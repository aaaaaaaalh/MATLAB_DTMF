function t=dtmfPixelTheme
%DTMFPIXELTHEME 本窗口的视觉配置；不设置 MATLAB 全局默认值。
t.Background=rgb('F7F5FB'); t.Panel=rgb('FFFFFF');
t.Text=rgb('34304D'); t.Border=rgb('666083'); t.Muted=rgb('686277');
t.Lavender=rgb('DCD4F4'); t.Blue=rgb('C8E8F9');
t.Green=rgb('A8DEBD'); t.Coral=rgb('F8C6BA'); t.Yellow=rgb('FFF0C8');
t.Wave=rgb('23749C'); t.Spectrum=rgb('7556A6'); t.Peak=rgb('B34B37');
t.Success=rgb('276044'); t.Warning=rgb('795B20'); t.Error=rgb('943E35');
t.BodySize=13; t.SmallSize=11; t.SectionSize=16;
t.TitleSize=26; t.KeySize=22; t.NumberSize=22; t.AxisSize=11;
t.BodyFont=get(groot,'DefaultUicontrolFontName');
t.DisplayFont=t.BodyFont;
try
    fonts=listfonts;
    t.BodyFont=chooseFont(fonts,{'Microsoft YaHei','Microsoft YaHei UI', ...
        'Noto Sans CJK SC','SimHei','Arial Unicode MS'},t.BodyFont);
    % 优先已有像素字体，其次为系统等宽字体；不下载字体。
    t.DisplayFont=chooseFont(fonts,{'Press Start 2P','Pixel Operator', ...
        'Cascadia Mono','Consolas','Courier New'},t.BodyFont);
catch
    % 字体枚举不可用时，沿用系统默认字体，仍能打开界面。
end
t.MinWidth=1080; t.MinWaveHeight=158; t.MinSpectrumHeight=194;
t.HeaderHeight=66; t.ResultsHeight=218;
end

function c=rgb(hex)
c=sscanf(hex,'%2x%2x%2x',[1 3])/255;
end

function font=chooseFont(fonts,candidates,fallback)
font=fallback;
for k=1:numel(candidates)
    if any(strcmpi(fonts,candidates{k})), font=candidates{k}; return; end
end
end
