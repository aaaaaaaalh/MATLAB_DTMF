function audio = dtmfReadWav(filename)
%DTMFREADWAV 读取 WAV，按通道平均转单声道，并重采样至实验采样率。
arguments
    filename (1,1) string
end
[x,originalFs]=audioread(filename); channels=size(x,2); x=mean(x,2);
if any(~isfinite(x)), error('dtmf:InvalidAudio','音频含非有限数值。'); end
if originalFs~=8192
    [p,q]=rat(8192/originalFs); x=resample(x,p,q);
end
audio=struct('signal',x,'fs',8192,'originalFs',originalFs,'originalChannels',channels);
end
