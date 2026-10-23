# 第一阶段验收状态（2026-10-23 更新）

## 当前验收结论：通过

用户手动运行，Codex 已检查磁盘原始记录和图像：

- MATLAB 25.2.0.2998904 (R2025b)，Signal Processing Toolbox 25.2。
- 实测时间：UTC 2026-10-22 16:31:17，即北京时间 2026-10-23 00:31。
- test_results.csv、tests.log、junit.xml：执行 21，通过 21，失败 0，未完成 0。
- demo_result.csv：输入和识别均为 13800123456，Match=1。
- examples/13800123456.wav 真实存在，105728 字节。
- digit8_waveform.png 130665 字节，digit8_spectrum.png 74119 字节。已目视核查中文、坐标单位和 852/1336 Hz 标记，未见重叠或缺字。
- 测试和演示 MAT、逐项 CSV、JUnit、噪声汇总及全部逐次记录均存在。
- 噪声实验 120 次：30/20/10 dB 两种模式均 10/10；5 dB 默认 6/10、基准 7/10；0/-5 dB 均 0/10。低 SNR 失败原样保留，不宣称所有噪声实验成功。

第一阶段现已满足本地稳定版本提交条件。main 分支，不推送远端。

2026-10-23 实际提交尝试失败：当前会话对 `.git` 仅有读取权限，`git add` 和 `git commit` 均报 `Unable to create 'E:/MATLAB_DTMF/.git/index.lock': Permission denied`。因此稳定版本已通过测试，但首次 Git 提交未完成，无哈希。没有修改权限或全局 Git 配置。

---

以下为 **2026-10-22 的历史阻塞记录**，其未运行、未生成、未提交状态已由上述最新验收结果替代。

## 交付物

已创建 9 个 src 核心函数、21 项 MATLAB 单元测试、测试运行器、演示脚本、PowerShell 验证脚本和设计文档。完整文件树参见 README。所有操作限制在本工程内，没有开发 GUI、最终报告或执行远端操作。

已实现标准频率映射、精确点数/时间单键合成、两种序列模式、FFT 双频判决、短时能量自动分段、WAV 读写与重采样。实现完成不等于运行验收通过。

## 实际运行情况

发现的安装：MATLAB R2025b，`C:\Program Files\MATLAB\R2025b`。常规 `matlab -batch`、项目内偏好及临时目录、`-nojvm`、直接调用 `bin\win64\MATLAB.exe` 均未能进入 MATLAB 脚本。原始错误：

```text
Fatal Startup Error:
Dynamic exception type: class std::runtime_error
std::exception::what: System Error: File system inconsistency
```

启动器非零退出。根因尚未确认，不能据此断定为许可证或权限问题。运行 `version`、许可证探测和实际测试入口均未成功。未修改其他 MATLAB 项目或系统配置。

**编写测试项 21；实际执行 0；通过 0；测试断言失败 0；未执行 21。环境启动失败与测试断言失败分开统计。** 噪声实验计划 120 次，实际 0 次，无准确率可报告。

现存原始启动日志：`outputs/results/launcher.log`、`outputs/results/direct_startup.log`。这些只证明启动失败，不代表测试结果。

## 待运行产生的文件（目前不存在）

- `examples/13800123456.wav`
- `outputs/figures/digit8_waveform.png`
- `outputs/figures/digit8_spectrum.png`
- `outputs/results/tests.log`、`test_results.mat`、`test_results.csv`、`junit.xml`
- `outputs/results/noise_results.csv`、`noise_trials.csv`、`noise_results.mat`
- `outputs/results/demo_result.mat`、`demo_result.csv`、`digit8_spectrum.mat`

在本目录正常用户 PowerShell 中运行：

```powershell
matlab -batch "addpath('tests','examples'); run_tests; demo_dtmf;"
```

或在已能启动的 MATLAB 中运行：

```matlab
cd('E:\MATLAB_DTMF');
addpath('src','tests','examples');
run_tests;
demo_dtmf;
```

## Git 与未完成事项

本地仓库已初始化，分支 main，无提交哈希。用户要求测试通过后首次提交，因此此处没有跳过前置条件提交未验证版本。当前文件为未跟踪状态。当前执行账户与目录所有者不同，Git 查询采用仅本次命令生效的 `-c safe.directory=E:/MATLAB_DTMF`，不修改全局配置。

待完成：真实 MATLAB 回归、噪声准确率分析、WAV/图像生成与检查、必要算法修复、首次 Git 提交。自动分段的边界与已知限制见 `design.md`。

第二阶段建议：先完成当前验证，再开发原生 4×3 GUI；将号码编辑与标准音调映射分开，`*` 删除末位并同步音频，`#` 确认并保留号码音频。GUI 调用 src 模块，不内嵌 DSP 实现。
