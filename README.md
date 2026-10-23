# Pixel DSP Lab — MATLAB DTMF 电话拨号音实验

纯 `.m` 文件实现的 DTMF 实验系统：独立 DSP 核心、原生 MATLAB GUI、WAV 往返演示与自动测试。目标环境 MATLAB R2025b，重采样需要 Signal Processing Toolbox。不包含最终实验报告。

**第一阶段验证通过。** 用户在 MATLAB R2025b 中实际运行，21 项测试全部通过，演示号码 `13800123456` 识别一致，WAV 和两张图像已生成并核查。详见 `docs/phase1_acceptance.md`。Codex 启动器历史错误单独保留。

## 运行

直接启动图形界面，无需手动添加路径：

```matlab
cd('E:\MATLAB_DTMF');
DTMF_App;
```

**第二阶段验收通过（2026-10-23）。** 用户在 MATLAB R2025b 中确认 GUI 启动、号码输入、删除、确认、WAV 导入导出及自动识别正常，`run_phase2_checks` 全部通过；本地结果 CSV 为 37/37 通过。此结果来自用户实际运行，Codex 本次未启动 MATLAB。操作见 `docs/gui_guide.md`，记录见 `docs/phase2_acceptance.md`。

GUI 默认按键试听开启；数字键追加号码，`*` 删除末位及音频，`#` 确认并 FFT 识别。左侧可切换指导书模式。右侧下拉框或识别明细表可选择按键片段，波形用红色虚线显示选定区间，频谱标出双频峰。

导入 WAV 后自动转为 8192 Hz 单声道并识别。此时按数字键开始新的拨号号码；参数调整只影响下一次拨号，不改写导入文件音频。

第二阶段回归检查（默认不发声）：

```matlab
addpath('tests');
run_phase2_checks; % 原有 21 项 + 新增 16 项 = 37 项
% 如需额外检查真实声卡，会播放声音：
run_phase2_checks(RunAudio=true); % 39 项；无设备时硬件项标记未完成
```

在本目录 PowerShell 中：

```powershell
matlab -batch "addpath('tests','examples'); run_tests; demo_dtmf;"
# 或使用自动保存启动日志的脚本
powershell -ExecutionPolicy Bypass -File .\tools_run_validation.ps1
```

在 MATLAB 命令窗口中先将当前目录切换为本工程，再执行：

```matlab
addpath('src','tests','examples');
results = run_tests;
demo_dtmf;
```

快速调用：

```matlab
addpath('src');
a = dtmfSequence("13800123456"); % 300 ms 发声 / 100 ms 间隔
b = dtmfSequence("11120033",Mode="baseline"); % 精确 1000 / 100 点
c = dtmfSequence("123",ToneDuration=0.12,GapDuration=0.03);
r = dtmfRecognizeSequence(b.signal,b.fs);
disp(r.keys);
dtmfWriteWav("examples/custom.wav",a.signal,a.fs);
audio = dtmfReadWav("examples/custom.wav");
```

基准模式以采样点数为准，此模式下持续时间选项不覆盖 1000/100 点。默认时间按 `round(持续秒数*8192)` 换算，即 2458/819 点。序列只在相邻按键之间插入静音，无尾部附加间隔。

## 结构

```text
DTMF_App.m    自动配置路径的 GUI 启动入口
src/          9 个独立 DSP 与音频处理函数
gui/          DtmfSession 状态类、DtmfAppWindow 窗口与播放器
tests/        原有回归、会话/界面/可选声卡测试与运行器
examples/     demo_dtmf.m；执行演示后生成 WAV
outputs/
  figures/    演示生成数字 8 的时域图及频谱图
  results/    第一阶段真实结果；phase2/ 存放第二阶段验证记录
report/       后续实验报告占位
docs/         算法设计及第一阶段验收状态
PROJECT_CONTEXT.md
tools_run_validation.ps1
```

## 接口约定

所有音频为有限数值的 double 列向量；识别采样率固定 8192 Hz。元数据采样区间为 MATLAB 从 1 开始的闭区间，时间区间为从 0 开始的半开区间。单键识别失败返回 `?`、状态与原因；纯静音的连续识别返回空号码。参数错误抛出可捕获异常，不退出 MATLAB 会话。

底层音调映射及合成支持全部 `0~9*#`。GUI 默认拨号编辑器只追加数字：`*` 删除最后一位及其音频，`#` 确认而不追加音调。GUI 状态与标准 DTMF 映射分开实现。

稳定版本标签：`v0.2.0` 为 GUI 视觉改版前基线，`v0.3.0` 为已验收的 Pixel DSP Lab 彩色像素 GUI 版本。源代码、测试、文档及测试依赖的演示 WAV 纳入版本管理；本地运行日志、缓存及 outputs 生成结果不上传。

## 第三阶段综合实验

在工程根目录执行：

```matlab
results = run_phase3_experiments;
```

独立运行 12 键频率、连续号码、拨号时间、AWGN 抗噪、输入采样率与异常输入六组实验。固定随机种子，保留逐次实际错误，生成七张 300 dpi 中文图表；不改动 DSP 核心或原有测试。

数据与配置保存至 `outputs/results/phase3/<UTC运行编号>/`，图片保存至 `outputs/figures/phase3/<UTC运行编号>/`。`outputs/results/phase3/latest.json` 指向最新完成运行。复现方法、指标定义和本阶段真实结果见 [第三阶段验收记录](docs/phase3_experiments.md)。

公开前人工检查个人信息。含姓名、学号的原始实验报告只放在忽略的 `report/private/`，不加入仓库。忽略规则不能替代公开前审查。
