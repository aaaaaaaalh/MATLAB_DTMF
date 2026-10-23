function tests=testDtmfGui
%TESTDTMFGUI 创建真实原生控件但不播放；不代替实际听音与人工布局检查。
tests=functiontests(localfunctions);
end

function setup(t)
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
t.TestData.app=DTMF_App(Visible="off"); ui=t.TestData.app.UI; ui.Audition.Value=false;
t.TestData.root=root;
end

function teardown(t)
if isfield(t.TestData,'app') && isvalid(t.TestData.app)
    delete(t.TestData.app);
end
end

function testKeypadLayoutAndCallbacks(t)
app=t.TestData.app;
verifyEqual(t,string(app.Figure.AutoResizeChildren),"off");
for k=1:12
    verifyEqual(t,app.UI.Keys(k).Layout.Row,ceil(k/3));
    verifyEqual(t,app.UI.Keys(k).Layout.Column,mod(k-1,3)+1);
end
% 执行真实按钮回调，检查循环闭包绑定的是各自数字。
for k=1:9
    button=app.UI.Keys(k); button.ButtonPushedFcn(button,[]);
end
button=app.UI.Keys(11); button.ButtonPushedFcn(button,[]);
verifyEqual(t,app.UI.Number.Value,'1234567890');
end

function testDeleteAndConfirmCallbacks(t)
app=t.TestData.app; for k='11120033', app.pressKey(k); end
button=app.UI.Keys(10); button.ButtonPushedFcn(button,[]);
verifyEqual(t,app.Session.Digits,"1112003");
button=app.UI.Keys(12); button.ButtonPushedFcn(button,[]);
verifyEqual(t,app.UI.Result.Value,'1112003'); verifyTrue(t,app.Session.Confirmed);
verifyEqual(t,size(app.UI.Table.Data,1),7);
verifyFalse(t,contains(app.Session.Digits,"#"));
end

function testWaveAndSpectrum(t)
app=t.TestData.app; app.pressKey('8');
verifyEqual(t,app.UI.Wave.XLabel.String,'时间 (s)');
verifyEqual(t,app.UI.Spectrum.XLabel.String,'频率 (Hz)');
verifyTrue(t,contains(app.UI.Frequencies.Text,'852')); verifyTrue(t,contains(app.UI.Frequencies.Text,'1336'));
verifyNotEmpty(t,findall(app.UI.Wave,'Type','line'));
verifyNotEmpty(t,findall(app.UI.Spectrum,'Type','line'));
app.pressKey('1'); app.selectSegment(1);
verifyTrue(t,contains(app.UI.Frequencies.Text,'852')); verifyEqual(t,app.UI.Segment.Value,1);
end

function testModeControls(t)
app=t.TestData.app; app.pressKey('8'); app.pressKey('8');
ui=app.UI;
verifyEqual(t,ui.Mode.ItemsData,[1 2]); verifyEqual(t,ui.Mode.Value,1);
verifyEqual(t,app.Session.Mode,"default");
ui.Mode.Value=2; ui.Mode.ValueChangedFcn(ui.Mode,[]);
verifyEqual(t,app.Session.Mode,"baseline"); verifyEqual(t,ui.Mode.Value,2);
verifyEqual(t,string(app.UI.Tone.Enable),"off"); verifyEqual(t,numel(app.Session.Audio.signal),2100);
ui.Mode.Value=1; ui.Tone.Value=120; ui.Gap.Value=30;
ui.Mode.ValueChangedFcn(ui.Mode,[]);
verifyEqual(t,app.Session.Mode,"default"); verifyEqual(t,ui.Mode.Value,1);
verifyEqual(t,string(app.UI.Tone.Enable),"on"); app.recognize;
verifyEqual(t,app.UI.Result.Value,'88');
end

function testImportExportAndClear(t)
app=t.TestData.app; app.importFile(fullfile(t.TestData.root,'examples','13800123456.wav'));
verifyEqual(t,app.UI.Result.Value,'13800123456'); verifyNotEmpty(t,findall(app.UI.Wave,'Type','line'));
file=string(tempname)+".wav"; cleanup=onCleanup(@()delete(file));
app.exportFile(file); b=dtmfReadWav(file); r=dtmfRecognizeSequence(b.signal);
verifyEqual(t,r.keys,"13800123456");
app.clearAudio; verifyEqual(t,app.UI.Result.Value,''); verifyEqual(t,app.UI.Number.Value,'');
verifyEqual(t,app.UI.Segment.Value,0); verifyEmpty(t,app.UI.Table.Data);
end

function testEmptyAndInvalidRemainOpen(t)
app=t.TestData.app;
verifyError(t,@()app.recognize,'dtmf:EmptyAudio'); verifyError(t,@()app.pressKey('A'),'dtmf:DialDigit');
verifyTrue(t,isgraphics(app.Figure)); verifyEmpty(t,app.Session.Audio.signal);
end

function testCloseLifecycle(t)
app=t.TestData.app; fig=app.Figure;
close(fig); verifyFalse(t,isgraphics(fig)); verifyFalse(t,isvalid(app));
end
