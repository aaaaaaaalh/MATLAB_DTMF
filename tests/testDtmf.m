function tests = testDtmf
%TESTDTMF 核心回归测试；每个 test 函数为一个测试项，内部覆盖多个参数组合。
tests=functiontests(localfunctions);
end

function testMapping(t)
keys='123456789*0#'; expected=[697 1209;697 1336;697 1477;770 1209;770 1336;770 1477;852 1209;852 1336;852 1477;941 1209;941 1336;941 1477];
for k=1:12, verifyEqual(t,dtmfFrequencies(keys(k)),expected(k,:)); end
end

function testToneShape(t)
[x,fs,info]=dtmfTone('0');
verifySize(t,x,[2458 1]); verifyEqual(t,fs,8192);
verifyTrue(t,all(isfinite(x))); verifyLessThanOrEqual(t,max(abs(x)),0.9);
verifyEqual(t,info.frequencies,[941 1336]);
s=dtmfSpectrum(x,fs); verifyEqual(t,s.nfft,2048); verifyEqual(t,s.validSamples,2048); verifyEqual(t,s.gridHz,4);
end

function testExactSamples(t)
x=dtmfTone('8',Samples=1000); verifySize(t,x,[1000 1]);
s=dtmfSpectrum(x); verifyEqual(t,s.validSamples,1000); verifyEqual(t,numel(s.frequency),1025);
a=dtmfSequence("123",Mode="baseline"); verifyEqual(t,numel(a.signal),3200);
verifyEqual(t,a.signal(1001:1100),zeros(100,1));
verifyEqual(t,[a.segments.startSample],[1 1101 2201]);
verifyEqual(t,[a.segments.endSample],[1000 2100 3200]);
end

function testAllKeys(t)
for key='123456789*0#'
    for N=[1000 2458]
        r=dtmfRecognizeTone(dtmfTone(key,Samples=N));
        verifyEqual(t,r.key,string(key)); verifyEqual(t,r.status,"accepted");
        verifyEqual(t,r.frequencies,dtmfFrequencies(key),'AbsTol',4);
    end
end
end

function testDefaultSequence(t)
a=dtmfSequence("13800123456"); r=dtmfRecognizeSequence(a.signal);
verifyEqual(t,r.keys,a.keys); verifyEqual(t,a.config.toneSamples,2458); verifyEqual(t,a.config.gapSamples,819);
verifyEqual(t,numel(a.signal),11*2458+10*819);
verifyEqual(t,numel(r.segments),11);
verifyEqual(t,[r.segments.startTime],[a.segments.startTime],'AbsTol',0.006);
verifyEqual(t,[r.segments.endTime],[a.segments.endTime],'AbsTol',0.006);
end

function testBaselineRepeated(t)
a=dtmfSequence("11120033",Mode="baseline"); r=dtmfRecognizeSequence(a.signal);
verifyEqual(t,r.keys,a.keys); verifyEqual(t,numel(r.segments),8);
end

function testDurations(t)
for duration=[0.060 0.120 0.300 0.500]
    for gap=[0.0122 0.030 0.100]
        a=dtmfSequence("11223390",ToneDuration=duration,GapDuration=gap);
        r=dtmfRecognizeSequence(a.signal); verifyEqual(t,r.keys,a.keys);
    end
end
end

function testVariableDurations(t)
keys='190088'; x=[];
for k=1:numel(keys)
    x=[x;dtmfTone(keys(k),Duration=0.07+0.027*k);zeros(90+13*k,1)]; %#ok<AGROW>
end
r=dtmfRecognizeSequence(x); verifyEqual(t,r.keys,string(keys));
end

function testLowVolumePadding(t)
for mode=["default","baseline"]
    a=dtmfSequence("0011388",Mode=mode,Amplitude=0.00045);
    x=[zeros(2048,1);a.signal;zeros(1700,1)]; r=dtmfRecognizeSequence(x);
    verifyEqual(t,r.keys,a.keys);
end
end

function testAmplitudeChanges(t)
x=[dtmfTone('1',Amplitude=0.45);zeros(819,1);dtmfTone('2',Amplitude=0.20);zeros(819,1);dtmfTone('3',Amplitude=0.30)];
r=dtmfRecognizeSequence(x); verifyEqual(t,r.keys,"123");
end

function testShortDropout(t)
a=dtmfSequence("111",Mode="baseline"); a.signal(450:456)=0;
r=dtmfRecognizeSequence(a.signal); verifyEqual(t,r.keys,a.keys);
end

function testSilence(t)
r=dtmfRecognizeTone(zeros(1000,1)); verifyEqual(t,r.key,"?");
r=dtmfRecognizeSequence(zeros(8192,1)); verifyEqual(t,r.keys,""); verifyEmpty(t,r.segments);
end

function testTooShort(t)
r=dtmfRecognizeTone(dtmfTone('1',Samples=100)); verifyEqual(t,r.key,"?");
verifyNotEmpty(t,r.reason);
r=dtmfRecognizeSequence(dtmfTone('1',Samples=200)); verifyEqual(t,r.keys,"?");
end

function testEmpty(t)
a=dtmfSequence(""); verifyEmpty(t,a.signal);
r=dtmfRecognizeSequence(zeros(0,1)); verifyEqual(t,r.keys,"");
verifyError(t,@()dtmfWriteWav("unused.wav",zeros(0,1)),'dtmf:EmptyAudio');
end

