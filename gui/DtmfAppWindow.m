classdef DtmfAppWindow < handle
    %DTMFAPPWINDOW 原生单窗口界面；状态由 DtmfSession 管理，音频播放器唯一持有。
    properties (SetAccess=private)
        Figure
        Session
        UI = struct()
        Player = []
        SelectedSegment = 1
    end
    methods
        function obj=DtmfAppWindow(visible)
            obj.Session=DtmfSession;
            try
                obj.buildUI;
                obj.refresh;
                obj.Figure.Visible=char(visible);
            catch exception
                delete(obj);
                rethrow(exception);
            end
        end
        function pressKey(obj,key)
            % 公共操作接口也供自动检查使用；控件回调通过 guarded 显示中文错误。
            key=string(key);
            obj.stopPlayback;
            if key=="*"
                obj.Session.backspace;
            elseif key=="#"
                obj.Session.recognize(true);
            else
                obj.Session.appendDigit(key);
            end
            obj.SelectedSegment=max(1,numel(obj.Session.getSegments));
            obj.refresh;
            if key~="*" && key~="#" && obj.UI.Audition.Value
                % 使用实际刚合成区间，基准模式也严格播放 1000 点。
                [x,~,~]=obj.Session.segmentAudio(obj.SelectedSegment);
                obj.playSignal(x);
            end
        end
        function clearAudio(obj)
            obj.stopPlayback; obj.Session.clear; obj.SelectedSegment=1; obj.refresh;
        end
        function recognize(obj)
            obj.Session.recognize(false); obj.SelectedSegment=1; obj.refresh;
        end
        function configure(obj)
            obj.stopPlayback;
            modes=["default","baseline"];
            obj.Session.configure(modes(obj.UI.Mode.Value),obj.UI.Tone.Value,obj.UI.Gap.Value);
            obj.SelectedSegment=1; obj.refresh;
        end
        function importFile(obj,filename)
            obj.stopPlayback;
            obj.Session.importWav(filename); obj.SelectedSegment=1; obj.refresh;
        end
        function exportFile(obj,filename)
            obj.Session.exportWav(filename);
            obj.UI.Status.Text='已导出完整音频。';
            obj.UI.Status.FontColor=obj.UI.Theme.Success;
        end
        function selectSegment(obj,index)
            segments=obj.Session.getSegments;
            if isempty(segments), return; end
            validateattributes(index,{'numeric'},{'scalar','integer','>=',1,'<=',numel(segments)});
            obj.SelectedSegment=index; obj.UI.Segment.Value=index; obj.renderSpectrum;
        end
        function playAll(obj)
            obj.Session.requireAudio;
            obj.playSignal(obj.Session.Audio.signal);
        end
        function stopPlayback(obj)
            player=obj.Player; obj.Player=[];
            if ~isempty(player)
                if isvalid(player)
                    player.StopFcn=[];
                    % 即使声卡停止时异常，仍释放播放器。
                    cleanup=onCleanup(@()delete(player));
                    stop(player);
                end
            end
            if isfield(obj.UI,'Playback') && isgraphics(obj.UI.Playback)
                obj.UI.Playback.Text='播放：已停止';
                obj.UI.Playback.FontColor=obj.UI.Theme.Muted;
            end
        end
        function delete(obj)
            % 先解除音频回调，避免停止事件访问正在销毁的窗口。
            try
                obj.stopPlayback;
            catch
                % 声卡异常不能阻止窗口销毁，播放器已由 onCleanup 释放。
            end
            if ~isempty(obj.Figure) && isgraphics(obj.Figure)
                obj.Figure.CloseRequestFcn=[];
                obj.Figure.UserData=[];
                delete(obj.Figure);
            end
        end
    end
    methods (Access=private)
        function buildUI(obj)
            t=dtmfPixelTheme; obj.UI.Theme=t;
            screen=get(groot,'ScreenSize');
            width=min(1480,screen(3)-64); height=min(940,screen(4)-80);
            obj.Figure=uifigure('Name','Pixel DSP Lab | DTMF 实验系统', ...
                'Position',[screen(1)+32 screen(2)+40 width height],'Visible','off', ...
                'AutoResizeChildren','off','Color',t.Background);
            obj.Figure.UserData=obj;
            obj.Figure.CloseRequestFcn=@(~,~)delete(obj);
            obj.Figure.SizeChangedFcn=@(~,~)obj.keepMinimumSize;
            root=uigridlayout(obj.Figure,[4 2],'Scrollable','on'); obj.UI.Root=root;
            root.ColumnWidth={332,'1x'};
            root.RowHeight={t.HeaderHeight,'1x','1.15x',t.ResultsHeight};
            root.Padding=[10 10 10 10]; root.RowSpacing=8; root.ColumnSpacing=10;
            root.BackgroundColor=t.Background;

            header=uipanel(root,'BackgroundColor',t.Lavender,'BorderType','line', ...
                'HighlightColor',t.Border);
            header.Layout.Row=1; header.Layout.Column=[1 2];
            g=uigridlayout(header,[2 3]); g.Padding=[14 5 14 5];
            g.ColumnWidth={36,'1x',270}; g.RowHeight={32,20};
            g.RowSpacing=1; g.BackgroundColor=t.Lavender;
            pixels=uigridlayout(g,[3 3]); pixels.Layout.Row=[1 2];
            pixels.Padding=[0 8 0 8]; pixels.RowSpacing=3; pixels.ColumnSpacing=3;
            pixels.BackgroundColor=t.Lavender;
            for k=1:9
                color=t.Border;
                if any(k==[2 6 7]), color=t.Blue; end
                uipanel(pixels,'BorderType','none','BackgroundColor',color);
            end
            obj.UI.Brand=uilabel(g,'Text','PIXEL DSP LAB','FontWeight','bold');
            obj.UI.Brand.Layout.Row=1; obj.UI.Brand.Layout.Column=2;
            subtitle=uilabel(g,'Text','DTMF 电话拨号音合成与识别实验系统');
            subtitle.Layout.Row=2; subtitle.Layout.Column=2;
            specs=uilabel(g,'Text','Fs 8192 Hz  /  FFT 2048', ...
                'HorizontalAlignment','right');
            specs.Layout.Row=1; specs.Layout.Column=3;
            obj.UI.LabState=uilabel(g,'Text','READY / 等待输入','HorizontalAlignment','right');
            obj.UI.LabState.Layout.Row=2; obj.UI.LabState.Layout.Column=3;

            left=obj.labPanel(root,'01  DIAL / 拨号控制台');
            left.Layout.Row=[2 4]; left.Layout.Column=1;
            g=uigridlayout(left,[10 1]);
            g.RowHeight={22,44,22,32,30,30,'1x',32,32,40};
            g.RowSpacing=6; g.Padding=[12 10 12 10];
            uilabel(g,'Text','当前号码 / NUMBER');
            obj.UI.Number=uieditfield(g,'text','Editable','off','Value','');
            obj.UI.Confirmed=uilabel(g,'Text','尚未确认');
            % 保留数值 ItemsData 和分步初始化，避免 default 的属性语义。
            obj.UI.Mode=uidropdown(g);
            obj.UI.Mode.Items={'时间模式：可调整毫秒','指导书：1000 点 / 100 点'};
            obj.UI.Mode.ItemsData=[1 2]; obj.UI.Mode.Value=1;
            obj.UI.Mode.ValueChangedFcn=@(~,~)obj.guarded(@()obj.configure);
            row=uigridlayout(g,[1 2]); row.Padding=[0 0 0 0]; row.ColumnWidth={154,'1x'};
            uilabel(row,'Text','按键持续时间 (ms)');
            obj.UI.Tone=uieditfield(row,'numeric','Limits',[40 3000],'Value',300, ...
                'ValueChangedFcn',@(~,~)obj.guarded(@()obj.configure));
            row=uigridlayout(g,[1 2]); row.Padding=[0 0 0 0]; row.ColumnWidth={154,'1x'};
            uilabel(row,'Text','静音间隔 (ms)');
            obj.UI.Gap=uieditfield(row,'numeric','Limits',[0 2000],'Value',100, ...
                'ValueChangedFcn',@(~,~)obj.guarded(@()obj.configure));
            keys=uigridlayout(g,[4 3]); keys.Padding=[0 4 0 4];
            keys.RowSpacing=8; keys.ColumnSpacing=8;
            labels={'1','2','3','4','5','6','7','8','9','* 删除','0','# 确认'};
            values='123456789*0#'; obj.UI.Keys=gobjects(1,12);
            for k=1:12
                key=values(k);
                obj.UI.Keys(k)=uibutton(keys,'Text',labels{k}, ...
                    'ButtonPushedFcn',@(~,~)obj.guarded(@()obj.pressKey(key)));
                obj.UI.Keys(k).Layout.Row=ceil(k/3); obj.UI.Keys(k).Layout.Column=mod(k-1,3)+1;
            end
            row=uigridlayout(g,[1 2]); row.Padding=[0 0 0 0];
            obj.UI.Play=uibutton(row,'Text','播放完整号码','ButtonPushedFcn',@(~,~)obj.guarded(@()obj.playAll));
            obj.UI.Stop=uibutton(row,'Text','停止播放','ButtonPushedFcn',@(~,~)obj.guarded(@()obj.stopPlayback));
            row=uigridlayout(g,[1 2]); row.Padding=[0 0 0 0]; row.ColumnWidth={'1.2x','1x'};
            obj.UI.Clear=uibutton(row,'Text','清空号码 / 音频','ButtonPushedFcn',@(~,~)obj.guarded(@()obj.clearAudio));
            obj.UI.Audition=uicheckbox(row,'Text','按键试听','Value',true);
            hint=uilabel(g,'Text',sprintf('* 删除末位 / # 确认识别\n导入后按数字键新建号码；零间隔可能合并重复音'), ...
                'WordWrap','on','BackgroundColor',t.Yellow);

            panel=obj.labPanel(root,'02  SIGNAL / 时域波形'); panel.Layout.Row=2; panel.Layout.Column=2;
            grid=uigridlayout(panel,[1 1]); grid.Padding=[8 2 8 2];
            obj.UI.Wave=uiaxes(grid);

            panel=obj.labPanel(root,'03  SPECTRUM / FFT 频谱'); panel.Layout.Row=3; panel.Layout.Column=2;
            grid=uigridlayout(panel,[3 1]); grid.RowHeight={28,'1x',30};
            grid.RowSpacing=2; grid.Padding=[8 4 8 4];
            row=uigridlayout(grid,[1 2]); row.Padding=[0 0 0 0]; row.ColumnWidth={110,'1x'};
            uilabel(row,'Text','选择分析按键');
            obj.UI.Segment=uidropdown(row);
            obj.UI.Segment.Items={'暂无片段'}; obj.UI.Segment.ItemsData=0; obj.UI.Segment.Value=0;
            obj.UI.Segment.ValueChangedFcn=@(~,~)obj.guarded(@()obj.selectSegment(obj.UI.Segment.Value));
            obj.UI.Spectrum=uiaxes(grid);
            obj.UI.Frequencies=uilabel(grid,'Text','等待音频','WordWrap','on');

            panel=obj.labPanel(root,'04  DECODE / 识别与 WAV'); panel.Layout.Row=4; panel.Layout.Column=2;
            grid=uigridlayout(panel,[5 1]); grid.RowHeight={30,34,20,18,'1x'};
            grid.RowSpacing=3; grid.Padding=[8 5 8 5];
            row=uigridlayout(grid,[1 4]); row.Padding=[0 0 0 0]; row.ColumnWidth={138,108,138,'1x'};
            obj.UI.Recognize=uibutton(row,'Text','识别当前音频','ButtonPushedFcn',@(~,~)obj.guarded(@()obj.recognize));
            obj.UI.Import=uibutton(row,'Text','导入 WAV','ButtonPushedFcn',@(~,~)obj.guarded(@()obj.chooseImport));
            obj.UI.Export=uibutton(row,'Text','导出完整 WAV','ButtonPushedFcn',@(~,~)obj.guarded(@()obj.chooseExport));
            obj.UI.Playback=uilabel(row,'Text','播放：已停止','HorizontalAlignment','right');
            row=uigridlayout(grid,[1 2]); row.Padding=[0 0 0 0]; row.ColumnWidth={82,'1x'};
            uilabel(row,'Text','识别号码');
            obj.UI.Result=uieditfield(row,'text','Editable','off');
            obj.UI.Status=uilabel(grid,'Text','等待输入');
            obj.UI.AudioInfo=uilabel(grid,'Text','8192 Hz');
            obj.UI.Table=uitable(grid,'ColumnName',{'序号','按键','开始(s)','结束(s)','低频(Hz)','高频(Hz)','判决','原因'}, ...
                'ColumnWidth',{42,44,72,72,78,78,66,'auto'},'RowName',{}, ...
                'CellSelectionCallback',@(~,event)obj.guarded(@()obj.tableSelected(event)));
            % 主题只作用于当前窗口；原有控件字段、数据和回调均保留。
            set(findall(obj.Figure,'-property','FontName'),'FontName',t.BodyFont);
            set(findall(obj.Figure,'-property','FontSize'),'FontSize',t.BodySize);
            set(findall(obj.Figure,'-property','FontColor'),'FontColor',t.Text);
            layouts=findall(obj.Figure,'Type','uigridlayout');
            set(layouts,'BackgroundColor',t.Panel);
            root.BackgroundColor=t.Background; gHeader=header.Children;
            gHeader.BackgroundColor=t.Lavender; pixels.BackgroundColor=t.Lavender;
            panels=[left; findall(root,'Type','uipanel')];
            for k=1:numel(panels)
                if ~isempty(panels(k).Title), panels(k).FontSize=t.SectionSize; end
            end
            buttons=findall(obj.Figure,'Type','uibutton');
            set(buttons,'BackgroundColor',t.Blue,'FontWeight','bold');
            obj.UI.Keys(10).BackgroundColor=t.Coral; obj.UI.Keys(12).BackgroundColor=t.Green;
            obj.UI.Recognize.BackgroundColor=t.Green; obj.UI.Clear.BackgroundColor=t.Lavender;
            obj.UI.Stop.BackgroundColor=t.Yellow;
            set(obj.UI.Keys,'FontSize',t.KeySize);
            set(obj.UI.Keys([1:9 11]),'FontName',t.DisplayFont);
            set(obj.UI.Keys([10 12]),'FontSize',18);
            obj.UI.Brand.FontName=t.DisplayFont; obj.UI.Brand.FontSize=t.TitleSize;
            specs.FontName=t.DisplayFont;
            obj.UI.Number.FontName=t.DisplayFont; obj.UI.Number.FontSize=t.NumberSize;
            obj.UI.Number.BackgroundColor=t.Background;
            obj.UI.Result.FontName=t.DisplayFont; obj.UI.Result.FontSize=t.NumberSize;
            obj.UI.Result.BackgroundColor=t.Background;
            set([hint,obj.UI.AudioInfo,obj.UI.Frequencies],'FontSize',t.SmallSize);
            obj.UI.Table.FontSize=12; obj.UI.Table.BackgroundColor=[t.Panel;t.Background];
            obj.UI.Table.ForegroundColor=t.Text;
            obj.styleAxes(obj.UI.Wave); obj.styleAxes(obj.UI.Spectrum);
            obj.keepMinimumSize;
        end
        function panel=labPanel(obj,parent,label)
            t=obj.UI.Theme;
            panel=uipanel(parent,'Title',label,'FontWeight','bold', ...
                'BackgroundColor',t.Panel,'BorderType','line','HighlightColor',t.Border);
        end
        function styleAxes(obj,ax)
            t=obj.UI.Theme;
            ax.FontName=t.BodyFont; ax.FontSize=t.AxisSize;
            ax.Color=t.Panel; ax.XColor=t.Muted; ax.YColor=t.Muted;
            ax.GridColor=t.Border; ax.GridAlpha=0.16; ax.LineWidth=0.8;
            ax.TitleFontSizeMultiplier=1; ax.LabelFontSizeMultiplier=1;
            ax.Title.Color=t.Text; ax.Title.FontWeight='normal';
            ax.Box='on'; ax.XGrid='on'; ax.YGrid='on';
        end

        function refresh(obj)
            t=obj.UI.Theme;
            state=obj.Session; audio=state.Audio;
            obj.UI.Number.Value=char(state.Digits);
            obj.UI.Mode.Value=1+double(state.Mode=="baseline");
            obj.UI.Tone.Value=state.ToneMs; obj.UI.Gap.Value=state.GapMs;
            enable='on'; if state.Mode=="baseline", enable='off'; end
            obj.UI.Tone.Enable=enable; obj.UI.Gap.Enable=enable;
            if state.Confirmed
                obj.UI.Confirmed.Text='已确认 / 音频已保留'; obj.UI.Confirmed.FontColor=t.Success;
            else
                obj.UI.Confirmed.Text='尚未确认'; obj.UI.Confirmed.FontColor=t.Muted;
            end
            x=audio.signal; ax=obj.UI.Wave; cla(ax);
            if ~isempty(x)
                plot(ax,(0:numel(x)-1)/audio.fs,x,'Color',t.Wave,'LineWidth',1.15);
                xlim(ax,[0 max(1/audio.fs,numel(x)/audio.fs)]);
            end
            xlabel(ax,'时间 (s)'); ylabel(ax,'幅度'); gridOn(ax);
            title(ax,char(state.SourceName),'Interpreter','none');
            obj.UI.AudioInfo.Text=sprintf('%s | %d Hz | %.3f s | %d 点',state.SourceName,audio.fs,numel(x)/audio.fs,numel(x));
            if state.Source=="wav"
                obj.UI.AudioInfo.Text=sprintf('导入 %d Hz / %d 声道 → 8192 Hz 单声道 | %.3f s', ...
                    audio.originalFs,audio.originalChannels,numel(x)/audio.fs);
            end
            segments=state.getSegments; count=numel(segments);
            obj.UI.Segment.ItemsData=[];
            if count==0
                obj.UI.Segment.Items={'暂无片段'}; obj.UI.Segment.ItemsData=0; obj.UI.Segment.Value=0; obj.UI.Segment.Enable='off';
            else
                obj.UI.Segment.Items=arrayfun(@(k)sprintf('%d：%s  [%.3f, %.3f) s',k,segments(k).key,segments(k).startTime,segments(k).endTime),1:count,'UniformOutput',false);
                obj.UI.Segment.ItemsData=1:count;
                obj.SelectedSegment=min(max(1,obj.SelectedSegment),count);
                obj.UI.Segment.Value=obj.SelectedSegment; obj.UI.Segment.Enable='on';
            end
            obj.UI.Result.Value=''; obj.UI.Status.Text='请按 # 确认，或点击“识别当前音频”。';
            if isempty(x), obj.UI.Status.Text='请输入号码或导入 WAV 文件。'; end
            data=cell(count,8);
            for k=1:count
                s=segments(k); data(k,1:4)={k,char(s.key),s.startTime,s.endTime};
                data(k,5:8)={NaN,NaN,'待识别','选择片段可查看频谱'};
                if isfield(s,'detail')
                    d=s.detail; status='不确定'; if d.status=="accepted", status='通过'; end
                    data(k,5:8)={d.frequencies(1),d.frequencies(2),status,char(d.reason)};
                end
            end
            obj.UI.Table.Data=data;
            if ~isempty(state.Recognition)
                result=state.Recognition; obj.UI.Result.Value=char(result.keys);
                unknown=countChars(result.keys,'?');
                if count==0
                    obj.UI.Status.Text='未检测到有效 DTMF 片段。';
                else
                    obj.UI.Status.Text=sprintf('检测到 %d 个片段，不确定字符 ?：%d 个。',count,unknown);
                    if state.Source=="dial"
                        if result.keys==state.Digits, suffix=' 与输入号码一致。'; else, suffix=' 与输入号码不一致，请检查片段。'; end
                        obj.UI.Status.Text=[obj.UI.Status.Text suffix];
                    end
                end
            end
            obj.renderSpectrum;
            obj.styleRecognition;
        end
        function styleRecognition(obj)
            % 只根据已有结果设置显示样式，不改变任何识别判决。
            t=obj.UI.Theme; state=obj.Session;
            obj.UI.Status.FontColor=t.Muted;
            obj.UI.Result.BackgroundColor=t.Background; obj.UI.Result.FontColor=t.Text;
            obj.UI.LabState.Text='READY / 等待输入'; obj.UI.LabState.FontColor=t.Text;
            if ~isempty(state.Audio.signal), obj.UI.LabState.Text='SIGNAL / 音频就绪'; end
            removeStyle(obj.UI.Table);
            if isempty(state.Recognition), return; end
            result=state.Recognition;
            if isempty(result.segments) || contains(result.keys,'?')
                color=t.Warning; background=t.Yellow; label='CHECK / 存在不确定结果';
            elseif state.Source=="dial" && result.keys~=state.Digits
                color=t.Error; background=t.Coral; label='CHECK / 与输入不一致';
            else
                color=t.Success; background=t.Green; label='DECODED / 识别完成';
            end
            obj.UI.Result.BackgroundColor=background; obj.UI.Result.FontColor=color;
            obj.UI.Status.FontColor=color;
            obj.UI.LabState.Text=label; obj.UI.LabState.FontColor=color;
            data=obj.UI.Table.Data;
            if ~isempty(data)
                accepted=find(strcmp(data(:,7),'通过'));
                uncertain=find(strcmp(data(:,7),'不确定'));
                if ~isempty(accepted)
                    addStyle(obj.UI.Table,uistyle('FontColor',t.Success,'BackgroundColor',t.Green), ...
                        'cell',[accepted,repmat(7,numel(accepted),1)]);
                end
                if ~isempty(uncertain)
                    addStyle(obj.UI.Table,uistyle('FontColor',t.Warning,'BackgroundColor',t.Yellow), ...
                        'cell',[uncertain,repmat(7,numel(uncertain),1)]);
                end
            end
        end
        function renderSpectrum(obj)
            t=obj.UI.Theme;
            ax=obj.UI.Spectrum; cla(ax); segments=obj.Session.getSegments;
            if isempty(segments)
                x=obj.Session.Audio.signal;
                if numel(x)>=2
                    s=dtmfSpectrum(x); plot(ax,s.frequency,s.amplitude,'Color',t.Spectrum,'LineWidth',1.4);
                    obj.UI.Frequencies.Text='无有效按键片段；显示当前音频中央帧频谱。';
                else
                    obj.UI.Frequencies.Text='等待音频；采样率 8192 Hz，FFT 2048 点。';
                end
            else
                [x,d,segment]=obj.Session.segmentAudio(obj.SelectedSegment);
                if numel(x)>=2
                    s=dtmfSpectrum(x); plot(ax,s.frequency,s.amplitude,'Color',t.Spectrum,'LineWidth',1.4); hold(ax,'on');
                    if d.status=="accepted"
                        nominal=dtmfFrequencies(d.key);
                        for k=1:2
                            xline(ax,nominal(k),'--','Color',t.Border,'LineWidth',1);
                            height=interp1(s.frequency,s.amplitude,d.frequencies(k));
                            plot(ax,d.frequencies(k),height,'v','Color',t.Peak,'MarkerFaceColor',t.Peak,'MarkerSize',6);
                        end
                        obj.UI.Frequencies.Text=sprintf('数字 %s：标称 %d / %d Hz；检测 %.1f / %.1f Hz；有效 %d 点', ...
                            d.key,nominal(1),nominal(2),d.frequencies(1),d.frequencies(2),s.validSamples);
                    else
                        obj.UI.Frequencies.Text=sprintf('片段 %d：?（%s）；候选 %.1f / %.1f Hz', ...
                            obj.SelectedSegment,d.reason,d.frequencies(1),d.frequencies(2));
                    end
                    hold(ax,'off');
                end
                % 时域用两条虚线标记选定区间；不重绘整段信号。
                delete(findall(obj.UI.Wave,'Tag','SegmentBoundary'));
                xline(obj.UI.Wave,segment.startTime,'--','Color',t.Peak,'Tag','SegmentBoundary');
                xline(obj.UI.Wave,segment.endTime,'--','Color',t.Peak,'Tag','SegmentBoundary');
            end
            xlabel(ax,'频率 (Hz)'); ylabel(ax,'单边幅度'); xlim(ax,[0 2000]); gridOn(ax);
            title(ax,'2048 点 FFT · 8192 Hz · 栅格间隔 4 Hz');
            obj.styleAxes(ax); obj.styleAxes(obj.UI.Wave);
        end
        function playSignal(obj,x)
            obj.stopPlayback;
            player=audioplayer(x,obj.Session.Audio.fs);
            obj.Player=player;
            player.StopFcn=@(~,~)obj.playbackFinished;
            try
                play(player); obj.UI.Playback.Text='播放：进行中';
                obj.UI.Playback.FontColor=obj.UI.Theme.Success;
            catch exception
                obj.stopPlayback;
                error('dtmf:Playback','无法播放音频，请检查输出设备：%s',exception.message);
            end
        end
        function playbackFinished(obj)
            if isvalid(obj) && isgraphics(obj.Figure)
                obj.UI.Playback.Text='播放：已结束';
                obj.UI.Playback.FontColor=obj.UI.Theme.Muted;
            end
        end
        function chooseImport(obj)
            [name,folder]=uigetfile({'*.wav','WAV 音频 (*.wav)'},'导入 DTMF 音频');
            if isequal(name,0), return; end
            obj.importFile(fullfile(folder,name));
        end
        function chooseExport(obj)
            obj.Session.requireAudio;
            [name,folder]=uiputfile({'*.wav','WAV 音频 (*.wav)'},'导出完整音频','dtmf.wav');
            if isequal(name,0), return; end
            [~,~,extension]=fileparts(name); if ~strcmpi(extension,'.wav'), name=[name '.wav']; end
            obj.exportFile(fullfile(folder,name));
        end
        function tableSelected(obj,event)
            if ~isempty(event.Indices), obj.selectSegment(event.Indices(1,1)); end
        end
        function guarded(obj,operation)
            try
                operation();
            catch exception
                if isgraphics(obj.Figure)
                    obj.UI.Status.Text='操作未完成，请检查提示。';
                    obj.UI.Status.FontColor=obj.UI.Theme.Error;
                    obj.UI.LabState.Text='ERROR / 请检查提示';
                    obj.UI.LabState.FontColor=obj.UI.Theme.Error;
                    uialert(obj.Figure,sprintf('操作未完成：\n%s',exception.message),'DTMF 操作提示','Icon','error');
                end
            end
        end
        function keepMinimumSize(obj)
            if ~isfield(obj.UI,'Root'), return; end
            p=obj.Figure.Position; t=obj.UI.Theme;
            % 小窗口保持图表和表格最小高度，用原生滚动访问全部区域。
            results=t.ResultsHeight;
            if p(4)>=800, results=260; end
            if p(4)>=900, results=280; end
            available=p(4)-20-24-t.HeaderHeight-results;
            if available<t.MinWaveHeight+t.MinSpectrumHeight
                obj.UI.Root.RowHeight={t.HeaderHeight,t.MinWaveHeight,t.MinSpectrumHeight,results};
            else
                wave=max(t.MinWaveHeight,floor(available*0.45));
                obj.UI.Root.RowHeight={t.HeaderHeight,wave,available-wave,results};
            end
            if p(3)<t.MinWidth
                obj.UI.Root.ColumnWidth={332,t.MinWidth-362};
            else
                obj.UI.Root.ColumnWidth={332,'1x'};
            end
        end
    end
end

function gridOn(ax)
ax.XGrid='on'; ax.YGrid='on'; ax.Box='on';
end

function n=countChars(value,character)
n=sum(char(value)==character);
end
