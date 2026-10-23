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
            screen=get(groot,'ScreenSize');
            width=min(1200,screen(3)-60); height=min(840,screen(4)-100);
            obj.Figure=uifigure('Name','DTMF 电话拨号音合成与识别实验', ...
                'Position',[screen(1)+30 screen(2)+40 width height],'Visible','off', ...
                'AutoResizeChildren','off','Color',[0.94 0.94 0.94]);
            obj.Figure.UserData=obj;
            obj.Figure.CloseRequestFcn=@(~,~)delete(obj);
            obj.Figure.SizeChangedFcn=@(~,~)obj.keepMinimumSize;
            root=uigridlayout(obj.Figure,[3 2],'Scrollable','on'); obj.UI.Root=root;
            root.ColumnWidth={290,'1x'}; root.RowHeight={'1x','1x',230};
            root.Padding=[12 12 12 12]; root.RowSpacing=10; root.ColumnSpacing=10;
            left=uipanel(root,'Title','电话拨号面板','FontWeight','bold');
            left.Layout.Row=[1 3]; left.Layout.Column=1;
            g=uigridlayout(left,[10 1]);
            g.RowHeight={24,46,24,32,32,32,'1x',34,34,58}; g.RowSpacing=8;
            uilabel(g,'Text','当前拨号号码（仅追加数字）');
            obj.UI.Number=uieditfield(g,'text','Editable','off','FontSize',22,'Value','');
            obj.UI.Confirmed=uilabel(g,'Text','尚未确认','FontColor',[0.35 0.35 0.35]);
            % 控件使用数值标识，避免字符值 default 的属性默认值语义。
            % 分步设置 Items、ItemsData、Value，确保每次赋值都有合法候选。
            obj.UI.Mode=uidropdown(g);
            obj.UI.Mode.Items={'时间模式：可调整毫秒','指导书：1000 点 / 100 点'};
            obj.UI.Mode.ItemsData=[1 2];
            obj.UI.Mode.Value=1;
            obj.UI.Mode.ValueChangedFcn=@(~,~)obj.guarded(@()obj.configure);
            row=uigridlayout(g,[1 2]); row.Padding=[0 0 0 0]; row.ColumnWidth={120,'1x'};
            uilabel(row,'Text','按键持续时间 (ms)');
            obj.UI.Tone=uieditfield(row,'numeric','Limits',[40 3000],'Value',300, ...
                'ValueChangedFcn',@(~,~)obj.guarded(@()obj.configure));
            row=uigridlayout(g,[1 2]); row.Padding=[0 0 0 0]; row.ColumnWidth={120,'1x'};
            uilabel(row,'Text','静音间隔 (ms)');
            obj.UI.Gap=uieditfield(row,'numeric','Limits',[0 2000],'Value',100, ...
                'ValueChangedFcn',@(~,~)obj.guarded(@()obj.configure));
            keys=uigridlayout(g,[4 3]); keys.Padding=[0 4 0 4];
            labels={'1','2','3','4','5','6','7','8','9','* 删除','0','# 确认'};
            values='123456789*0#';
            obj.UI.Keys=gobjects(1,12);
            for k=1:12
                key=values(k);
                obj.UI.Keys(k)=uibutton(keys,'Text',labels{k},'FontSize',22, ...
                    'ButtonPushedFcn',@(~,~)obj.guarded(@()obj.pressKey(key)));
                obj.UI.Keys(k).Layout.Row=ceil(k/3); obj.UI.Keys(k).Layout.Column=mod(k-1,3)+1;
            end
            row=uigridlayout(g,[1 2]); row.Padding=[0 0 0 0];
            obj.UI.Play=uibutton(row,'Text','播放完整号码','ButtonPushedFcn',@(~,~)obj.guarded(@()obj.playAll));
            obj.UI.Stop=uibutton(row,'Text','停止播放','ButtonPushedFcn',@(~,~)obj.guarded(@()obj.stopPlayback));
            row=uigridlayout(g,[1 2]); row.Padding=[0 0 0 0];
            obj.UI.Clear=uibutton(row,'Text','清空号码 / 音频','ButtonPushedFcn',@(~,~)obj.guarded(@()obj.clearAudio));
            obj.UI.Audition=uicheckbox(row,'Text','按键试听','Value',true);
            uilabel(g,'Text',sprintf('* 删除末位；# 确认并识别\n导入后按数字键开始新号码\n无静音间隔可能无法区分重复数字'), ...
                'WordWrap','on','FontSize',12);

            panel=uipanel(root,'Title','时域波形','FontWeight','bold'); panel.Layout.Row=1; panel.Layout.Column=2;
            grid=uigridlayout(panel,[1 1]);
            obj.UI.Wave=uiaxes(grid); xlabel(obj.UI.Wave,'时间 (s)'); ylabel(obj.UI.Wave,'幅度'); gridOn(obj.UI.Wave);
            panel=uipanel(root,'Title','FFT 频谱分析','FontWeight','bold'); panel.Layout.Row=2; panel.Layout.Column=2;
            grid=uigridlayout(panel,[3 1]); grid.RowHeight={28,'1x',34}; grid.RowSpacing=3;
            row=uigridlayout(grid,[1 2]); row.Padding=[0 0 0 0]; row.ColumnWidth={90,'1x'};
            uilabel(row,'Text','选择分析按键');
            obj.UI.Segment=uidropdown(row);
            obj.UI.Segment.Items={'暂无片段'};
            obj.UI.Segment.ItemsData=0;
            obj.UI.Segment.Value=0;
            obj.UI.Segment.ValueChangedFcn=@(~,~)obj.guarded(@()obj.selectSegment(obj.UI.Segment.Value));
            obj.UI.Spectrum=uiaxes(grid); xlabel(obj.UI.Spectrum,'频率 (Hz)'); ylabel(obj.UI.Spectrum,'单边幅度'); gridOn(obj.UI.Spectrum);
            obj.UI.Frequencies=uilabel(grid,'Text','等待音频','WordWrap','on','FontSize',12);

            panel=uipanel(root,'Title','识别结果与 WAV 文件','FontWeight','bold'); panel.Layout.Row=3; panel.Layout.Column=2;
            grid=uigridlayout(panel,[5 1]); grid.RowHeight={30,26,20,20,'1x'}; grid.RowSpacing=4; grid.Padding=[8 6 8 6];
            row=uigridlayout(grid,[1 4]); row.Padding=[0 0 0 0];
            obj.UI.Recognize=uibutton(row,'Text','识别当前音频','ButtonPushedFcn',@(~,~)obj.guarded(@()obj.recognize));
            obj.UI.Import=uibutton(row,'Text','导入 WAV','ButtonPushedFcn',@(~,~)obj.guarded(@()obj.chooseImport));
            obj.UI.Export=uibutton(row,'Text','导出完整 WAV','ButtonPushedFcn',@(~,~)obj.guarded(@()obj.chooseExport));
            obj.UI.Playback=uilabel(row,'Text','播放：已停止');
            row=uigridlayout(grid,[1 2]); row.Padding=[0 0 0 0]; row.ColumnWidth={70,'1x'};
            uilabel(row,'Text','识别号码');
            obj.UI.Result=uieditfield(row,'text','Editable','off','FontSize',16);
            obj.UI.Status=uilabel(grid,'Text','等待输入');
            obj.UI.AudioInfo=uilabel(grid,'Text','8192 Hz','FontSize',12);
            obj.UI.Table=uitable(grid,'ColumnName',{'序号','按键','开始(s)','结束(s)','低频(Hz)','高频(Hz)','判决','原因'}, ...
                'ColumnWidth',{40,45,65,65,70,70,70,260},'RowName',{}, ...
                'CellSelectionCallback',@(~,event)obj.guarded(@()obj.tableSelected(event)));
            % 仅设置本窗口字体，不修改 MATLAB 根对象或其他工程的默认值。
            font='Microsoft YaHei';
            try
                fonts=listfonts;
                for candidate=["Microsoft YaHei","SimHei","Noto Sans CJK SC","Arial Unicode MS"]
                    if any(strcmpi(fonts,candidate)), font=char(candidate); break; end
                end
            catch
                % Windows 默认使用微软雅黑；字体失败不影响 DSP。
            end
            objects=findall(obj.Figure,'-property','FontName');
            set(objects,'FontName',font);
            obj.keepMinimumSize;
        end
        function refresh(obj)
            state=obj.Session; audio=state.Audio;
            obj.UI.Number.Value=char(state.Digits);
            obj.UI.Mode.Value=1+double(state.Mode=="baseline");
            obj.UI.Tone.Value=state.ToneMs; obj.UI.Gap.Value=state.GapMs;
            enable='on'; if state.Mode=="baseline", enable='off'; end
            obj.UI.Tone.Enable=enable; obj.UI.Gap.Enable=enable;
            if state.Confirmed
                obj.UI.Confirmed.Text='✓ 已确认（音频已保留）'; obj.UI.Confirmed.FontColor=[0 .45 .15];
            else
                obj.UI.Confirmed.Text='尚未确认'; obj.UI.Confirmed.FontColor=[.35 .35 .35];
            end
            x=audio.signal; ax=obj.UI.Wave; cla(ax);
            if ~isempty(x)
                plot(ax,(0:numel(x)-1)/audio.fs,x,'Color',[0 .35 .7]);
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
        end
        function renderSpectrum(obj)
            ax=obj.UI.Spectrum; cla(ax); segments=obj.Session.getSegments;
            if isempty(segments)
                x=obj.Session.Audio.signal;
                if numel(x)>=2
                    s=dtmfSpectrum(x); plot(ax,s.frequency,s.amplitude);
                    obj.UI.Frequencies.Text='无有效按键片段；显示当前音频中央帧频谱。';
                else
                    obj.UI.Frequencies.Text='等待音频；采样率 8192 Hz，FFT 2048 点。';
                end
            else
                [x,d,segment]=obj.Session.segmentAudio(obj.SelectedSegment);
                if numel(x)>=2
                    s=dtmfSpectrum(x); plot(ax,s.frequency,s.amplitude,'Color',[0 .35 .7]); hold(ax,'on');
                    if d.status=="accepted"
                        nominal=dtmfFrequencies(d.key);
                        for k=1:2
                            xline(ax,nominal(k),'--','Color',[.65 .3 0]);
                            height=interp1(s.frequency,s.amplitude,d.frequencies(k));
                            plot(ax,d.frequencies(k),height,'rv','MarkerFaceColor','r');
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
                xline(obj.UI.Wave,segment.startTime,'--r','Tag','SegmentBoundary');
                xline(obj.UI.Wave,segment.endTime,'--r','Tag','SegmentBoundary');
            end
            xlabel(ax,'频率 (Hz)'); ylabel(ax,'单边幅度'); xlim(ax,[0 2000]); gridOn(ax);
            title(ax,'2048 点 FFT · 8192 Hz · 栅格间隔 4 Hz');
        end
        function playSignal(obj,x)
            obj.stopPlayback;
            player=audioplayer(x,obj.Session.Audio.fs);
            obj.Player=player;
            player.StopFcn=@(~,~)obj.playbackFinished;
            try
                play(player); obj.UI.Playback.Text='播放：进行中';
            catch exception
                obj.stopPlayback;
                error('dtmf:Playback','无法播放音频，请检查输出设备：%s',exception.message);
            end
        end
        function playbackFinished(obj)
            if isvalid(obj) && isgraphics(obj.Figure)
                obj.UI.Playback.Text='播放：已结束';
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
                    uialert(obj.Figure,sprintf('操作未完成：\n%s',exception.message),'DTMF 操作提示','Icon','error');
                end
            end
        end
        function keepMinimumSize(obj)
            if ~isfield(obj.UI,'Root'), return; end
            p=obj.Figure.Position;
            % 小屏幕保留控件实际高度并允许滚动，不用缩小坐标轴挤压文字。
            if p(4)<800
                obj.UI.Root.RowHeight={260,260,230};
            else
                obj.UI.Root.RowHeight={'1x','1x',230};
            end
            if p(3)<1000
                obj.UI.Root.ColumnWidth={290,660};
            else
                obj.UI.Root.ColumnWidth={290,'1x'};
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
