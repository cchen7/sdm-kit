#!/usr/bin/env bash
# SDM preflight — where am I in the lifecycle, and may I write code now? Read-only.
# Exit 0 = on a work branch with a committed plan and the guard installed.
root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "SDM: not a git repository. PM: run install.sh from the SDM kit."; exit 1; }
cd "$root" || exit 1
SKILL=.agents/skills/sdm; rc=0; warns=""
warn() { warns="$warns  ! $1"$'\n'; }
same() { [ -f "$1" ] && [ "$(git hash-object --no-filters "$1")" = "$(git hash-object --no-filters "$2")" ]; }   # portable cmp
base=""; for b in main master origin/main origin/master; do git rev-parse -q --verify "$b^{commit}" >/dev/null && { base=$b; break; }; done
br=$(git symbolic-ref -q --short HEAD) || br="(detached)"
dirty=$(git status --porcelain | wc -l | tr -d ' ')
hooks=$(git rev-parse --git-path hooks)
for h in pre-commit pre-push; do
  same "$hooks/$h" "$SKILL/hooks/guard.sh" || { rc=1; warn "guard hook '$h' missing or modified → bash $SKILL/scripts/setup.sh"; }
done
[ -z "$(git ls-files | grep -vE '^(AGENTS\.md|CLAUDE\.md|\.gitignore|\.agents/|\.claude/|\.github/|docs/)' | head -n 1)" ] &&
  warn "no product code yet → the first work item is chore/bootstrap (SKILL.md step 0)"
re='^(feature|fix|chore|refactor|docs)/[a-z0-9][a-z0-9._-]*$'
case $br in
  main|master)
    rc=1; phase=PLAN; next="Send the PM a 需求回执; after \"开工\": git switch -c <type>/<id>"
    [ "$dirty" != 0 ] && next="Uncommitted changes on $br: move them to a work branch now (git switch -c <type>/<id> takes them along). Never commit on $br." ;;
  "(detached)")
    rc=1; phase="-"; next="git switch <work-branch>   (review sessions don't need preflight)" ;;
  *)
    id=${br#*/}; plan=docs/work/$id/plan.md
    [[ $br =~ $re ]] || warn "branch name should be <type>/<id> (type: feature|fix|chore|refactor|docs)"
    if git cat-file -e "HEAD:$plan" 2>/dev/null; then
      phase=IMPLEMENT; title=$(git show "HEAD:$plan" | head -n 1)
      next=$(git log -1 --format=%B | grep -m1 '^Next:')
      [ -z "$next" ] && next="Implement within plan.md; commit checkpoints; when done run verify.sh"
      if [ -n "$base" ]; then
        ahead=$(git rev-list --count "$base..HEAD"); behind=$(git rev-list --count "HEAD..$base")
        [ "$behind" != 0 ] && warn "$base has $behind newer commit(s) → git merge $base before integrating"
      fi
    else
      rc=1; phase=ISOLATE; next="Write $plan from the agreed 需求回执 and commit it as the branch's first commit"
    fi ;;
esac
echo "SDM preflight"
echo "  Branch:  $br${base:+   (base: $base)}"
[ -n "${plan:-}" ] && echo "  Plan:    $plan${title:+   — $title}"
echo "  Tree:    $([ "$dirty" = 0 ] && echo clean || echo "$dirty uncommitted change(s)")${ahead:+   · $ahead commit(s) on this branch}"
echo "  Phase:   $phase"
echo "  Next:    $next"
printf '%s' "$warns"
if [ $rc = 0 ]; then echo "PREFLIGHT: OK — you may write code on $br"; else echo "PREFLIGHT: NOT READY to write code"; fi
exit $rc
