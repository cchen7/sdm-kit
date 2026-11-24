---
name: sdm
description: Delivery-process guardrails (SDM control plane) for this repository. Use when starting any new work item (feature, fix, refactor, chore; 新需求, 开工), when resuming unfinished work, before claiming anything is done, when opening or merging a PR (验收, 合并), when the PM asks for status (进度), and when asked to review a branch or PR (评审). Governs scope, branch, verification and integration, not how to write code.
---

# SDM — delivery control plane

The user is the PM: they own *what* gets built and *whether it is accepted*. You own *how*: design, code, tests, debugging and tooling are your call, following this repo's own conventions. This skill governs only **What → Where → Boundary → Verify → Finish**.

Scripts (run from the repo root):
- `bash .agents/skills/sdm/scripts/preflight.sh` — where am I, and may I write code? (exit 0 = yes)
- `bash .agents/skills/sdm/scripts/verify.sh` — automated checks on the candidate (exit 0 = configured checks passed)
- `bash .agents/skills/sdm/scripts/setup.sh` — reinstall the git guard when preflight asks (e.g. fresh clone)

## Lifecycle: 1 work item = 1 branch = 1 PR = 1 chat

**Every session starts with preflight.** Resuming a work branch? Rebuild context from the repo, not chat memory: `plan.md`, `git log --oneline main..HEAD` (the last commit's `Next:` line), `git diff --stat main...HEAD`.

**0 · Bootstrap — new project, once.** For a new project without tests, the first work item is `chore/bootstrap`: agree the stack with the PM; create the skeleton with `test` / `lint` / `build` entry points verify can discover (references/verification.md); add the stack's setup steps to `.github/workflows/sdm-verify.yml`; fill in the Project section of AGENTS.md. For an existing project, read its documented checks first; connect them as described in [verification.md](references/verification.md).

**1 · PLAN — in chat, on main, no file changes.**
- When a UI or product choice affects acceptance, agree on the earliest runnable user action to show the PM with representative data before filling in the rest.
- One work item = one goal the PM can accept or reject as a whole. Split bundles (feature + unrelated fix + refactor) and do them one at a time.
- Send the **需求回执** (template below) and wait for "开工". Ask only questions whose answers change the result, each with options and your recommendation.
- Tiny and unambiguous (typo, copy text, a config value): a one-line 回执, then proceed.

**2 · ISOLATE — before any code.**
- `git switch main` (+ `git pull --ff-only` when there is a remote), then `git switch -c <type>/<id>` — type: feature | fix | chore | refactor | docs; id: short kebab-case, not yet used under `docs/work/`.
- Write `docs/work/<id>/plan.md` from the agreed 回执 (template below); commit it as the branch's first commit.
- preflight must pass before you write code.

**3 · IMPLEMENT — your way.**
- *Stay in scope.* A material change — a new or changed acceptance criterion, a new subsystem, a data-model or public-interface change, effort far beyond the plan — means: stop → tell the PM → update plan.md (变更记录) and commit, or split off a new work item. Unrelated bugs or ideas: don't fix them; save them for the 验收包's 顺带发现.
- *Commit checkpoints.* Commit each logical step (`<type>: <what>`). Stopping mid-way, add a body line `Next: <what remains>`. Never end a session with uncommitted work. If the chat grows long, commit with `Next:` and suggest the PM continue in a fresh chat.
- *Hand off the first reviewable change.* Share the item, base/head SHAs, scope, evidence, gaps and next owner in the draft PR (if publishing is authorized) or the shared local plan. Do not stack dependent items before the reviewer picks it up or the PM agrees to group them. Independent authorized work can continue.

**4 · VERIFY — evidence, not belief.**
- Commit everything, then run verify. It refuses on main or with uncommitted changes, runs the repo's own test/lint/build, and flags referee changes and oversized diffs.
- Not PASS = not done. Fix the cause and re-run; never weaken tests, checks, sdm scripts, hooks, CI or AGENTS.md to get green. Three failed attempts at the same problem → stop and bring the PM options.
- Record each criterion's actual result and how it was checked. A PM decision to defer a gap for one version is separate from its test result. See [acceptance evidence and independent review](references/verification.md#acceptance-evidence).

**5 · INTEGRATE — the PM accepts, then merge.** Use [git-lifecycle.md](references/git-lifecycle.md) to merge the reviewed commit and check what landed.
- Write the **验收包** (template below): the PR body in GitHub mode, your message to the PM in local mode.
- Tell the PM it is ready for review (second console: "评审 <branch>", using the shared handoff) and acceptance. Fix 必须改 findings, then re-verify.
- Merge only after the PM says "合并" (the PM may pre-authorize tiny changes). Delete the branch, return to main, and tell the PM: "本工作项已完成，请开新会话做下一个。"

## Decision rights

| Decide yourself | Decide, then list as 假设 in the 验收包 | Ask the PM first |
|---|---|---|
| implementation, structure, naming, tests, in-scope refactors, fixing your own bugs, mainstream open-source libraries | reversible product details the PM didn't specify: wording, defaults, layout, edge-case behaviour | ambiguous requirements with very different outcomes; anything out of scope; new external services, accounts or paid dependencies; data model, public interface or data migration; security, privacy, money; irreversible or destructive actions; the same failure three times |

Rule of thumb: 撤得回的自己定，撤不回的先问。

## Talking to the PM
- Chinese, product language, no unexplained jargon. Lead with what the PM needs to decide.
- Every question: options, your recommendation, the cost of each. Batch non-blocking questions and keep working on what isn't blocked.
- "进度？" → four lines: 阶段 / 已完成 / 下一步 / 需要你决定.
- A new idea mid-item → ask: "现在做（更新计划和验收标准），还是作为下一个工作项？"

## Review console (read-only)
When asked to review, follow references/verification.md § Review. Never edit code, commit, switch branches or stash: the dev console shares this working copy.

## Templates

**需求回执** (chat message)

> **需求回执：<标题>**
> - 目标：<一句话，用户视角>
> - 范围：<要做的>
> - 不做：<明确不做的>
> - 验收标准：1) … 2) … 3) …（你能亲自检查的结果）
> - 需要你决定：<如有：选项 + 我的建议>
> - 规模：小 / 中 / 大（大 → 建议拆成：…）
>
> 回复"开工"我就开始。

