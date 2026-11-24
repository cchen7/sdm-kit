# Git lifecycle (SDM)

Read when isolating, integrating or cleaning up, and before any git operation that feels risky.

## Invariants
- `main` changes only by merging a verified, PM-accepted work branch. The guard hook blocks plain commits on main/master and pushes to an existing remote main/master; GitHub branch protection enforces the same server-side where enabled.
- One work item = one branch `<type>/<id>` = one PR = one folder `docs/work/<id>/`.
- Bring main into your branch by merging (`git merge main`), not rebasing: no history rewriting, no force-push.

## Mode
GitHub mode when `origin` points to GitHub and `gh auth status` succeeds; otherwise local mode. Unsure → ask the PM.

## Start a work item
    git switch main
    git pull --ff-only                  # GitHub mode
    git switch -c feature/<id>          # or fix/ chore/ refactor/ docs/
    # write docs/work/<id>/plan.md, then
    git add docs/work/<id>/plan.md && git commit -m "docs: plan for <id>"

## Checkpoints
Message `<type>: <what changed>`. Stopping mid-way: add a body line `Next: <what remains>`; preflight shows it to the next session.

## Integrate: GitHub mode
1. At the first reviewable checkpoint, when publishing is authorized, `git push -u origin HEAD` and open a draft with `gh pr create --draft --base main --title "<type>: <标题>" --body-file <file>`. Use this same PR for the final 验收包. Without push authorization, share the local commit range.
2. Record the reviewed full head SHA and the target base SHA. If the base advances across a shared manifest, migration or user path, verify the combined tree and record its tree ID before merging.
3. `gh pr checks --watch` — red CI = not done.
4. Review findings arrive as PR comments: fix, re-verify, push, update the body (`gh pr edit --body-file <file>`).
5. After acceptance and merge authorization, mark the draft ready if needed, then use `gh pr merge <PR> --merge --match-head-commit "$REVIEWED_HEAD"` (omit the strategy for a merge queue). Use the full SHA from the review. A mismatch requires review of the new head. Wait for the PR to be merged; verify the merge commit and, when a combined tree was tested, compare tree IDs. Only then sync main and clean up the merged branch.

## Integrate: local mode
1. Keep scope, evidence and next owner in the shared plan; the Git ID of the handoff commit identifies a local candidate without writing its SHA into itself. Send the 验收包 in chat. Record findings in `docs/work/<id>/review.md` together with any fixes; put the final verdict and reviewed SHA in the merge message.
2. After the PM says 合并 (message file: first line `Merge <branch>: <标题>`, then the 验收包):

       # Set WORK_BRANCH and REVIEWED_HEAD from the handoff; MESSAGE_FILE is the acceptance note.
       if [ "$(git rev-parse "$WORK_BRANCH")" = "$REVIEWED_HEAD" ]; then
         git switch main && git merge --no-ff "$REVIEWED_HEAD" -F "$MESSAGE_FILE"
       else
         echo "Branch changed; review the new head before merging."
       fi

   Verify the merge commit and any tested combined tree before removing the merged branch. Merge commits are allowed on main; plain commits are not.
3. Conflict: `git merge --abort`, `git switch <type>/<id>`, `git merge main`, resolve there, re-verify, retry.

## After the merge
Tell the PM the item is done and suggest a new chat for the next one. The PR (or merge commit), plan.md and the commits are the permanent record. A grant to merge covers that action and scope; it does not grant permission to publish a release or send a different artifact. Carry forward still-valid grants without asking again.

## Ask the PM first
Any `push --force`, `reset --hard`, rebase of pushed commits, `branch -D`, `clean -fdx`, discarding uncommitted work (`checkout -- .`, `restore .`, `stash drop`), history rewriting, deleting tags, releases or remote branches you didn't create, changing remotes, hooks or git config.

## Harness notes
- Codex's default sandbox keeps `.git` read-only, so branch, commit and merge need approval. Ask with a one-line justification; never work around the sandbox.
- Worktrees are optional in v1. If your harness makes one per task (e.g. Claude Code `--worktree`), keep one per work item and remove it after merge. Avoid them in Codex on Linux/WSL: commits fail inside linked worktrees.
- Hook managers that take over git hooks (husky, pre-commit, lefthook) displace the SDM guard and preflight will fail. Don't add one without the PM's approval.