function testInvalidKeys(t)
for key=["A","12"," ","一"]
    verifyError(t,@()dtmfFrequencies(key),'dtmf:InvalidKey');
end
verifyError(t,@()dtmfSequence("12A"),'dtmf:InvalidKey');
verifyError(t,@()dtmfTone('1',Amplitude=0.6),'dtmf:Amplitude');
verifyError(t,@()dtmfTone('1',Fs=2000),'dtmf:SampleRate');
end

function testNonDtmf(t)
n=(0:999)'/8192; rng(117,'twister');
signals={0.4*sin(2*pi*697*n),0.4*sin(2*pi*1000*n), ...
    0.2*(sin(2*pi*697*n)+sin(2*pi*1633*n)), ...
    0.2*(sin(2*pi*697*n)+sin(2*pi*770*n)+sin(2*pi*1209*n)),randn(1000,1)};
for k=1:numel(signals)
    r=dtmfRecognizeTone(signals{k}); verifyEqual(t,r.key,"?");
end
end

function testFrequencyTolerance(t)
n=(0:999)'/8192;
r=dtmfRecognizeTone(0.4*(sin(2*pi*705*n)+sin(2*pi*1217*n))); verifyEqual(t,r.key,"1");
r=dtmfRecognizeTone(0.4*(sin(2*pi*720*n)+sin(2*pi*1232*n))); verifyEqual(t,r.key,"?");
end

function testWavRates(t)
folder=tempname; mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
a=dtmfSequence("13800123456",Mode="baseline");
for rate=[8000 16000 44100 48000]
    [p,q]=rat(rate/a.fs); x=resample(a.signal,p,q);
    file=fullfile(folder,sprintf('rate_%d.wav',rate)); audiowrite(file,[x 0.7*x],rate);
    b=dtmfReadWav(file); r=dtmfRecognizeSequence(b.signal,b.fs);
    verifyEqual(t,b.fs,8192); verifyEqual(t,b.originalChannels,2); verifyEqual(t,b.originalFs,rate);
    verifyEqual(t,r.keys,a.keys);
end
end

function testWavRoundtrip(t)
file=string(tempname)+".wav"; cleanup=onCleanup(@()delete(file)); %#ok<NASGU>
a=dtmfSequence("11120033"); dtmfWriteWav(file,a.signal,a.fs); b=dtmfReadWav(file);
r=dtmfRecognizeSequence(b.signal,b.fs); verifyEqual(t,r.keys,a.keys);
verifyEqual(t,b.signal,a.signal,'AbsTol',2^-22);
end

function testExportNormalization(t)
file=string(tempname)+".wav"; cleanup=onCleanup(@()delete(file)); %#ok<NASGU>
x=3*dtmfTone('8'); dtmfWriteWav(file,x); b=dtmfReadWav(file);
verifyLessThan(t,max(abs(b.signal)),1); r=dtmfRecognizeTone(b.signal); verifyEqual(t,r.key,"8");
end

function testNoiseExperiment(t)
% SNR 以发声区间的平均功率定义；低 SNR 仅记录能力边界，不伪造通过要求。
rng(20261022,'twister'); rows=struct('mode',{},'snrDb',{},'count',{},'correct',{},'accuracy',{},'failures',{});
trialRows=struct('mode',{},'snrDb',{},'trial',{},'expected',{},'recognized',{},'correct',{});
trials=10;
for mode=["default","baseline"]
    a=dtmfSequence("1112003313800123456",Mode=mode);
    clean=[zeros(1024,1);a.signal;zeros(1024,1)];
    tonePower=mean(dtmfTone('1',Samples=a.config.toneSamples).^2);
    for snrDb=[30 20 10 5 0 -5]
        correct=0; failures=strings(0,1);
        for k=1:trials
            noisy=clean+sqrt(tonePower/10^(snrDb/10))*randn(size(clean));
            r=dtmfRecognizeSequence(noisy);
            trialRows(end+1)=struct('mode',mode,'snrDb',snrDb,'trial',k, ...
                'expected',a.keys,'recognized',r.keys,'correct',r.keys==a.keys); %#ok<AGROW>
            if r.keys==a.keys, correct=correct+1;
            else, failures(end+1)=sprintf('trial=%d expected=%s actual=%s',k,a.keys,r.keys); end %#ok<AGROW>
        end
        rows(end+1)=struct('mode',mode,'snrDb',snrDb,'count',trials,'correct',correct, ...
            'accuracy',correct/trials,'failures',join(failures," | ")); %#ok<AGROW>
    end
end
root=fileparts(fileparts(mfilename('fullpath'))); out=fullfile(root,'outputs','results');
writetable(struct2table(rows),fullfile(out,'noise_results.csv'));
writetable(struct2table(trialRows),fullfile(out,'noise_trials.csv'));
save(fullfile(out,'noise_results.mat'),'rows','trials','trialRows');
required=[rows.snrDb]>=10;
verifyEqual(t,[rows(required).correct],trials*ones(1,sum(required)), ...
    'SNR >=10 dB 的固定种子回归要求失败；详见原始记录。');
end
