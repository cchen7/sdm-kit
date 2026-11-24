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
1. `git push -u origin HEAD`
2. `gh pr create --base main --title "<type>: <标题>" --body-file <file>` (the 验收包, in a temp file outside the repo)
3. `gh pr checks --watch` — red CI = not done.
4. Review findings arrive as PR comments: fix, re-verify, push, update the body (`gh pr edit --body-file <file>`).
5. After the PM says 合并: `gh pr merge --merge --delete-branch`, then `git switch main && git pull --ff-only`.

## Integrate: local mode
1. Send the 验收包 in chat. Review findings arrive in `docs/work/<id>/review.md`: commit it together with your fixes.
2. After the PM says 合并 (message file: first line `Merge <branch>: <标题>`, then the 验收包):

       git switch main
       git merge --no-ff <type>/<id> -F <message-file>
       git branch -d <type>/<id>

   Merge commits are allowed on main; plain commits are not.
3. Conflict: `git merge --abort`, `git switch <type>/<id>`, `git merge main`, resolve there, re-verify, retry.

## After the merge
Tell the PM the item is done and suggest a new chat for the next one. The PR (or merge commit), plan.md and the commits are the permanent record.

## Ask the PM first
Any `push --force`, `reset --hard`, rebase of pushed commits, `branch -D`, `clean -fdx`, discarding uncommitted work (`checkout -- .`, `restore .`, `stash drop`), history rewriting, deleting tags, releases or remote branches you didn't create, changing remotes, hooks or git config.

## Harness notes
- Codex's default sandbox keeps `.git` read-only, so branch, commit and merge need approval. Ask with a one-line justification; never work around the sandbox.
- Worktrees are optional in v1. If your harness makes one per task (e.g. Claude Code `--worktree`), keep one per work item and remove it after merge. Avoid them in Codex on Linux/WSL: commits fail inside linked worktrees.
- Hook managers that take over git hooks (husky, pre-commit, lefthook) displace the SDM guard and preflight will fail. Don't add one without the PM's approval.
