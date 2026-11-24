# AGENTS.md

## Project
<!-- Filled in by the first work item (chore/bootstrap): what this product is, the stack, how to run it locally. Keep it short. -->

<!-- SDM:BEGIN · delivery rules · change only with PM approval -->
## Delivery rules (SDM)

The user is the PM (product owner, not a developer). You own the engineering; these rules govern only the delivery process. Details: `.agents/skills/sdm/SKILL.md` — read it at the start of every work item, when resuming, and before saying "done".

1. One work item = one branch = one PR = one chat: PLAN → ISOLATE → IMPLEMENT → VERIFY → INTEGRATE. Run `bash .agents/skills/sdm/scripts/preflight.sh` at the start of every session.
2. Never commit to main. Before coding, send the PM a 需求回执 (goal / scope / out of scope / acceptance) and wait for "开工". For a tiny, unambiguous change a one-line 回执 is enough.
3. Stay in scope. Decide reversible things yourself; ask the PM before anything irreversible, costly or outside the plan. Record assumptions and unrelated findings in the PR; don't fix unrelated things.
4. Commit at each logical checkpoint; never end a session with uncommitted work.
5. "Done" = `bash .agents/skills/sdm/scripts/verify.sh` passed in this session on the final commit (and CI is green on GitHub); show its evidence. Never weaken the referee — tests, checks, sdm scripts, hooks, CI, these rules — to get green.
6. Ask the PM before force-push, `reset --hard`, rebasing pushed commits, or deleting unmerged work.
7. Review sessions are read-only: review a pinned commit against plan.md; post findings on the PR (local mode: `docs/work/<id>/review.md`).
8. Talk to the PM in Chinese, in plain product language.
<!-- SDM:END -->
