function cfg = dtmfConfig(mode)
%DTMFCONFIG 实验参数。baseline 严格使用 1000/100 点；默认使用 300/100 ms。
arguments
    mode (1,1) string {mustBeMember(mode,["default","baseline"])} = "default"
end
cfg = struct('fs',8192,'nfft',2048,'toneDuration',0.300, ...
    'gapDuration',0.100,'toneSamples',round(0.300*8192), ...
    'gapSamples',round(0.100*8192),'amplitude',0.45,'mode',mode);
if mode == "baseline"
    cfg.toneSamples = 1000; cfg.gapSamples = 100;
    cfg.toneDuration = 1000/cfg.fs; cfg.gapDuration = 100/cfg.fs;
end
end
