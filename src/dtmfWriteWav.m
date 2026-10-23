function dtmfWriteWav(filename,x,fs)
%DTMFWRITEWAV 导出完整单声道波形，超范围时整体归一化，避免削波。
arguments
    filename (1,1) string
    x (:,1) double {mustBeFinite}
    fs (1,1) double {mustBePositive,mustBeInteger} = 8192
end
if isempty(x), error('dtmf:EmptyAudio','不能导出空音频。'); end
peak=max(abs(x)); if peak>1, x=x*(0.999/peak); end
audiowrite(filename,x,fs,'BitsPerSample',24);
end
