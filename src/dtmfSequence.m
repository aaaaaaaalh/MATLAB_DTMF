function audio = dtmfSequence(keys,options)
%DTMFSEQUENCE 底层标准音调序列（支持 *、#）；不执行 GUI 删除/确认操作。
% segments 的 startSample/endSample 为闭区间；startTime/endTime 为半开区间，单位秒。
arguments
    keys (1,1) string
    options.Mode (1,1) string {mustBeMember(options.Mode,["default","baseline"])} = "default"
    options.ToneDuration (1,1) double {mustBeFinite,mustBePositive} = 0.300
    options.GapDuration (1,1) double {mustBeFinite,mustBeNonnegative} = 0.100
    options.Amplitude (1,1) double {mustBeFinite,mustBePositive} = 0.45
end
cfg = dtmfConfig(options.Mode);
if options.Amplitude>0.5, error('dtmf:Amplitude','每个正弦幅度不得超过 0.5。'); end
cfg.amplitude=options.Amplitude;
if options.Mode == "default"
    cfg.toneSamples = round(options.ToneDuration*cfg.fs);
    cfg.gapSamples = round(options.GapDuration*cfg.fs);
    cfg.toneDuration=cfg.toneSamples/cfg.fs;
    cfg.gapDuration=cfg.gapSamples/cfg.fs;
end
if cfg.toneSamples<1, error('dtmf:Duration','持续时间至少对应一个采样点。'); end
chars = char(keys); count = numel(chars);
for k=1:count, dtmfFrequencies(chars(k)); end
N = count*cfg.toneSamples+max(0,count-1)*cfg.gapSamples;
x = zeros(N,1);
segments = repmat(struct('key',"",'startSample',0,'endSample',0,'startTime',0,'endTime',0),count,1);
for k=1:count
    a = (k-1)*(cfg.toneSamples+cfg.gapSamples)+1; b = a+cfg.toneSamples-1;
    x(a:b) = dtmfTone(chars(k),Samples=cfg.toneSamples,Amplitude=options.Amplitude);
    segments(k) = struct('key',string(chars(k)),'startSample',a,'endSample',b, ...
        'startTime',(a-1)/cfg.fs,'endTime',b/cfg.fs);
end
audio = struct('signal',x,'fs',cfg.fs,'keys',keys,'segments',segments,'config',cfg);
end
