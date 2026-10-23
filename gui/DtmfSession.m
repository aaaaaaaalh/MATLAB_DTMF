classdef DtmfSession < handle
    %DTMFSESSION GUI 会话状态，不包含控件或播放器，不重复实现 DSP。
    % 修改操作先计算再提交状态，失败时保留原音频。导入后输入数字开始新号码。
    properties (SetAccess=private)
        Digits = ""
        Mode = "default"
        ToneMs = 300
        GapMs = 100
        Audio
        Source = "dial"
        SourceName = "拨号合成"
        Recognition = []
        Confirmed = false
    end
    methods
        function obj=DtmfSession
            obj.Audio=dtmfSequence("");
        end
        function appendDigit(obj,key)
            key=string(key);
            if ~isscalar(key) || strlength(key)~=1 || ~contains("0123456789",key)
                error('dtmf:DialDigit','拨号输入只允许单个数字 0～9。');
            end
            digits=obj.Digits;
            if obj.Source=="wav", digits=""; end
            if strlength(digits)>=200, error('dtmf:DialLength','一次最多输入 200 位号码。'); end
            obj.setDigits(digits+key);
        end
        function backspace(obj)
            if obj.Source=="wav"
                error('dtmf:ImportedEdit','导入音频不能按号码删除；请清空或输入数字开始新拨号。');
            end
            chars=char(obj.Digits);
            if ~isempty(chars), chars(end)=[]; end
            obj.setDigits(string(chars));
        end
        function clear(obj)
            obj.setDigits("");
        end
        function configure(obj,mode,toneMs,gapMs)
            mode=string(mode);
            if ~isscalar(mode) || ~any(mode==["default","baseline"])
                error('dtmf:Mode','请选择默认时间模式或指导书基准模式。');
            end
            validateattributes(toneMs,{'numeric'},{'scalar','finite','>=',40,'<=',3000});
            validateattributes(gapMs,{'numeric'},{'scalar','finite','>=',0,'<=',2000});
            if obj.Source=="dial"
                audio=dtmfSequence(obj.Digits,Mode=mode,ToneDuration=toneMs/1000,GapDuration=gapMs/1000);
                obj.Audio=audio; obj.Recognition=[]; obj.Confirmed=false;
            end
            obj.Mode=mode; obj.ToneMs=toneMs; obj.GapMs=gapMs;
        end
        function recognize(obj,confirm)
            if nargin<2, confirm=false; end
            obj.requireAudio;
            result=dtmfRecognizeSequence(obj.Audio.signal,obj.Audio.fs);
            obj.Recognition=result;
            obj.Confirmed=logical(confirm);
        end
        function importWav(obj,filename)
            audio=dtmfReadWav(filename);
            if isempty(audio.signal), error('dtmf:EmptyAudio','WAV 文件没有可用音频。'); end
            result=dtmfRecognizeSequence(audio.signal,audio.fs);
            [~,name,ext]=fileparts(filename);
            obj.Audio=audio; obj.Source="wav"; obj.SourceName=string(name)+string(ext);
            obj.Digits=""; obj.Recognition=result; obj.Confirmed=false;
        end
        function exportWav(obj,filename)
            obj.requireAudio;
            dtmfWriteWav(filename,obj.Audio.signal,obj.Audio.fs);
        end
        function segments=getSegments(obj)
            if ~isempty(obj.Recognition)
                segments=obj.Recognition.segments;
            elseif obj.Source=="dial"
                segments=obj.Audio.segments;
            else
                segments=[];
            end
        end
        function [x,detail,segment]=segmentAudio(obj,index)
            segments=obj.getSegments;
            validateattributes(index,{'numeric'},{'scalar','integer','>=',1,'<=',numel(segments)});
            segment=segments(index);
            x=obj.Audio.signal(segment.startSample:segment.endSample);
            detail=dtmfRecognizeTone(x,obj.Audio.fs);
        end
        function requireAudio(obj)
            if isempty(obj.Audio.signal), error('dtmf:EmptyAudio','请先输入号码或导入 WAV 文件。'); end
        end
    end
    methods (Access=private)
        function setDigits(obj,digits)
            audio=dtmfSequence(digits,Mode=obj.Mode,ToneDuration=obj.ToneMs/1000,GapDuration=obj.GapMs/1000);
            obj.Audio=audio; obj.Digits=digits; obj.Source="dial"; obj.SourceName="拨号合成";
            obj.Recognition=[]; obj.Confirmed=false;
        end
    end
end
