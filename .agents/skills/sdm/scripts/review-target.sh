#!/usr/bin/env bash
# Resolve the review target (BRANCH, SHA, BASE, PLAN) without modifying the working copy.
# Usage: bash .agents/skills/sdm/scripts/review-target.sh [branch-or-commit]
set -e -o pipefail
[ "$#" -le 1 ] || { echo "Usage: bash .agents/skills/sdm/scripts/review-target.sh [branch-or-commit]" >&2; exit 2; }
root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "SDM review: not a git repository" >&2; exit 1; }
cd "$root" || exit 1

base_ref=""
for b in main master; do
  if git rev-parse -q --verify "$b^{commit}" >/dev/null; then
    base_ref=$b
    if git rev-parse -q --verify "origin/$b^{commit}" >/dev/null &&
       git merge-base --is-ancestor "$b" "origin/$b" 2>/dev/null &&
       ! git merge-base --is-ancestor "origin/$b" "$b" 2>/dev/null; then
      base_ref="origin/$b"
    fi
    break
  fi
done
if [ -z "$base_ref" ]; then
  for b in origin/main origin/master; do
    if git rev-parse -q --verify "$b^{commit}" >/dev/null; then base_ref=$b; break; fi
  done
fi
[ -n "$base_ref" ] || { echo "SDM review: no main/master base branch found" >&2; exit 1; }

plan_for() {
  local ref=$1 sha=$2 mb=$3 clean id p
  clean=${ref#refs/heads/}
  clean=${clean#refs/remotes/}
  clean=${clean#origin/}
  if [[ $clean == */* ]]; then
    id=${clean#*/}
    p="docs/work/$id/plan.md"
    if git cat-file -e "$sha:$p" 2>/dev/null; then printf '%s\n' "$p"; return 0; fi
  fi
  p=$(git diff --name-only "$mb" "$sha" -- 'docs/work/*/plan.md' 2>/dev/null | head -n 2)
  if [ "$(printf '%s\n' "$p" | sed '/^$/d' | wc -l | tr -d ' ')" = 1 ]; then
    printf '%s\n' "$p"
  elif [[ $clean == */* ]]; then
    printf 'docs/work/%s/plan.md\n' "${clean#*/}"
  fi
}

title_for() {
  local sha=$1 p=$2
  [ -n "$p" ] && git cat-file -e "$sha:$p" 2>/dev/null || return 0
  git show "$sha:$p" 2>/dev/null | head -n 1 | sed 's/^#[[:space:]]*//'
}

if [ "$#" -eq 1 ]; then
  branch=$1
  sha=$(git rev-parse -q --verify "$branch^{commit}") || { echo "SDM review: unknown branch or commit: $branch" >&2; exit 1; }
  mb=$(git merge-base "$base_ref" "$sha") || { echo "SDM review: no shared history between $base_ref and $branch" >&2; exit 1; }
else
  candidates=()
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    case $b in main|master) continue ;; esac
    git merge-base --is-ancestor "$b" "$base_ref" 2>/dev/null || candidates+=("$b")
  done < <(git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads)

  if [ "${#candidates[@]}" -eq 0 ]; then
    while IFS= read -r b; do
      [ -n "$b" ] || continue
      case $b in origin/HEAD|origin/main|origin/master) continue ;; esac
      git merge-base --is-ancestor "$b" "$base_ref" 2>/dev/null || candidates+=("$b")
    done < <(git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/remotes/origin)
  fi

  if [ "${#candidates[@]}" -eq 0 ]; then
    echo "SDM review: no unmerged work branch found (base: $base_ref). Pass a branch or commit explicitly." >&2
    exit 1
  elif [ "${#candidates[@]}" -gt 1 ]; then
    cur=$(git symbolic-ref -q --short HEAD || true)
    echo "SDM review: multiple unmerged work branches found — ask the PM which item to review:" >&2
    for b in "${candidates[@]}"; do
      s=$(git rev-parse --verify "$b^{commit}")
      m=$(git merge-base "$base_ref" "$s" 2>/dev/null || printf '%s' "$s")
      p=$(plan_for "$b" "$s" "$m")
      t=$(title_for "$s" "$p")
      mark=""; [ "$b" = "$cur" ] && mark=" (checked out)"
      echo "  - $b${t:+ — $t}$mark" >&2
    done
    exit 1
  fi
  branch=${candidates[0]}
  sha=$(git rev-parse --verify "$branch^{commit}")
  mb=$(git merge-base "$base_ref" "$sha")
fi

plan=$(plan_for "$branch" "$sha" "$mb")
title=$(title_for "$sha" "$plan")
echo "BRANCH=$branch"
echo "SHA=$sha"
echo "BASE=$mb"
echo "BASE_REF=$base_ref"
echo "PLAN=${plan:-(none)}"
[ -n "$title" ] && echo "TITLE=$title" || true
