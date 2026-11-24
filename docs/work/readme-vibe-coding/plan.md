# 精简并重写面向 vibe coding 用户的 README
分支：docs/readme-vibe-coding · 创建：2026-11-24

## 目标 Goal
用克制的 GitHub 仓库风格重写 `README.md`，直接说明 `sdm-kit` 作为轻量交付护栏 skill 在 vibe coding 场景下解决的问题、核心机制、安装与日常用法，去掉冗余流程说明。

## 范围 Scope
- 用已确认的精简版本替换根目录 `README.md`
- 同步对齐 `verify.sh` 当前支持的检查范围（Makefile、Shell、Node、Python、Rust、Go、Swift）、`--update` 升级命令与 GPL-3.0 许可证链接

## 不做 Out of scope
- 不修改 `.agents/skills/sdm/`、`template/`、`install.sh` 或测试逻辑
- 不新增额外文档文件

## 验收标准 Acceptance
- [x] `README.md` 采用克制的开源仓库描述风格，点明本质上是一个面向 coding agent 的轻量交付护栏 skill，无推销口号与冗长配置教程
- [x] 准确包含解决的问题、工作原理、安装/升级命令、日常指令与许可证链接
- [x] `verify.sh` 全部检查通过

## 验证 Verification
- 自动：`bash .agents/skills/sdm/scripts/verify.sh`（`make test` 通过，差异扫描通过，无警告）
- 手动：打开根目录 `README.md` 通读结构、篇幅与命令准确性（全文精简为 58 行）

## 交接 Handoff
- 基线提交（base）：`ec87445982afa779e07366724c84e9348fa07351`（`main`）
- 候选提交（head）：见当前分支最新提交（`git rev-parse docs/readme-vibe-coding`）
- 证据：`verify.sh` 运行 `make test` 通过，diff 扫描无裁判规则改动或抑制警告；人工核对 `README.md` 命令与当前脚本一致
- 缺口：无
- 下一位负责人：PM 验收（或第二终端运行 `评审 docs/readme-vibe-coding`），确认后回复“合并”
