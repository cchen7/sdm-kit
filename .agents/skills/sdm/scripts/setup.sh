#!/usr/bin/env bash
# Reinstall the project Git guards and the Claude Code skill link.
root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "SDM setup: not a git repository" >&2; exit 1; }
cd "$root" || exit 1
G=.agents/skills/sdm/hooks/guard.sh
hooks=$(git rev-parse --git-path hooks) || exit 1
rc=0
if git config --get core.hooksPath >/dev/null 2>&1; then
  echo "SDM setup: core.hooksPath is set; existing hooks were left intact. Resolve the hook configuration before installing the guard." >&2
  rc=1
elif [ -L "$hooks" ] || ! mkdir -p "$hooks"; then
  echo "SDM setup: cannot use the repository hooks directory: $hooks" >&2
  rc=1
else
  for h in pre-commit pre-push; do
    f=$hooks/$h
    if [ -L "$f" ] || { [ -e "$f" ] && { [ ! -f "$f" ] || ! grep -q '^# SDM-GUARD' "$f"; }; }; then
      echo "SDM setup: $f belongs to another tool and was not replaced." >&2
      rc=1
    elif cmp -s "$f" "$G" && [ -x "$f" ]; then
      echo "SDM setup: $h guard OK"
    elif cp "$G" "$f" && chmod +x "$f"; then
      echo "SDM setup: installed $h guard"
    else
      rc=1
    fi
  done
fi

link=.claude/skills/sdm
target=../../.agents/skills/sdm
if [ -L .claude ] || [ -L .claude/skills ]; then
  echo "SDM setup: use a project-local directory for .claude/skills." >&2
  rc=1
elif [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ] && [ -f "$link/SKILL.md" ]; then
  echo "SDM setup: Claude Code skill link OK"
elif [ -e "$link" ] || [ -L "$link" ]; then
  echo "SDM setup: $link already exists and was not replaced. Use it or move it before installing the SDM link." >&2
  rc=1
elif [ -f .agents/skills/sdm/SKILL.md ] && mkdir -p .claude/skills && ln -s "$target" "$link"; then
  echo "SDM setup: linked $link → .agents/skills/sdm"
else
  echo "SDM setup: could not link the Claude Code skill." >&2
  rc=1
fi
exit "$rc"
