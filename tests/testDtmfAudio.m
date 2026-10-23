function tests=testDtmfAudio
%TESTDTMFAUDIO 可选真实声卡测试，会发声；通过也不等价于人工听音验收。
tests=functiontests(localfunctions);
end

function setup(t)
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
devices=audiodevinfo;
assumeFalse(t,isempty(devices.output),'没有音频输出设备，跳过硬件测试。');
t.TestData.app=DTMF_App(Visible="off"); ui=t.TestData.app.UI; ui.Audition.Value=false;
for k='13800123456', t.TestData.app.pressKey(k); end
end

function teardown(t)
if isfield(t.TestData,'app') && isvalid(t.TestData.app), delete(t.TestData.app); end
end

function testReplaceAndStopPlayer(t)
app=t.TestData.app; app.playAll; first=app.Player;
verifyTrue(t,isplaying(first));
app.playAll; verifyFalse(t,isvalid(first)); verifyTrue(t,isplaying(app.Player));
second=app.Player; app.stopPlayback;
verifyEmpty(t,app.Player); verifyFalse(t,isvalid(second));
end

function testCloseWhilePlaying(t)
app=t.TestData.app; app.playAll; player=app.Player; fig=app.Figure;
close(fig); verifyFalse(t,isvalid(player)); verifyFalse(t,isgraphics(fig)); verifyFalse(t,isvalid(app));
end
