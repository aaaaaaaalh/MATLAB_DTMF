function result = dtmfRecognizeTone(x,fs)
%DTMFRECOGNIZETONE FFT 双频判决。能量、频率容差、组内显著性、能量集中度及扭斜联合检查。
arguments
    x (:,1) double {mustBeFinite}
    fs (1,1) double {mustBePositive,mustBeFinite} = 8192
end
if fs ~= 8192, error('dtmf:SampleRate','请先重采样至 8192 Hz。'); end
result = struct('key',"?",'status',"rejected",'reason',"",'frequencies',[NaN NaN], ...
    'candidateFrequencies',[697 770 852 941 1209 1336 1477], ...
    'candidateAmplitudes',zeros(1,7),'energy',0,'concentration',0,'spectrum',[]);
if numel(x)<256, result.reason="信号短于 256 点"; return; end
result.energy = mean((x-mean(x)).^2);
if result.energy<1e-10, result.reason="有效能量不足"; return; end
s = dtmfSpectrum(x,fs); result.spectrum = s;
nominal = result.candidateFrequencies; peaks=zeros(1,7); hz=zeros(1,7);
for k=1:7
    indices=find(abs(s.frequency-nominal(k))<=16);
    [peaks(k),j]=max(s.amplitude(indices)); bin=indices(j);
    % 在对数幅度上插值，提高离栅格频率估计精度。
    y=log(max(s.amplitude(bin-1:bin+1),realmin));
    delta=0.5*(y(1)-y(3))/(y(1)-2*y(2)+y(3));
    hz(k)=s.frequency(bin)+max(-0.5,min(0.5,delta))*s.gridHz;
end
result.candidateAmplitudes=peaks;
[lo,r]=max(peaks(1:4)); [hi,c]=max(peaks(5:7));
result.frequencies=[hz(r) hz(c+4)];
otherLow=peaks(1:4); otherLow(r)=0; otherHigh=peaks(5:7); otherHigh(c)=0;
if any(abs(result.frequencies-[nominal(r) nominal(c+4)])>12)
    result.reason="峰值超出候选频率容差"; return;
end
if lo<3*max(otherLow) || hi<3*max(otherHigh)
    result.reason="组内峰值显著性不足"; return;
end
if min(lo,hi)/max(lo,hi)<0.25
    result.reason="双频幅度比异常或缺少一个频率"; return;
end
mask=abs(s.frequency-result.frequencies(1))<=24 | abs(s.frequency-result.frequencies(2))<=24;
result.concentration=sum(s.power(mask))/max(sum(s.power),realmin);
if result.concentration<0.60
    result.reason="双频能量集中度不足"; return;
end
keys=['123';'456';'789';'*0#'];
result.key=string(keys(r,c)); result.status="accepted"; result.reason="通过 FFT 双频检查";
end
