# 更新记录

## v0.3.0 — 2026-10-23

Pixel DSP Lab — Colorful Pixel GUI Release

- 完成彩色复古像素 GUI：统一主题、标题/状态栏、拨号控制台、时域与 FFT 显示、识别/WAV 区和小窗口滚动。
- 保留全部原操作语义、DSP 算法、采样率、FFT 点数和测试断言。
- 用户本机 MATLAB R2025b 25.2.0.2998904（Signal Processing Toolbox R2025b）验证：核心 21/21、完整第二阶段 37/37，失败 0、未完成 0；37 项包含核心 21 项，不重复计数。用户已确认视觉效果满意。
- 发布提交：`7d3d39a506509b67b7b01e4b8aadbf88e6415420`。
- 发布页：https://github.com/aaaaaaaalh/MATLAB_DTMF/releases/tag/v0.3.0

## v0.3.0 之后的开发记录

- `038ed79` 已引入独立可复现的第三阶段 A～F 性能实验入口；该历史提交保留。
- 本轮第三阶段实验补充在 `feat/phase3-experiments` 分支开展，v0.3.0 标签保持不变。
- 新增 1000 Hz 单频音、600/1700 Hz 非标准双频音的 WAV 往返与拒绝检查；本轮 A～F 已实际运行，异常场景 10/10 符合预期。
- 数据、配置与错误案例保存在 `outputs/results/phase3/`，报告图保存在 `outputs/figures/phase3/`；不公开上传日志或批量生成文件。

## v0.2.0 — 2026-10-23

- GUI 美化前稳定基线，完成 DTMF 合成、识别、WAV 处理和单窗口 GUI。
- 提交：`4f9490c431e8dc9f2d8ad5f91ee993c9d56b9d89`。
