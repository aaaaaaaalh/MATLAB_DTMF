# 第二阶段交付记录（2026-10-23）

## 稳定版本验收（2026-10-23）

用户已在 MATLAB R2025b 中确认 GUI 正常打开，号码输入、删除、确认、WAV 导入导出及 DTMF 自动识别正常，`run_phase2_checks` 全部通过。归档前核查本地 test_results.csv：37 项 Passed=1、Failed=0、Incomplete=0。Codex 本次未启动 MATLAB，不将用户运行记录记为 Codex 运行。可选 RunAudio=true 检查未在本次声明通过。

本版本作为 GUI 美化前的 v0.2.0 稳定基线；运行日志及生成结果仅本地保留，不随公开仓库发布。下文为开发过程历史记录，其中待验收、未提交状态不代表当前验收结论。

## 历史：首次用户实测与初始化修复

用户于 UTC 2026-10-22 17:03:40 运行 37 项检查：通过 30，失败 7，未完成 7（失败与未完成是同一组 GUI 测试，不能相加为 14）。核心 21 项和会话 9 项均通过。7 项 GUI 测试在模式下拉框初始化时失败，尚未进入测试正文；同时出现缩放回调警告和 teardown 二次报错。

原始日志、CSV、MAT 和 JUnit 已归档到 `outputs/results/phase2/history/20261023_010340/`。

修复内容：模式下拉框改用数值 ItemsData=[1 2]，在会话边界映射为 default/baseline；两个下拉框分步初始化。窗口先设 AutoResizeChildren=off 再安装 SizeChangedFcn。测试 teardown 先检查 app 字段是否存在。既有模式测试增加初始化断言，并通过实际 ValueChangedFcn 验证往返切换。总数仍为 37 项。

修复后 mlint 无诊断；Codex 重跑 MATLAB 仍在启动阶段失败（见 dropdown_fix_launcher.log），修复版本尚待用户实测。以下开发交付时的“未执行”描述为历史记录，以本节用户实测为准。

## 实现范围

- DTMF_App.m：自动添加本工程路径的启动入口。
- gui/DtmfSession.m：号码、参数、来源、确认和识别状态；所有 DSP 调用第一阶段 src 函数。
- gui/DtmfAppWindow.m：4×3 原生键盘、时域/FFT 两图、片段选择、明细表、WAV 操作和唯一播放器生命周期。
- tests/testDtmfSession.m：9 项状态测试。
- tests/testDtmfGui.m：7 项真实原生控件测试（默认隐藏窗口、不发声）。
- tests/testDtmfAudio.m：2 项可选真实声卡测试。
- tests/run_phase2_checks.m：组合原有 21 项回归，保存第二阶段独立日志/CSV/MAT/JUnit。

src 核心算法、原有 testDtmf.m 与 run_tests.m 未修改。没有开发最终实验报告，没有访问 GitHub 或推送。

## 实际验证证据

1. 第一阶段用户实测记录已核查：MATLAB R2025b，21/21 通过；13800123456 合成、WAV 往返、识别一致；两张图像真实存在且已目视检查。
2. 第二阶段实际尝试 MATLAB batch，启动器仍在执行 `.m` 之前报 `System Error: File system inconsistency`，退出码 1。见 outputs/results/phase2/launcher.log。
3. 已实际运行安装目录下 `bin/win64/mlint.exe -id` 检查新增 7 个 `.m` 文件，退出码 0，无诊断；原始输出见 outputs/results/phase2/static_mlint.log。该结果只说明静态分析，不说明控件渲染或运行行为已通过。
4. 人工代码检查覆盖：* / # 不追加音调、参数与导入音频分离、先计算后修改状态、播放器回调解绑/停止/删除、错误对话框、固定 FFT 与有效样点区分、小窗口滚动。

**第二阶段实际执行测试 0，新增测试通过 0；计划标准 37 项（含原回归 21），可选完整 39 项。未成功运行 GUI，无真实 GUI 截图，无听音验收。** 第一阶段历史 21/21 通过不等于本次回归已重跑。

## Git 状态

main 仓库存在，但当前会话 `.git` 只读。实际执行 `git add .` 和指定提交命令失败，均无法创建 index.lock。没有提交哈希，文件仍未跟踪。未绕过权限，也未擅自写其他仓库。第一阶段稳定提交与第二阶段提交都尚未完成。

## 运行与剩余验收

```matlab
cd('E:\MATLAB_DTMF');
DTMF_App;
```

```matlab
addpath('tests');
run_phase2_checks;
% 声卡检查会发声，可按需要执行：
run_phase2_checks(RunAudio=true);
```

用户需检查实际布局、中文字体、声音、文件对话框以及播放中关闭资源释放，完整步骤见 gui_guide.md。当前识别算法低 SNR 限制仍按第一阶段真实记录保留；无静音的重复音调不可自动恢复边界。
