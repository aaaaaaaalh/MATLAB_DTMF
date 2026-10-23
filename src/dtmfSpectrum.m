function spectrum = dtmfSpectrum(x,fs)
%DTMFSPECTRUM 2048 点 FFT，长信号取中央 2048 点，短信号补零。
% Hann 窗按有效采样点归一化；幅度为单边峰值幅度，power 为各栅格功率。
arguments
    x (:,1) double {mustBeFinite}
    fs (1,1) double {mustBePositive,mustBeFinite} = 8192
end
N = min(numel(x),2048);
if N < 2, error('dtmf:TooShort','频谱至少需要两个有效采样点。'); end
a = floor((numel(x)-N)/2)+1; frame = x(a:a+N-1); frame = frame-mean(frame);
w = 0.5-0.5*cos(2*pi*(0:N-1)'/(N-1));
F = fft(frame.*w,2048); mag = abs(F(1:1025))/sum(w);
mag(2:end-1) = 2*mag(2:end-1);
power = abs(F(1:1025)).^2/(2048*sum(w.^2)); power(2:end-1)=2*power(2:end-1);
spectrum = struct('frequency',(0:1024)'*fs/2048,'amplitude',mag, ...
    'power',power,'nfft',2048,'validSamples',N,'gridHz',fs/2048);
end
