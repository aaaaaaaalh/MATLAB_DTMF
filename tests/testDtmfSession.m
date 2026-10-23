function tests=testDtmfSession
%TESTDTMFSESSION 无界面的会话状态测试；复用已验收 DSP。
tests=functiontests(localfunctions);
end

function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'src'),fullfile(root,'gui'));
t.TestData.root=root;
end

function testDigitAndDelete(t)
s=DtmfSession;
for k='11120033', s.appendDigit(k); end
verifyEqual(t,s.Digits,"11120033");
s.backspace; verifyEqual(t,s.Digits,"1112003");
verifyEqual(t,numel(s.Audio.signal),7*2458+6*819);
s.recognize(true); verifyEqual(t,s.Recognition.keys,s.Digits); verifyTrue(t,s.Confirmed);
s.appendDigit('8'); verifyFalse(t,s.Confirmed); verifyEmpty(t,s.Recognition);
end

function testEmptyAndInvalid(t)
s=DtmfSession; s.backspace; verifyEmpty(t,s.Audio.signal);
verifyError(t,@()s.recognize,'dtmf:EmptyAudio');
for key=["*","#","A","12",""]
    verifyError(t,@()s.appendDigit(key),'dtmf:DialDigit');
end
verifyEqual(t,s.Digits,"");
end

function testBaselineConfig(t)
s=DtmfSession; s.appendDigit('8'); s.appendDigit('8'); s.configure("baseline",500,50);
verifyEqual(t,numel(s.Audio.signal),2100);
s.recognize(true); verifyEqual(t,s.Recognition.keys,"88");
s.configure("default",120,30); verifyFalse(t,s.Confirmed);
verifyEqual(t,numel(s.Audio.signal),2*round(.12*8192)+round(.03*8192));
end

function testFailedChangePreservesState(t)
s=DtmfSession; s.appendDigit('8'); old=s.Audio;
verifyError(t,@()s.configure("bad",300,100),'dtmf:Mode');
verifyEqual(t,s.Audio,old); verifyEqual(t,s.Mode,"default");
end

function testImportAndNewDial(t)
s=DtmfSession; s.appendDigit('9'); s.importWav(fullfile(t.TestData.root,'examples','13800123456.wav'));
verifyEqual(t,s.Source,"wav"); verifyEqual(t,s.Digits,""); verifyEqual(t,s.Recognition.keys,"13800123456");
old=s.Audio.signal; s.configure("baseline",300,100); verifyEqual(t,s.Audio.signal,old);
verifyError(t,@()s.backspace,'dtmf:ImportedEdit'); verifyEqual(t,s.Audio.signal,old);
s.appendDigit('2'); verifyEqual(t,s.Source,"dial"); verifyEqual(t,s.Digits,"2"); verifyEqual(t,numel(s.Audio.signal),1000);
end

function testImportExport(t)
file=string(tempname)+".wav"; cleanup=onCleanup(@()delete(file));
s=DtmfSession; for k='88001', s.appendDigit(k); end
s.exportWav(file); other=DtmfSession; other.importWav(file);
verifyEqual(t,other.Recognition.keys,"88001"); verifyEqual(t,other.Audio.fs,8192);
end

function testResampleStereo(t)
file=string(tempname)+".wav"; cleanup=onCleanup(@()delete(file));
audio=dtmfSequence("1138",Mode="baseline"); x=resample(audio.signal,375,64); % 48000/8192
audiowrite(file,[x 0.8*x],48000); s=DtmfSession; s.importWav(file);
verifyEqual(t,s.Audio.originalFs,48000); verifyEqual(t,s.Audio.originalChannels,2);
verifyEqual(t,s.Recognition.keys,"1138");
end

function testSelectedSegment(t)
s=DtmfSession; for k='138', s.appendDigit(k); end
[x,r,segment]=s.segmentAudio(3);
verifyEqual(t,r.key,"8"); verifyEqual(t,r.frequencies,[852 1336],'AbsTol',4);
verifyEqual(t,x,s.Audio.signal(segment.startSample:segment.endSample));
end

function testClearResets(t)
s=DtmfSession; s.appendDigit('1'); s.recognize(true); s.clear;
verifyEqual(t,s.Digits,""); verifyEmpty(t,s.Audio.signal); verifyEmpty(t,s.Recognition); verifyFalse(t,s.Confirmed);
verifyError(t,@()s.exportWav("unused.wav"),'dtmf:EmptyAudio');
end
