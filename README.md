# SDM Kit v1 · 让 coding agent 按软件开发流程工作

**分工**：你（PM）决定做什么、验收是否通过；agent 决定怎么写代码；SDM 只管 **做什么 → 在哪做 → 边界 → 怎么算完成 → 怎么收尾**，不干涉 agent 的编码方式。

```
需求回执 ─"开工"→ 建分支+计划 → agent 自由实现 → 自动验证 → 评审 + 你验收 ─"合并"→ 合并、清理、开新会话
  PLAN             ISOLATE        IMPLEMENT         VERIFY      INTEGRATE
```

一个工作项 = 一个分支 = 一个 PR = 一个 agent 会话。项目状态存在 git 里，而不是聊天记录里。

> 设计北极星：Build an SDM control plane around the coding agent, not another coding methodology inside it. Persist state in Git, align agent-context lifetime with branch/PR lifetime, enforce deterministic boundaries with tools, and otherwise stay out of the model's way.

## 包里有什么

| 文件 | 作用 |
|---|---|
| `install.sh` | 把 SDM 装进目标项目（可重复运行） |
| `.agents/skills/sdm/SKILL.md` | 三款工具共用的技能：5 个阶段、决策权、回执 / 计划 / 验收包模板 |
| `.agents/skills/sdm/references/` | 分支与合并、验证与评审细节（进入对应阶段才读） |
| `.claude/skills/sdm` | Claude Code 的项目内链接，指向同一份技能 |
| `template/AGENTS.md`、`template/CLAUDE.md` | 目标项目的 8 条常驻规则，以及 Claude Code 的规则入口 |
| `…/sdm/scripts/preflight.sh` | 回答"现在能不能写代码" |
| `…/sdm/scripts/verify.sh` | 自动找到并运行项目的测试 / 检查，输出证据；不通过 = 没完成 |
| `…/sdm/scripts/setup.sh`、`…/sdm/hooks/guard.sh` | 本地护栏：禁止直接提交 / 推送 main |
| `template/.github/workflows/sdm-verify.yml` | GitHub 上自动重跑同样的检查 |

以 `.` 开头的文件夹（`.agents`、`.github`）在 Finder 里默认隐藏，按 Cmd + Shift + . 可以显示。

## 1 · 每台电脑准备一次

- 设置 git 身份：
  ```
  git config --global user.name  "你的名字"
  git config --global user.email "你的邮箱"
  ```
- 想用 GitHub 模式：安装 GitHub CLI（macOS：`brew install gh`；WSL：按 cli.github.com 上的 Linux 安装说明），然后运行 `gh auth login`。

## 2 · 每个新项目安装一次

先把 kit 放在目标项目之外。可以解压，也可以克隆：

```bash
git clone https://github.com/cchen7/sdm-kit.git ~/sdm-kit
bash ~/sdm-kit/install.sh ~/code/my-app
```

三款 CLI 在目标项目内读取同一份技能；安装不需要改用户级配置。安装器会复制技能、规则和 CI 模板，并安装本仓库的 Git hooks。只有安装器在空目录新建 Git 仓库时，它才会为已安装的文件创建首次提交；其他情况下由你审阅后自行提交。已有 `AGENTS.md` 和 `CLAUDE.md` 的内容会保留，安装器只补入 SDM 区块和 `@AGENTS.md` 引用。

如果只是要在 kit 仓库中查看技能，克隆后从仓库根目录打开任一 CLI 即可。Kit 仓库已包含技能入口；完整的 SDM 流程和 CI 模板由安装器配置到目标项目。

## 3 · 日常：你只需要会说这几句话

| 你说 | agent 会做 |
|---|---|
| 按 SDM 流程，先做 bootstrap：<一句话描述产品> | 新项目的第一个工作项：和你确定技术栈，搭好骨架、测试和检查 |
| 按 SDM 流程：<需求> | 回你一份「需求回执」：目标 / 范围 / 不做 / 验收标准 / 需要你决定的事 |
| 开工 | 建分支、写计划、开始实现 |
| 进度？ | 4 行汇报：阶段 / 已完成 / 下一步 / 需要你决定 |
| （中途有新想法，直接说） | 它会问：现在做（更新计划），还是作为下一个工作项 |
| 评审 <分支名>（在第二个终端） | 只读评审：结论 + 必须改 / 建议改 / 可忽略 |
| 合并 | 合并、删分支，并提醒你开新会话 |
| 继续上次的工作 | 从计划和提交记录里恢复上下文 |

**验收时看「验收包」**：做了什么、怎么试、每条标准的结果（通过 / 失败 / 受阻 / 未测）、版本与证据；本版经你接受的缺口另列、实际跑过的检查、风险、它替你做的假设、顺带发现的问题。按"怎么试"亲手试一遍，再说"合并"。

**agent 必须先问你的情况**：需求有歧义且结果差别大、超出范围、新增外部服务或付费依赖、改数据结构或对外接口、涉及安全 / 隐私 / 钱、不可撤销的操作、同一个问题失败 3 次。其余它自己决定——撤得回的自己定，撤不回的先问。

## 4 · 两个终端

