# 面向零经验 / vibe coding 用户的 README 与交互门槛优化
分支：docs/readme-vibe-coding · 创建：2026-11-24

## 目标 Goal
让没有软件开发经验的 vibe coding 用户能看懂仓库定位，并在首次立项（bootstrap）、交叉评审（评审）和阅读验收包时无需理解技术栈选型、Git 分支名或底层哈希日志。

## 范围 Scope
- 用克制的 GitHub 仓库风格重写根目录 `README.md`
- 调整 `SKILL.md` 的 `0 · Bootstrap`：面向 PM 只确认产品形态与核心约束，由 agent 默认选定主流易验证的技术栈（PM 主动指定时除外）
- 新增只读辅助脚本 `.agents/skills/sdm/scripts/review-target.sh` 并更新 `SKILL.md` / `verification.md`：输入 `评审` 免填分支名即可自动定位唯一未合并的工作分支；存在多个未合并分支时列出计划标题供 PM 选择
- 调整 `SKILL.md` 的「验收包」模板为分层结构：首屏只呈现产品语言（做了什么、怎么试、检查与验收结论、需留意事项），将路径、base/head SHA 与 `verify.sh` 原始证据折叠在底部备查
- 在 `tests/test_delivery.py` 补充 `review-target.sh` 在临时 Git 仓库中的集成测试

## 不做 Out of scope
- 不改动 `guard.sh`、`preflight.sh`、`verify.sh` 的门禁与差异扫描规则
- 不引入外部依赖或修改全局配置

## 验收标准 Acceptance
- [x] `README.md` 简洁克制，准确反映免技术栈选型的 `bootstrap` 与免填分支名的 `评审` 用法
- [x] `SKILL.md` 与 `verification.md` 完成 `bootstrap` 产品化提问、免分支名 `评审` 及分层「验收包」模板改造
- [x] 在临时 Git 仓库中测试 `review-target.sh`：唯一未合并分支自动识别（含合并旧分支后）、无未合并分支与多未合并分支安全报错并展示计划标题、显式传参正常解析
- [x] `verify.sh` 全部检查通过

## 验证 Verification
- 自动：`bash .agents/skills/sdm/scripts/verify.sh`（运行 `make test` 全量交付测试通过；差异扫描提示 `.agents/` 变更属本需求对 skill 本身的预期修改）
- 手动：阅读更新后的 `README.md`、`SKILL.md` 模板，并在本仓库实跑 `bash .agents/skills/sdm/scripts/review-target.sh` 无参解析当前工作分支

## 交接 Handoff
- 基线提交（base）：`ec87445982afa779e07366724c84e9348fa07351`（`main`）
- 候选提交（head）：见 `docs/readme-vibe-coding` 最新提交
- 证据：`verify.sh` 全量测试通过（含 `test_review_target_resolves_sole_unmerged_branch_and_rejects_ambiguity`）；无参运行 `review-target.sh` 输出当前分支、SHA、BASE 与计划标题
- 缺口：无
- 下一位负责人：PM 验收（或在第二终端直接输入 `评审`），确认后回复“合并”

## 变更记录 Changes
- 2026-11-24 PM 确认在精简 `README.md` 基础上，一并落地针对零开发经验用户的三项改进：`bootstrap` 改问产品形态、`评审` 免输分支名、验收包分层展示。
