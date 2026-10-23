function [x,fs,info] = dtmfTone(key,options)
%DTMFTONE 合成列向量。Samples 非空时优先于 Duration；Amplitude 为每个正弦幅度。
arguments
    key
    options.Fs (1,1) double {mustBeFinite,mustBePositive} = 8192
    options.Duration (1,1) double {mustBeFinite,mustBePositive} = 0.300
    options.Samples double = []
    options.Amplitude (1,1) double {mustBeFinite,mustBePositive} = 0.45
end
f = dtmfFrequencies(key); fs = options.Fs;
if fs <= 2*max(f), error('dtmf:SampleRate','采样率不满足奈奎斯特条件。'); end
N = round(options.Duration*fs);
if ~isempty(options.Samples)
    validateattributes(options.Samples,{'double'},{'scalar','integer','positive','finite'});
    N = options.Samples;
end
if N < 1, error('dtmf:Duration','持续时间至少对应一个采样点。'); end
if options.Amplitude > 0.5, error('dtmf:Amplitude','每个正弦幅度不得超过 0.5。'); end
t = (0:N-1)'/fs;
x = options.Amplitude*(sin(2*pi*f(1)*t)+sin(2*pi*f(2)*t));
info = struct('key',string(key),'frequencies',f,'samples',N,'duration',N/fs);
end
