function results=run_phase3_experiments(options)
%RUN_PHASE3_EXPERIMENTS 独立 A～F 实验；不修改 DSP，不将性能失败隐藏为通过。
% results=run_phase3_experiments; 默认固定种子，输出时间戳子目录。
arguments
    options.Seed (1,1) double {mustBeInteger,mustBeNonnegative} = 20261023
    options.RandomCount (1,1) double {mustBeInteger,mustBePositive} = 20
    options.NoiseRepeats (1,1) double {mustBeInteger,mustBePositive} = 10
end
root=fileparts(mfilename('fullpath')); addpath(fullfile(root,'src'),fullfile(root,'gui'));
oldRng=rng; restoreRng=onCleanup(@()rng(oldRng));
cfg=struct('seed',options.Seed,'randomCount',options.RandomCount, ...
    'noiseRepeats',options.NoiseRepeats,'fs',8192,'nfft',2048, ...
    'toneMs',[20 30 40 60 120 200 300],'gapMs',[0 10 30 100], ...
    'snrDb',[Inf 30 20 15 10 5 0],'inputRates',[8000 16000 44100 48000], ...
    'modes',["default","baseline"],'resolutionDpi',300);
cfg.startedUtc=string(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss'));
cfg.matlabVersion=string(version); cfg.toolboxes=ver;
cfg.characterMetric="max(0, 1 - sum(Levenshtein edits)/sum(reference lengths)); insertions/deletions/substitutions cost 1";
cfg.snrDefinition="Mean squared signal power over the entire sequence including gaps; measured Gaussian noise power normalized per trial; no clipping";
cfg.snrLabels=["no_noise","30 dB","20 dB","15 dB","10 dB","5 dB","0 dB"];
cfg.jsonNonfiniteNote="JSON encodes Inf as null; first snrDb entry denotes no_noise. MAT and CSV retain Inf.";
cfg.noiseSeedFormula="seed + modeIndex*100000 + snrIndex*10000 + sequenceIndex*100 + repeatIndex";
cfg.sourceFiles=sourceSnapshot(root);
[~,revision]=system(sprintf('git -c safe.directory="%s" -C "%s" rev-parse HEAD',root,root));
cfg.gitRevision=strtrim(string(revision));
runId=char(datetime('now','TimeZone','UTC','Format','yyyyMMdd_HHmmss_SSS'));
out=fullfile(root,'outputs','results','phase3',runId);
figDir=fullfile(root,'outputs','figures','phase3',runId);
mkdir(out); mkdir(figDir); mkdir(fullfile(out,'wav'));
diary(fullfile(out,'experiments.log')); closeDiary=onCleanup(@()diary('off'));
fprintf('Phase 3: %s UTC; MATLAB %s; seed=%d\n',runId,version,cfg.seed);
% 验证指标计算本身，尤其插入/删除不会被长度截断掩盖。
assert(editDistance('123','123')==0 && editDistance('123','13')==1 && ...
    editDistance('123','1234')==1 && editDistance('123','1?3')==1 && editDistance('123','')==3);
rng(cfg.seed,'twister'); numbers=["13800123456","11120033","0123456789"];
for k=1:cfg.randomCount
    n=randi([6 14]); numbers(end+1)=string(char(randi([0 9],1,n)+'0')); %#ok<AGROW>
end
cfg.numbers=numbers; cfg.timingNumbers=numbers(1:min(5,numel(numbers)));
cfg.noiseNumbers=numbers(1:3); cfg.compatibilityNumbers=numbers(1:3);
writeJson(fullfile(out,'config.json'),cfg);

%% A: 12 个标准键及频率误差
keys='0123456789*#'; rows=cell(12,1);
for k=1:numel(keys)
    theoretical=dtmfFrequencies(keys(k)); x=dtmfTone(keys(k)); d=dtmfRecognizeTone(x);
    rows{k}=struct('Key',string(keys(k)),'LowHz',theoretical(1),'HighHz',theoretical(2), ...
        'DetectedLowHz',d.frequencies(1),'DetectedHighHz',d.frequencies(2), ...
        'LowErrorHz',d.frequencies(1)-theoretical(1),'HighErrorHz',d.frequencies(2)-theoretical(2), ...
        'Recognized',d.key,'Correct',d.key==string(keys(k)),'Status',d.status,'Reason',d.reason);
end
results.A=struct2table(vertcat(rows{:})); writetable(results.A,fullfile(out,'A_frequency.csv'));
fprintf('A: %d/%d standard keys correct\n',sum(results.A.Correct),height(results.A));

%% B: 连续号码，包括重复数字和固定随机语料
rows=cell(numel(numbers),1);
for k=1:numel(numbers)
    a=dtmfSequence(numbers(k)); rows{k}=recognitionTrial("B","default",k,numbers(k),a.signal,a.config);
end
results.B=struct2table(vertcat(rows{:}));
writetable(results.B,fullfile(out,'B_sequences.csv'));
results.BSummary=summarize(results.B); writetable(results.BSummary,fullfile(out,'B_summary.csv'));
fprintf('B: %d/%d sequences exact\n',sum(results.B.SequenceCorrect),height(results.B));

%% C: 发声/间隔的全组合，另外加入严格 1000/100 点基准
rows={};
for tone=cfg.toneMs
    for gap=cfg.gapMs
        condition=sprintf('%gms_%gms',tone,gap);
        for k=1:numel(cfg.timingNumbers)
            a=dtmfSequence(cfg.timingNumbers(k),ToneDuration=tone/1000,GapDuration=gap/1000);
            rows{end+1}=recognitionTrial("C",condition,k,a.keys,a.signal,a.config); %#ok<AGROW>
        end
    end
end
for k=1:numel(cfg.timingNumbers)
    a=dtmfSequence(cfg.timingNumbers(k),Mode="baseline");
    rows{end+1}=recognitionTrial("C","baseline_1000_100",k,a.keys,a.signal,a.config); %#ok<AGROW>
end
results.C=struct2table(vertcat(rows{:})); results.CSummary=summarize(results.C);
writetable(results.C,fullfile(out,'C_timing_trials.csv')); writetable(results.CSummary,fullfile(out,'C_timing_summary.csv'));
fprintf('C: %d trials in %d parameter groups\n',height(results.C),height(results.CSummary));

%% D: AWGN，按包含间隔的整段平均功率定义 SNR，记录逐次真实识别
rows={};
for m=1:numel(cfg.modes)
    for level=1:numel(cfg.snrDb)
        snrDb=cfg.snrDb(level); repeats=cfg.noiseRepeats;
        if isinf(snrDb), repeats=1; end
        for k=1:numel(cfg.noiseNumbers)
            a=dtmfSequence(cfg.noiseNumbers(k),Mode=cfg.modes(m));
            for trial=1:repeats
                seed=cfg.seed+m*100000+level*10000+k*100+trial;
                rng(seed,'twister'); noisy=a.signal; measured=Inf;
                if isfinite(snrDb)
                    noise=randn(size(a.signal));
                    noise=noise*sqrt(mean(a.signal.^2)/(10^(snrDb/10)*mean(noise.^2)));
                    noisy=a.signal+noise;
                    measured=10*log10(mean(a.signal.^2)/mean(noise.^2));
                end
                condition=sprintf('%s_%gdB',cfg.modes(m),snrDb);
                r=recognitionTrial("D",condition,trial,a.keys,noisy,a.config);
                r.SnrDb=snrDb; r.MeasuredSnrDb=measured; r.Seed=seed;
                rows{end+1}=r; %#ok<AGROW>
            end
        end
        fprintf('D: %s SNR=%g dB complete\n',cfg.modes(m),snrDb);
    end
end
results.D=struct2table(vertcat(rows{:})); results.DSummary=summarize(results.D);
writetable(results.D,fullfile(out,'D_noise_trials.csv')); writetable(results.DSummary,fullfile(out,'D_noise_summary.csv'));

%% E: 在各输入采样率直接合成音调，写 WAV，再调用现有读取/重采样接口
rows={};
for rate=cfg.inputRates
    for channels=[1 2]
        for k=1:numel(cfg.compatibilityNumbers)
            expected=cfg.compatibilityNumbers(k); x=externalSignal(expected,rate);
            if channels==2, x=[x 0.7*x]; end %#ok<AGROW>
            file=fullfile(out,'wav',sprintf('rate_%d_ch%d_seq%d.wav',rate,channels,k));
            audiowrite(file,x,rate,'BitsPerSample',16);
            a=dtmfReadWav(file);
            r=recognitionTrial("E",sprintf('%dHz_ch%d',rate,channels),k,expected,a.signal,dtmfConfig);
            r.SampleRate=rate; r.Channels=channels; r.OutputRate=a.fs;
            r.CompatibilityOK=a.fs==8192 && size(a.signal,2)==1 && a.originalFs==rate && a.originalChannels==channels;
            rows{end+1}=r; %#ok<AGROW>
        end
    end
end
results.E=struct2table(vertcat(rows{:})); results.ESummary=summarize(results.E);
writetable(results.E,fullfile(out,'E_sample_rates.csv')); writetable(results.ESummary,fullfile(out,'E_summary.csv'));
fprintf('E: %d/%d sequences exact\n',sum(results.E.SequenceCorrect),height(results.E));

%% F: 实际异常/拒绝结果；意料之外的异常不会记作通过
results.F=exceptionChecks(out);
writetable(results.F,fullfile(out,'F_exceptions.csv'));
fprintf('F: %d/%d expected behaviors\n',sum(results.F.Passed),height(results.F));
results.Errors=[results.B(~results.B.SequenceCorrect,:);results.C(~results.C.SequenceCorrect,:);results.D(~results.D.SequenceCorrect,:)];
% E 附加的接口字段保留在 E 表中；错误总表使用共同字段。
eFailures=results.E(~results.E.SequenceCorrect,results.B.Properties.VariableNames);
results.Errors=[results.Errors;eFailures];
writetable(results.Errors,fullfile(out,'recognition_errors.csv'));

%% 图表与完整配置/结果
makeFigures(results,cfg,figDir,out);
cfg.finishedUtc=string(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss'));
results.Config=cfg; results.ResultsDirectory=string(out); results.FiguresDirectory=string(figDir);
save(fullfile(out,'phase3_results.mat'),'results','cfg');
writeJson(fullfile(out,'config.json'),cfg);
writeJson(fullfile(root,'outputs','results','phase3','latest.json'), ...
    struct('runId',runId,'resultsDirectory',out,'figuresDirectory',figDir,'completed',true));
fprintf('COMPLETE: %s\nFigures: %s\nRecognition error rows: %d\n',out,figDir,height(results.Errors));
end

function row=recognitionTrial(experiment,condition,trial,expected,x,cfg)
r=dtmfRecognizeSequence(x,8192); edits=editDistance(char(expected),char(r.keys));
reasons=strings(1,numel(r.segments));
for k=1:numel(r.segments), reasons(k)=r.segments(k).detail.reason; end
row=struct('Experiment',string(experiment),'Condition',string(condition),'Trial',trial, ...
    'Expected',string(expected),'Recognized',r.keys,'ReferenceChars',strlength(expected), ...
    'EditDistance',edits,'CharacterAccuracy',max(0,1-edits/max(1,strlength(expected))), ...
    'SequenceCorrect',r.keys==expected,'SegmentCount',numel(r.segments), ...
    'UnknownCount',sum(char(r.keys)=='?'),'Reasons',join(reasons,' | '), ...
    'Mode',cfg.mode,'ToneSamples',cfg.toneSamples,'GapSamples',cfg.gapSamples, ...
    'SnrDb',Inf,'MeasuredSnrDb',Inf,'SampleRate',8192,'Channels',1,'Seed',NaN);
end

function distance=editDistance(a,b)
previous=0:numel(b);
for i=1:numel(a)
    current=zeros(1,numel(b)+1); current(1)=i;
    for j=1:numel(b)
        current(j+1)=min([current(j)+1,previous(j+1)+1,previous(j)+(a(i)~=b(j))]);
    end
    previous=current;
end
distance=previous(end);
end

function summary=summarize(t)
conditions=unique(t.Condition,'stable'); rows=cell(numel(conditions),1);
for k=1:numel(conditions)
    s=t(t.Condition==conditions(k),:); n=sum(s.ReferenceChars); errors=sum(s.EditDistance);
    rows{k}=struct('Condition',conditions(k),'Trials',height(s),'ReferenceChars',n, ...
        'TotalEdits',errors,'CharacterErrorRate',errors/n,'CharacterAccuracy',max(0,1-errors/n), ...
        'CorrectSequences',sum(s.SequenceCorrect),'SequenceAccuracy',mean(s.SequenceCorrect), ...
        'Mode',s.Mode(1),'ToneSamples',s.ToneSamples(1),'GapSamples',s.GapSamples(1), ...
        'SnrDb',s.SnrDb(1),'SampleRate',s.SampleRate(1),'Channels',s.Channels(1));
end
summary=struct2table(vertcat(rows{:}));
end

function x=externalSignal(keys,rate)
chars=char(keys); n=round(.3*rate); gap=round(.1*rate);
x=zeros(numel(chars)*n+(numel(chars)-1)*gap,1);
for k=1:numel(chars)
    start=(k-1)*(n+gap)+1;
    x(start:start+n-1)=dtmfTone(chars(k),Fs=rate,Samples=n);
end
end

function t=exceptionChecks(out)
names=["纯静音序列","空音频序列","过短单音","无效字符","不支持的文本文件","空音频导出","空会话识别","非有限音频", ...
    "非标准单频音","非标准双频音"];
expected=["空号码且无片段","空号码且无片段","? / rejected", ...
    "dtmf:InvalidKey","MATLAB audioread 格式错误","dtmf:EmptyAudio","dtmf:EmptyAudio","有限数值校验异常", ...
    "单音 rejected；序列不输出有效按键","双音 rejected；序列不输出有效按键"];
rows=cell(numel(names),1);
badfile=fullfile(out,'unsupported_input.txt'); fid=fopen(badfile,'w');
assert(fid>=0,'Cannot create unsupported format fixture'); fprintf(fid,'Not an audio file.'); fclose(fid);
for k=1:numel(names)
    passed=false; observed=""; identifier="";
    try
        switch k
            case 1
                r=dtmfRecognizeSequence(zeros(8192,1));
                passed=r.keys=="" && isempty(r.segments); observed="keys="+r.keys+"; segments="+numel(r.segments);
            case 2
                r=dtmfRecognizeSequence(zeros(0,1));
                passed=r.keys=="" && isempty(r.segments); observed="keys="+r.keys+"; segments="+numel(r.segments);
            case 3
                r=dtmfRecognizeTone(dtmfTone('8',Samples=128));
                passed=r.key=="?" && r.status=="rejected"; observed=r.key+" / "+r.status+" / "+r.reason;
            case 4, dtmfSequence("12A3");
            case 5, dtmfReadWav(badfile);
            case 6, dtmfWriteWav(fullfile(out,'empty.wav'),zeros(0,1));
            case 7, session=DtmfSession; session.recognize;
            case 8, dtmfRecognizeSequence([0;NaN;0]);
            case {9,10}
                time=(0:2457)'/8192;
                if k==9
                    signal=0.45*sin(2*pi*1000*time);
                else
                    signal=0.30*(sin(2*pi*600*time)+sin(2*pi*1700*time));
                end
                file=fullfile(out,'wav',sprintf('nonstandard_case%d.wav',k));
                audiowrite(file,signal,8192,'BitsPerSample',16);
                audio=dtmfReadWav(file);
                tone=dtmfRecognizeTone(audio.signal);
                sequence=dtmfRecognizeSequence(audio.signal);
                passed=tone.status=="rejected" && all(char(sequence.keys)=='?');
                observed="tone="+tone.key+" / "+tone.status+" / "+tone.reason+"; sequence="+sequence.keys;
        end
        if k>=4 && k<=8, observed="未抛出异常"; end
    catch exception
        observed=string(exception.message); identifier=string(exception.identifier);
        switch k
            case 4, passed=identifier=="dtmf:InvalidKey";
            case 5, passed=contains(lower(identifier),'audioread');
            case {6,7}, passed=identifier=="dtmf:EmptyAudio";
            case 8, passed=contains(lower(identifier),'finite');
        end
    end
    rows{k}=struct('Case',names(k),'Expected',expected(k),'Observed',observed,'Identifier',identifier,'Passed',passed);
end
t=struct2table(vertcat(rows{:}));
end

function makeFigures(r,cfg,figDir,out)
x=dtmfTone('8',Samples=1000); spectrum=dtmfSpectrum(x);
f=reportFigure; c=onCleanup(@()close(f));
layout=tiledlayout(f,2,1,'TileSpacing','compact','Padding','compact');
ax=nexttile(layout); plot(ax,(0:numel(x)-1)/8192*1000,x,'Color',[.14 .45 .61]);
title(ax,'数字 8：1000 点时域波形'); xlabel(ax,'时间 (ms)'); ylabel(ax,'归一化幅度'); legend(ax,'852 Hz + 1336 Hz');
ax=nexttile(layout); count=round(.012*8192); plot(ax,(0:count-1)/8192*1000,x(1:count));
title(ax,'前 12 ms 局部放大'); xlabel(ax,'时间 (ms)'); ylabel(ax,'归一化幅度'); legend(ax,'双频叠加');
saveFigure(f,fullfile(figDir,'01_digit8_waveform.png'),cfg);
clf(f); ax=axes(f); plot(ax,spectrum.frequency,spectrum.amplitude,'Color',[.46 .34 .65],'LineWidth',1.4);
xlim(ax,[0 2000]); ylim(ax,[0 max(spectrum.amplitude)*1.15]);
xline(ax,852,'--','852 Hz','LabelVerticalAlignment','middle');
xline(ax,1336,'--','1336 Hz','LabelVerticalAlignment','middle');
title(ax,'数字 8：2048 点 FFT（1000 有效样点，栅格 4 Hz）'); xlabel(ax,'频率 (Hz)'); ylabel(ax,'单边峰值幅度');
legend(ax,'FFT 幅度','理论低频','理论高频','Location','northeast');
saveFigure(f,fullfile(figDir,'02_digit8_spectrum.png'),cfg);
save(fullfile(out,'digit8_data.mat'),'x','spectrum');
clf(f); ax=axes(f); bar(ax,[r.A.LowErrorHz,r.A.HighErrorHz]);
xticks(ax,1:12); xticklabels(ax,r.A.Key); yline(ax,0,':','HandleVisibility','off');
title(ax,sprintf('12 键 DTMF 频率估计误差（最大绝对误差 %.4f Hz）',max(abs([r.A.LowErrorHz;r.A.HighErrorHz]))));
xlabel(ax,'标准按键'); ylabel(ax,'检测频率 − 理论频率 (Hz)');
legend(ax,'低频误差','高频误差','Location','southoutside','Orientation','horizontal');
saveFigure(f,fullfile(figDir,'03_frequency_error.png'),cfg);
clf(f); ax=axes(f); a=dtmfSequence(cfg.numbers(1));
plot(ax,(0:numel(a.signal)-1)/a.fs,a.signal,'Color',[.14 .45 .61]); ylim(ax,[-1.1 1.22]);
for k=1:numel(a.segments)
    s=a.segments(k); text(ax,(s.startTime+s.endTime)/2,1.05,s.key,'HorizontalAlignment','center');
end
title(ax,'连续号码 13800123456：300 ms 发声 / 100 ms 间隔'); xlabel(ax,'时间 (s)'); ylabel(ax,'归一化幅度'); legend(ax,'DTMF 序列');
saveFigure(f,fullfile(figDir,'04_sequence_waveform.png'),cfg);
clf(f); ax=axes(f); hold(ax,'on'); colors=[.14 .45 .61;.65 .35 .15];
for m=1:2
    s=r.DSummary(r.DSummary.Mode==cfg.modes(m),:); [~,order]=sort(s.SnrDb); s=s(order,:);
    finite=isfinite(s.SnrDb); reference=~finite;
    plot(ax,s.SnrDb(finite),100*s.CharacterAccuracy(finite),'-o','Color',colors(m,:),'LineWidth',1.7,'DisplayName',cfg.modes(m)+" 字符准确率");
    plot(ax,s.SnrDb(finite),100*s.SequenceAccuracy(finite),'--s','Color',colors(m,:),'LineWidth',1.7,'DisplayName',cfg.modes(m)+" 完整号码准确率");
    % 无噪声是独立参考点，不将无穷大伪装成有限 SNR 的连续曲线。
    plot(ax,40,100*s.CharacterAccuracy(reference),'o','Color',colors(m,:),'MarkerSize',9,'HandleVisibility','off');
    plot(ax,40,100*s.SequenceAccuracy(reference),'s','Color',colors(m,:),'MarkerSize',6,'HandleVisibility','off');
end
xticks(ax,[0 5 10 15 20 30 40]); xticklabels(ax,{'0','5','10','15','20','30','无噪声'}); ylim(ax,[-3 105]);
title(ax,sprintf('高斯白噪声下识别性能（每个有限 SNR / 模式 %d 次）',3*cfg.noiseRepeats));
xlabel(ax,'整段信号 SNR (dB)；无噪声为独立参考点'); ylabel(ax,'识别准确率 (%)'); legend(ax,'Location','southoutside','NumColumns',2);
saveFigure(f,fullfile(figDir,'05_snr_accuracy.png'),cfg);
clf(f); layout=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
metrics={'CharacterAccuracy','SequenceAccuracy'}; titles={'字符级准确率','完整号码准确率'};
for metric=1:2
    ax=nexttile(layout); hold(ax,'on');
    for gap=cfg.gapMs
        s=r.CSummary(r.CSummary.Mode=="default" & r.CSummary.GapSamples==round(gap/1000*8192),:);
        [~,order]=sort(s.ToneSamples); s=s(order,:);
        plot(ax,s.ToneSamples/8192*1000,100*s.(metrics{metric}),'-o','LineWidth',1.4,'DisplayName',sprintf('间隔 %g ms',gap));
    end
    s=r.CSummary(r.CSummary.Mode=="baseline",:);
    plot(ax,s.ToneSamples/8192*1000,100*s.(metrics{metric}),'p','MarkerSize',12,'LineWidth',1.5,'DisplayName','基准 1000/100 点');
    title(ax,titles{metric}); xlabel(ax,'实际单键持续时间 (ms)'); ylabel(ax,'识别准确率 (%)'); ylim(ax,[-3 108]);
    legend(ax,'Location','southoutside','FontSize',10);
end
title(layout,sprintf('拨号时间与间隔的影响（每组 %d 个号码；含短音与零间隔压力条件）',numel(cfg.timingNumbers)));
saveFigure(f,fullfile(figDir,'06_timing_accuracy.png'),cfg);
clf(f); ax=axes(f); values=zeros(4,2);
for k=1:4
    s=r.E(r.E.SampleRate==cfg.inputRates(k),:);
    values(k,:)=[max(0,1-sum(s.EditDistance)/sum(s.ReferenceChars)),mean(s.SequenceCorrect)]*100;
end
bar(ax,values); ylim(ax,[0 112]); xticks(ax,1:4); xticklabels(ax,string(cfg.inputRates));
for k=1:4, text(ax,k,103,sprintf('%.0f%% / %.0f%%',values(k,:)),'HorizontalAlignment','center'); end
title(ax,'WAV 输入采样率兼容性（每种采样率 3 个号码 × 单/双声道）');
xlabel(ax,'WAV 原始采样率 (Hz)，读取后统一为 8192 Hz'); ylabel(ax,'识别准确率 (%)');
legend(ax,'字符级','完整号码','Location','southoutside','Orientation','horizontal');
saveFigure(f,fullfile(figDir,'07_sample_rate_accuracy.png'),cfg);
end

function f=reportFigure
f=figure('Visible','off','Color','white','Position',[50 50 1100 640]);
end

function saveFigure(f,file,cfg)
theme=dtmfPixelTheme;
set(findall(f,'-property','FontName'),'FontName',theme.BodyFont);
axesList=findall(f,'Type','axes');
for k=1:numel(axesList)
    axesList(k).FontSize=12; axesList(k).XGrid='on'; axesList(k).YGrid='on';
    axesList(k).GridAlpha=.18; axesList(k).Box='on';
end
drawnow; exportgraphics(f,file,'Resolution',cfg.resolutionDpi,'BackgroundColor','white');
end

function files=sourceSnapshot(root)
paths=[dir(fullfile(root,'src','*.m'));dir(fullfile(root,'gui','DtmfSession.m'));dir(fullfile(root,'run_phase3_experiments.m'))];
files=struct('name',{},'gitBlobHash',{});
for k=1:numel(paths)
    file=fullfile(paths(k).folder,paths(k).name);
    [status,hash]=system(sprintf('git hash-object "%s"',file));
    assert(status==0,'Cannot fingerprint experiment sources');
    files(k)=struct('name',paths(k).name,'gitBlobHash',strtrim(string(hash)));
end
end

function writeJson(path,value)
text=jsonencode(value,'PrettyPrint',true);
fid=fopen(path,'w','n','UTF-8'); assert(fid>=0,'Cannot write experiment metadata');
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',text);
end
