function frequencies = dtmfFrequencies(key)
%DTMFFREQUENCIES 查询单个标准 4×3 按键，返回 [低频 高频]，单位 Hz。
key = char(string(key));
keys = ['123';'456';'789';'*0#'];
if numel(key) ~= 1
    error('dtmf:InvalidKey','必须输入一个 0~9、* 或 # 按键。');
end
[r,c] = find(keys == key);
if isempty(r), error('dtmf:InvalidKey','无效 DTMF 按键。'); end
low = [697 770 852 941]; high = [1209 1336 1477];
frequencies = [low(r) high(c)];
end
