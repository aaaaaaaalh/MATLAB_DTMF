function app = DTMF_App(options)
%DTMF_APP 启动 DTMF 实验系统；自动添加本工程路径。
% app = DTMF_App(Visible="off") 可用于界面自动检查，不播放声音。
arguments
    options.Visible (1,1) string {mustBeMember(options.Visible,["on","off"])} = "on"
end
root=fileparts(mfilename('fullpath'));
addpath(fullfile(root,'src'),fullfile(root,'gui'));
app=DtmfAppWindow(options.Visible);
if nargout==0, clear app; end % 窗口 UserData 保留应用对象直到关闭。
end
