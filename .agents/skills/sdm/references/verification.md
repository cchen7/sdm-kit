# Verification and review (SDM)

Read before the first verify in a project, when verify fails or finds nothing, and when reviewing.

## What verify.sh does
1. Gate (skipped in CI): preflight passes and the working tree is clean, so the evidence belongs to a commit.
2. Discover the repo's own checks:
   - A root `Makefile` defining any of `test:` `lint:` `build:` → only those targets. Use this for multi-stack repos or unusual commands.
   - Otherwise every detected stack contributes:
     - `package.json` scripts `test`, `lint`, `typecheck`, `build`, run with npm / pnpm / yarn / bun (chosen by lockfile)
     - Python (`pyproject.toml`, `requirements.txt` or `setup.py`): `pytest` and `ruff check` when configured; run via `uv run`, `poetry run`, `.venv` or `python3`
     - `Cargo.toml`: `cargo test`, `cargo clippy` (if installed), `cargo build`
     - `go.mod`: `go test ./...`, `go vet ./...`, `go build ./...`
   - No test command → FAIL. Missing lint/build is reported, not fatal.
3. Run each check with `CI=true` and no stdin (no watch modes); print the tail of any failure; full logs go to a temp folder.
4. Scan the branch against main: referee changes (AGENTS.md, sdm files, CI, Makefile, check scripts and configs), deleted tests, added skip/only markers and lint suppressions, size (> 30 files or > 1000 changed lines, lockfiles excluded).
5. Print the EVIDENCE block. Exit 0 only if every check passed.

Fresh means: run in this session, on the current HEAD. Any commit after verify → run it again.

## When verify fails or finds nothing
- Read the failing log and fix the cause, not the check.
- Dependencies missing locally: install them the project's normal way, then re-run.
- No test command: add a real test runner and at least one meaningful test (bootstrap), or a root Makefile `test:` target.
- Tests must run from a fresh clone: put dependency installation in the CI workflow (or a `make setup` target, which the workflow calls), and keep build outputs in `.gitignore`.

## Warnings need PM attention
verify can PASS with warnings. Each goes into the 验收包 under 风险与注意 with a one-line reason. Some are expected (bootstrap touches CI, Makefile and configs). Unexplained weakening — deleted or skipped tests, loosened lint, edited sdm scripts, hooks or AGENTS.md — is a 必须改 in review.

## Acceptance evidence
For each criterion in plan.md: name the test that proves it, or describe what you actually did to try it and what happened. If you can't verify it yourself, say so and tell the PM exactly how to try it. Never mark ✅ on belief.

## Review
Goal: an independent check of one pinned commit against plan.md — not a rewrite, not style preferences.
1. Pin: `SHA=$(git rev-parse <branch>)`, `BASE=$(git merge-base main $SHA)`. Quote the SHA in your findings.
2. Read through git objects only: `git diff $BASE $SHA`, `git show $SHA:<path>`, `git log $BASE..$SHA`. Never checkout, switch, stash, reset, commit or edit: the dev console shares this working copy.
3. Check, in order:
   - Scope: every change traces to plan.md; flag unrelated changes.
   - Acceptance: each criterion has convincing evidence (a test or demo steps).
   - Referee: changes to tests, checks, CI, hooks, sdm files or AGENTS.md are justified; nothing is weakened.
   - Risks: likely bugs, security or privacy issues, data loss, unhandled errors on user paths.
   - Honesty: the 验收包 matches the diff and the evidence.
4. Optional, recommended in local mode — run the checks yourself on the pinned commit in a throwaway worktree: `git worktree add --detach <tmp> $SHA`, install dependencies there, `CI=true bash .agents/skills/sdm/scripts/verify.sh`, then `git worktree remove --force <tmp>`.
5. Report in Chinese, product language first: verdict 可以验收 / 需修改; findings graded 必须改 / 建议改 / 可忽略, each with file:line and a one-line reason.
6. Deliver: GitHub mode → `gh pr comment <PR> --body-file <file>`. Local mode → append a section `## Review @<SHA>` to `docs/work/<id>/review.md` — the only file you may write.
