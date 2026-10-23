function result = dtmfRecognizeSequence(x,fs)
%DTMFRECOGNIZESEQUENCE 短时能量分段，填补 <=2 ms 的内部缺口；保留真实短静音。
% 不使用号码长度或固定音调周期。最小区间 12 ms，短片段交由单键识别返回 ?。
arguments
    x (:,1) double {mustBeFinite}
    fs (1,1) double {mustBePositive,mustBeFinite} = 8192
end
if fs~=8192, error('dtmf:SampleRate','请先重采样至 8192 Hz。'); end
segments=struct('key',{},'startSample',{},'endSample',{},'startTime',{},'endTime',{},'detail',{});
result=struct('keys',"",'segments',segments,'threshold',NaN,'energy',[],'fs',fs);
if isempty(x), return; end
x=x-mean(x); energy=movmean(x.^2,round(0.004*fs));
sorted=sort(energy); floorEnergy=sorted(max(1,round(0.10*numel(sorted))));
top=sorted(max(1,round(0.95*numel(sorted))));
% 无静音时低分位也属于音调；上限确保整段单音能够分段。
threshold=max(1e-10,min(0.25*top,max(4*floorEnergy,0.10*top)));
active=energy>threshold;
[a,b]=runs(~active);
for k=1:numel(a)
    if a(k)>1 && b(k)<numel(x) && b(k)-a(k)+1<=round(0.002*fs)
        active(a(k):b(k))=true;
    end
end
[a,b]=runs(active);
for k=1:numel(a)
    if b(k)-a(k)+1<round(0.012*fs), continue; end
    detail=dtmfRecognizeTone(x(a(k):b(k)),fs);
    segments(end+1)=struct('key',detail.key,'startSample',a(k),'endSample',b(k), ...
        'startTime',(a(k)-1)/fs,'endTime',b(k)/fs,'detail',detail); %#ok<AGROW>
end
result.segments=segments; result.energy=energy; result.threshold=threshold;
if ~isempty(segments), result.keys=join([segments.key],""); end
end

function [a,b]=runs(mask)
d=diff([false;mask;false]); a=find(d==1); b=find(d==-1)-1;
end
