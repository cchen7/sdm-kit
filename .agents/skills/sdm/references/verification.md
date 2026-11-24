# Verification and review (SDM)

Read before the first verify in a project, when verify fails or finds nothing, and when reviewing.

## What verify.sh does
1. Gate (skipped in CI): preflight passes and the working tree is clean, so the evidence belongs to a commit.
2. Discover the repo's own checks:
   - A root `Makefile` defining any of `test:` `lint:` `build:` → only those targets. Use this for multi-stack repos or unusual commands.
   - Otherwise every detected stack contributes:
     - Shell: use the first of `tests/run.sh`, `test/run.sh`, `scripts/test.sh`, `test.sh`. Without a suite runner, run `test_*.sh` / `*_test.sh` and Bats suites (`*.bats`) directly under `tests/` and `test/`. Shell entry scripts must be executable; the shebang selects the interpreter. Bats must be on PATH for a Bats suite. Source or syntax checks alone are not tests.
     - `package.json` scripts `test`, `lint`, `typecheck`, `build`, run with npm / pnpm / yarn / bun (chosen by lockfile)
     - Python: use `python -m pytest -q` for a pytest configuration, conftest or declared pytest dependency. Otherwise discover unittest cases from the first conventional test root (`tests/`, `test/`, then the project root) containing `test*.py`; a `tests/` or `test/` package can also contain nested test modules. Empty unittest collection fails. Use a Makefile for other layouts or multiple independent roots. Configured Ruff runs as lint. The runner prefers a uv lock, Poetry lock, local `.venv`, then `python3`.
     - Rust: a root `Cargo.toml` runs `cargo test`, available Clippy, and `cargo build`; Cargo's default workspace member selection is preserved. Use a Makefile for custom features, targets or all members when the workspace specifies a subset.
     - Go: a root `go.mod` runs `go test ./...`, `go vet ./...` and `go build ./...`. With a root `go.work` and workspace mode enabled, run each check over the workspace's in-repository modules, including layouts without a root module. A workspace referencing another checkout requires an explicit scope; use a Makefile.
     - Swift manifests at `Package.swift` or `Packages/*/Package.swift`: `swift test --package-path <dir>` for each. Native app builds, UI runs, signing and project-specific guardrails require the project's own entry points and host.
   - No test command → FAIL. A detected test runner that is unavailable or exits unsuccessfully also fails verification. Missing optional lint/build is reported, not fatal.
3. Run each check with `CI=true` and no stdin (no watch modes); print the tail of any failure; full logs go to a temp folder.
4. When a comparison base is available, scan its merge base with HEAD: referee changes (AGENTS.md, sdm files, CI, Makefile, check scripts and configs), deleted tests, added skip/only markers and lint suppressions, size (> 30 files or > 1000 changed lines, lockfiles excluded).
5. Print the EVIDENCE block, including whether the diff scan ran. Exit 0 only if every configured check passed. Locally the base defaults to main/master. In CI or a detached review use `SDM_BASE_SHA=<full base commit>` with both histories available; an explicit invalid or unreachable base fails. Without a base, CI reports the scan was skipped. Record a separate comparison before concluding checks were not weakened.

Fresh means: run in this session, on the current HEAD. Any commit after verify → run it again.

## When verify fails or finds nothing
- Read the failing log and fix the cause, not the check.
- Dependencies missing locally: install them the project's normal way, then re-run.
- No discovered test entry: inspect the project's instructions and CI. Reuse existing commands via a thin root Makefile (e.g. `test:` invokes the documented package and tool suites). List checks needing a desktop or special host separately. Bootstrap a runner only if the project actually has no tests.
- Tests must run from a fresh clone: put dependency installation in the CI workflow (or a `make setup` target, which the workflow calls), and keep build outputs in `.gitignore`.

## Warnings need PM attention
verify can PASS with warnings. Each goes into the 验收包 under 风险与注意 with a one-line reason. Some are expected (bootstrap touches CI, Makefile and configs). Unexplained weakening — deleted or skipped tests, loosened lint, edited sdm scripts, hooks or AGENTS.md — is a 必须改 in review.

## Acceptance evidence
For each criterion in plan.md, record the candidate or artifact, evidence source (test, native interaction, PM observation or independent reference), actual result and any gap. A 12-minute sample of a required 30-minute observation is incomplete even if the PM accepts the risk for this release. Preserve that result and record who accepted it, for which version, and when to revisit. A source build alone does not verify the published artifact.

For unattended desktop QA, verify the test process and isolated data location before interacting. If a tool might start the ordinary app or the target cannot be confirmed, leave that case blocked. Separate fixture-based checks from actual input; a PM grant does not change host permissions.

## Review
Goal: an independent check of one pinned commit against plan.md — not a rewrite, not style preferences.
1. Pin: run `bash .agents/skills/sdm/scripts/review-target.sh [branch]` to resolve `BRANCH`, `SHA`, `BASE` and `PLAN`. When the PM says only "评审", it automatically selects the sole unmerged work branch; if multiple unmerged branches exist, ask the PM which item to review using their plan titles rather than raw Git branch names.
2. Read through git objects only: `git diff $BASE $SHA`, `git show $SHA:<path>`, `git log $BASE..$SHA`. Never checkout, switch, stash, reset, commit or edit: the dev console shares this working copy.
3. Check, in order:
   - Scope: every change traces to plan.md; flag unrelated changes.
   - For persistence, permissions, privacy or accounting, derive a counterexample from the user promise before reading the developer's tests. Write the input and expected result, then try it on the pinned candidate: for example, a replayed cumulative total must not add the same calls again, including after an upgrade. Have the developer keep regressions as tests and independently verify the fix.
   - Acceptance: each criterion has convincing evidence; proposed demo steps alone are not a pass.
   - Referee: changes to tests, checks, CI, hooks, sdm files or AGENTS.md are justified; nothing is weakened.
   - Risks: likely bugs, security or privacy issues, data loss, unhandled errors on user paths.
   - Honesty: the 验收包 matches the diff and the evidence.
4. Optional, recommended in local mode — run the checks yourself on the pinned commit in a throwaway worktree: `git worktree add --detach <tmp> $SHA`, install dependencies there, `CI=true SDM_BASE_SHA="$BASE" bash .agents/skills/sdm/scripts/verify.sh`, then `git worktree remove --force <tmp>`.
5. Report in Chinese, product language first: verdict 可以验收 / 需修改; findings graded 必须改 / 建议改 / 可忽略, each with a plain-language explanation (plus `file:line` for the developer); put the pinned `BRANCH` and `SHA` on a reference line at the bottom.
6. Record head, base, verdict, open findings and who acts next in the shared handoff. If separately authorized to fix a critical finding yourself, hand that fix to another reviewer.
7. Deliver: GitHub mode → `gh pr comment <PR> --body-file <file>`. Local mode → append a section `## Review @<SHA>` to `docs/work/<id>/review.md` — the only file you may write.