- **开发终端**：一个工作项一个会话；合并后关掉，下一个需求开新会话（上下文干净，agent 更可靠）。
- **评审终端**：只读。建议用和开发**不同的工具或模型**（例如 Claude Code 开发、Codex 评审），交叉检查更有效。
- 第一项能演示或复验时就交审。在获准推送的草稿 PR 或本地计划写清：改动范围、基线和候选提交、证据、缺口、下一位负责人。两个终端直接读同一处，你不用转贴意见。涉及权限、计量或升级时，评审方先从用户预期设计一个反例，修复后在新提交上复验。
- 两个终端共用一个文件夹，所以评审方只读 git 记录，不切分支、不改代码。本地模式下意见写进 `docs/work/<id>/review.md`；GitHub 模式下写在 PR 评论里。

## 5 · 本地模式与 GitHub 模式

**本地模式**（默认，无需账号）：你说"合并"后 agent 在本地合并。本地护栏能防手滑，但防不住刻意绕过（例如 `--no-verify`）。

**GitHub 模式**（推荐，护栏更硬）：
1. 在项目目录创建远程仓库并推送：`gh repo create <名字> --private --source . --push`
2. 等 CI 跑完第一次（第一次失败是正常的：还没有测试；bootstrap 完成后会变绿）。
3. 打开仓库 → Settings → Branches → Add classic branch protection rule，Branch name pattern 填 `main`，勾选：
   - **Require a pull request before merging**（不要勾 Require approvals：你不能批准自己的 PR）
   - **Require status checks to pass before merging** → 搜索并选择 `sdm-verify`（CI 跑过一次后才会出现在列表里）
   - **Do not allow bypassing the above settings**（一定要勾：agent 用的是你的账号，你是管理员，不勾它就能绕过）
4. 可用性：分支保护在**公开仓库**上免费可用；**私有仓库**需要 GitHub Pro / Team / Enterprise。没有也能用 GitHub 模式，只是少了服务器端这道锁。
5. 进阶（可选）：给 agent 一个单独的 GitHub 账号，再开启 Require approvals —— 这样不经你批准，任何改动都进不了 main。

## 6 · 三种工具的注意事项

| 本地 CLI | 技能入口 | 怎么确认 |
|---|---|---|
| [Codex](https://developers.openai.com/codex/skills) | `.agents/skills/sdm` | 在新会话用 `/skills` 查看，或输入 `$sdm` |
| [Claude Code](https://code.claude.com/docs/en/skills) | `.claude/skills/sdm`（相对符号链接） | 在新会话输入 `/sdm`；`CLAUDE.md` 引用项目的 `AGENTS.md` |
| [GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills) | `.agents/skills/sdm` | 在项目目录运行 `copilot skill list`，或在会话中用 `/skills` |

Codex 默认沙箱可能会要求批准 Git 写入。Claude Code 的链接需要文件系统支持符号链接；在 Windows 上可使用 WSL。已打开的会话建议重新打开后再确认技能。

## 7 · 怎么判断它有没有用

跑 2–3 个项目后回看，下面这些情况应该变少：直接改 main、超大分支、一个会话跑很久、PR 里混入无关改动、忘了跑测试、换个 agent 要从头解释。
同时 agent 的编码能力**不应该变差**。如果流程明显拖慢了开发，就删减规则——这是 v1，越薄越好。

## 8 · 升级

kit 改进后，在项目目录运行 `bash ~/sdm-kit/install.sh . --update`：会刷新 `.agents/skills/sdm/` 和 `AGENTS.md` 中的 SDM 段落，并补齐缺失的兼容入口。已有的 CI 文件和项目规则中的其他段落会保留；旧 CI 若要运行差异扫描，请对照新版工作流模板传入 `SDM_BASE_SHA` 并检出完整历史；审阅后以工作项 `chore/sdm-update` 提交。

## 9 · v1 已知限制

- 本地护栏可被 `--no-verify` 绕过；真正的硬约束是 GitHub 分支保护。
- v1 只用分支，不强制 worktree：Codex 在 Linux / WSL 的 worktree 里提交会失败。
- 自动发现支持 Shell（项目测试脚本、Bats）、Python（pytest、标准库 unittest、已配置的 Ruff）、Rust（Cargo）、Go（`go.mod`、`go.work`）、Node 和 Swift 包。根 Makefile 的检查优先。支持的文件名、工作区范围和工具缺失时的行为见[验证说明](.agents/skills/sdm/references/verification.md)。原生 UI、签名和专用主机检查单列。
- 主分支必须叫 `main`（或 `master`）。
- 安装器不会覆盖其他工具的 hooks，也不会写入自定义 `core.hooksPath`。如果项目使用了这类 hooks，需先安排如何接入 SDM 护栏。

## 附录 · Codex 预先放行常规 git 操作（可选）

在 `~/.codex/rules/default.rules` 中加入下面内容，然后重启 Codex。推送、合并、删除等操作仍会逐次询问你。

```
prefix_rule(
    pattern = ["git", ["add", "commit"]],
    decision = "allow",
    justification = "SDM: routine checkpoint commits",
)
prefix_rule(
    pattern = ["git", "switch", "-c"],
    decision = "allow",
    justification = "SDM: create a work-item branch",
)
```

## 许可证

[GNU General Public License v3.0](LICENSE)。
