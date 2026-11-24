#!/usr/bin/env bash
# Usage: bash install.sh [project-dir] [--update]
#   --update  refresh the sdm skill and the SDM block of AGENTS.md from this kit.
set -e -o pipefail
KIT=$(cd "$(dirname "$0")" && pwd -P)
TPL=$KIT/template
SKILL=.agents/skills/sdm
update=0; dir=.; new_empty_repo=0
for a in "$@"; do
  case $a in
    --update) update=1 ;;
    -h|--help) sed -n '2,3p' "$0"; exit 0 ;;
    --*) echo "SDM: unknown option: $a" >&2; exit 1 ;;
    *) dir=$a ;;
  esac
done
mkdir -p -- "$dir"
cd -- "$dir"
[ "$(pwd -P)" = "$KIT" ] && { echo "SDM: this kit already contains the skill. Name a target project folder, e.g. bash install.sh ~/code/my-app"; exit 1; }
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  [ -n "$(find . -mindepth 1 -maxdepth 1 -print -quit)" ] || new_empty_repo=1
  git init -q -b main
  echo "SDM: new git repository (branch: main)"
fi
top=$(git rev-parse --show-toplevel)
[ "$top" = "$(pwd -P)" ] || { echo "SDM: please run this at the repository root: $top"; exit 1; }
for p in .agents .agents/skills "$SKILL" "$SKILL"/{hooks,references,scripts} .claude .claude/skills .github .github/workflows docs docs/work; do
  if [ -L "$p" ]; then
    echo "SDM: $p is a symlink; use a project-local directory before installing." >&2
    exit 1
  fi
done
echo "SDM: installing into $top"

install_file() {
  local f=$1 src=$2 tmp
  if [ -L "$f" ]; then
    echo "  = $f (symlink, kept)"
  elif [ "$f" = AGENTS.md ] && [ -f "$f" ]; then
    if ! grep -q '<!-- SDM:BEGIN' "$f"; then
      { echo; sed -n '/<!-- SDM:BEGIN/,/<!-- SDM:END/p' "$src"; } >> "$f"
      echo "  + AGENTS.md (SDM rules appended)"
    elif [ "$update" = 1 ]; then
      if [ "$(grep -c '<!-- SDM:BEGIN' "$f")" != 1 ] || [ "$(grep -c '<!-- SDM:END' "$f")" != 1 ]; then
        echo "SDM: AGENTS.md must have one complete SDM block before updating." >&2
        return 1
      fi
      tmp=$(mktemp AGENTS.md.sdm.XXXXXX)
      cp -p "$f" "$tmp"
      if awk -v t="$src" '/<!-- SDM:BEGIN/ { while ((getline l < t) > 0) { if (l ~ /<!-- SDM:BEGIN/) p=1; if (p) print l; if (l ~ /<!-- SDM:END/) p=0 } s=1; next }
        /<!-- SDM:END/ { if (!s) exit 1; s=0; next } !s; END { if (s) exit 1 }' "$f" > "$tmp"; then
        mv "$tmp" "$f"
        echo "  ~ AGENTS.md (SDM rules refreshed)"
      else
        rm -f "$tmp"
        echo "SDM: could not refresh the SDM block in AGENTS.md." >&2
        return 1
      fi
    fi
  elif [ "$f" = CLAUDE.md ] && [ -f "$f" ]; then
    if ! grep -Eq '^@(\./)?AGENTS\.md[[:space:]]*$' "$f"; then
      { printf '\n\n'; cat "$src"; } >> "$f"
      echo "  + CLAUDE.md (AGENTS.md import appended)"
    fi
  elif [ ! -e "$f" ]; then
    mkdir -p "$(dirname "$f")"
    cp -p "$src" "$f"
    echo "  + $f"
  elif ! cmp -s "$src" "$f"; then
    case $f in
      "$SKILL"/*)
        if [ "$update" = 1 ] && [ -f "$f" ]; then
          cp -p "$src" "$f"
          echo "  ~ $f"
        else
          echo "  = $f (differs from the kit; kept — use --update for skill files)"
        fi ;;
      *) echo "  = $f (exists, kept)" ;;
    esac
  fi
}
install_tree() {
  local srcroot=$1 prefix=$2 f
  (cd "$srcroot" && find . -type f ! -name .DS_Store) | while IFS= read -r f; do
    f=${f#./}
    install_file "$prefix$f" "$srcroot/$f"
  done
}
install_tree "$TPL" ""
install_tree "$KIT/$SKILL" "$SKILL/"
bash "$KIT/$SKILL/scripts/setup.sh" || {
  echo "SDM: resolve the setup message above, then rerun the installer." >&2
  exit 1
}
if [ "$new_empty_repo" = 1 ]; then
  if ! git var GIT_AUTHOR_IDENT >/dev/null 2>&1 || ! git var GIT_COMMITTER_IDENT >/dev/null 2>&1; then
    echo 'SDM: configure a Git name and email for this repository before committing the installed files.' >&2
    exit 1
  fi
  git add -- AGENTS.md CLAUDE.md .gitignore "$SKILL" .claude/skills/sdm .github/workflows/sdm-verify.yml docs/work/README.md
  git commit -q --no-verify -m "chore: install SDM control plane"
  echo "SDM: first commit created on main"
else
  echo "SDM: nothing was staged or committed. Review and commit the SDM changes as a work item."
fi
cat <<'NEXT'

SDM 已就绪。在目标项目打开 Codex、Claude Code 或 GitHub Copilot CLI。
新项目：按 SDM 流程，先做 bootstrap：<一句话描述你的产品>
已有项目：按 SDM 流程：<需求>
NEXT
