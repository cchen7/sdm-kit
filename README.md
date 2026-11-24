# sdm-kit

给使用 coding agent（Codex、Claude Code、GitHub Copilot CLI）开发项目的人准备的一套轻量交付护栏 skill。

适合 **vibe coding** 场景：你负责用自然语言提需求、做取舍、按步骤验收产品结果；代码怎么写完全由 agent 决定。`sdm-kit` 不干预模型的编码方式，只用 Git 分支、仓库内计划文档和几个本地脚本管住交付边界。

## 解决什么问题

用 coding agent 从零做原型很快，但项目迭代几天后通常会遇到几类固定问题：

- **主分支失控**：所有改动直接堆在 `main` 上，改坏已有功能时很难干净回退。
- **长会话退化**：一个聊天窗口跑太久，上下文混杂历史讨论，agent 容易忘掉最初约束或顺手改动无关代码。
- **口头“已完成”**：agent 宣布改好了但没跑完整检查，甚至为了通过检查删测试、加 `skip` 或屏蔽 lint 报错。
- **切换工具断档**：关掉终端下次继续，或者想换另一个 CLI 交叉检查时，背景全留在上一段聊天记录里。

## 它是怎么工作的

核心约束只有一条：**一个工作项 = 一个分支 = 一个 PR = 一个 agent 会话**。项目状态保存在 Git 里，而不是聊天记录里。

```text
需求回执 ─"开工"→ 建分支写计划 → agent 自主实现 → 自动验证 → 评审与验收 ─"合并"→ 合并清理、开新会话
```

1. **先对齐再写代码**：在 `main` 上只聊需求、不改文件。agent 先给出一份简短的「需求回执」（目标、范围、不做、验收标准），你回复“开工”后才切分支动手。撤得回的细节由 agent 自己定；涉及范围变更、外部依赖、数据结构或不可逆操作必须先问你。
2. **用 Git 代替长对话记忆**：每个需求对应 `docs/work/<id>/plan.md` 和阶段性提交（未完成时记录 `Next:`）。做完合并即可关掉当前会话，新会话从仓库记录直接恢复上下文。
3. **锁住主分支**：本地 `pre-commit` / `pre-push` hooks 默认阻止直接在 `main` 上提交或推送；配合自带的 GitHub Actions 工作流和分支保护规则，可以在远端做硬约束。
4. **基于证据交差（防绕过检查）**：合并前运行 `verify.sh`，自动识别并执行项目已有的 `test` / `lint` / `build`（支持 Makefile、Shell、Node、Python、Rust、Go、Swift），同时扫描当前分支 diff——如果出现删除测试、新增 `skip`/`only`、新增 lint 屏蔽注释、修改规则脚本或单次改动过大，都会在验证证据中显式标出。
5. **双终端只读交叉评审**：支持在同一项目目录下开第二个终端做只读评审（例如用 Claude Code 开发，用 Codex 评审）。评审端只通过 Git 对象读取固定 commit SHA 并对照 `plan.md` 检查，不切分支、不改工作区。

> Design principle: Build a delivery control plane around the coding agent, not another coding methodology inside it. Persist state in Git, align agent-context lifetime with branch/PR lifetime, enforce deterministic boundaries with tools, and otherwise stay out of the model's way.

## 支持的工具与安装

一次安装同时配置 **Codex CLI**、**Claude Code** 和 **GitHub Copilot CLI**，所有文件均在目标项目内，不修改全局配置：

```bash
git clone https://github.com/cchen7/sdm-kit.git ~/sdm-kit
bash ~/sdm-kit/install.sh ~/code/my-app
```

已有项目的 `AGENTS.md`、`CLAUDE.md` 和自定义 CI 不会被覆盖，安装器只会补入 SDM 规则段落和技能入口（`.agents/skills/sdm` 与 `.claude/skills/sdm`）。后续升级技能可在目标项目根目录执行 `bash ~/sdm-kit/install.sh . --update`。

## 日常使用

安装后在项目目录打开任一 CLI，日常只需要几句固定指令：

- `按 SDM 流程，先做 bootstrap：<一句话描述产品>` —— 新项目首个工作项：确认产品形态（如网页、本地工具、是否存数据），由 agent 选定稳妥的主流技术栈并搭好骨架与测试入口
- `按 SDM 流程：<需求描述>` —— 生成「需求回执」，对齐范围和验收方式
- `开工` —— 创建工作分支、提交 `plan.md` 并开始实现
- `进度？` —— 返回 4 行状态（当前阶段 / 已完成 / 下一步 / 待你决定）
- `评审` ——（在第二个终端）自动定位当前未合并的工作分支，对候选提交做只读检查
- `合并` —— 你按「验收包」试跑确认后，合并回 `main`、清理分支并结束当前会话
- `继续上次的工作` —— 在新会话中从 `plan.md` 和提交记录恢复进度

## 许可证

[GNU General Public License v3.0](LICENSE)。