**docs/work/<id>/plan.md**

    # <标题>
    分支：<type>/<id> · 创建：YYYY-MM-DD
    ## 目标 Goal
    <一句话，用户视角>
    ## 范围 Scope
    - …
    ## 不做 Out of scope
    - …
    ## 首次演示（影响产品取舍时）
    <最早能实际体验的用户动作和代表性数据>
    ## 验收标准 Acceptance
    - [ ] <PM 能亲自检查的结果>
    ## 验证 Verification
    - 自动：verify.sh（test / lint / build）
    - 手动：<PM 如何亲自试每条验收标准>
    ## 变更记录 Changes
    - <日期> <范围变更及 PM 的决定>

**验收包** (PR body, or the local-mode message)

    ## <标题> — docs/work/<id>/plan.md
    **做了什么**：<2–4 句，产品语言>
    **怎么试**：1. … 2. …
    **验收标准**
    - <标准> — <通过 / 失败 / 受阻 / 未测>；<候选版本、测试 / 原生操作 / PM 反馈及观察结果>
    **本版接受的缺口**（如有）：<谁、哪个版本、剩余影响和何时补验>
    **实际运行的检查**：<粘贴 verify.sh 的 EVIDENCE 块>
    **风险与注意**：<包括 verify 的警告；没有就写"无">
    **我做的假设**：<可推翻的小决定>
    **顺带发现（未处理）**：<无关的问题或想法，由 PM 决定是否立项>
