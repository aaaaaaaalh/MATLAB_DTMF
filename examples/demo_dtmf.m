function demo_dtmf
%DEMO_DTMF 合成→WAV→导入→自动识别；生成数字 8 的报告用图片。
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'src'));
figDir=fullfile(root,'outputs','figures'); out=fullfile(root,'outputs','results');
if ~isfolder(figDir), mkdir(figDir); end
if ~isfolder(out), mkdir(out); end
a=dtmfSequence("13800123456"); file=fullfile(root,'examples','13800123456.wav');
dtmfWriteWav(file,a.signal,a.fs); b=dtmfReadWav(file); r=dtmfRecognizeSequence(b.signal,b.fs);
fprintf('输入号码：%s\n识别号码：%s\n',a.keys,r.keys);
save(fullfile(out,'demo_result.mat'),'a','r');
summary=table(a.keys,r.keys,a.keys==r.keys,'VariableNames',{'Expected','Recognized','Match'});
writetable(summary,fullfile(out,'demo_result.csv'));
x=dtmfTone('8',Samples=1000); s=dtmfSpectrum(x);
f=figure('Visible','off','Color','w'); cleanup=onCleanup(@()close(f)); %#ok<NASGU>
plot((0:numel(x)-1)/8192*1000,x); grid on;
xlabel('时间 (ms)'); ylabel('幅度 (归一化)'); title('数字 8：1000 点 DTMF 波形（852 Hz + 1336 Hz）');
exportgraphics(f,fullfile(figDir,'digit8_waveform.png'),'Resolution',200);
clf(f); plot(s.frequency,s.amplitude); grid on; xlim([0 2000]);
xline(852,'--r','预计 852 Hz'); xline(1336,'--r','预计 1336 Hz');
xlabel('频率 (Hz)'); ylabel('单边峰值幅度 (归一化)'); title('数字 8：2048 点 FFT，频率栅格 4 Hz');
exportgraphics(f,fullfile(figDir,'digit8_spectrum.png'),'Resolution',200);
save(fullfile(out,'digit8_spectrum.mat'),'x','s');
assert(a.keys==r.keys,'dtmf:DemoMismatch','演示号码识别不一致。');
end
