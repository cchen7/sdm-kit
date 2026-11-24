#!/usr/bin/env bash
# SDM verify — run the repo's configured checks and print candidate evidence.
# Usage: bash .agents/skills/sdm/scripts/verify.sh   Exit 0 = PASS.   Details: references/verification.md
root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "SDM-VERIFY: FAIL — not a git repository"; exit 1; }
cd "$root" || exit 1
SKILL=.agents/skills/sdm; LOG=$(mktemp -d "${TMPDIR:-/tmp}/sdm-verify.XXXXXX")
checks=(); rows=(); warns=(); kinds=" "; fail=0

# 1 · Gate (local only): preflight OK and a clean tree, so the evidence belongs to a commit.
if [ -z "${CI:-}" ]; then
  bash "$SKILL/scripts/preflight.sh" >"$LOG/preflight.txt" 2>&1 || { cat "$LOG/preflight.txt"; echo "SDM-VERIFY: FAIL — preflight not OK"; exit 1; }
  [ -z "$(git status --porcelain)" ] || { git status --short | head -n 20; echo "SDM-VERIFY: FAIL — uncommitted changes; commit first"; exit 1; }
fi

# A requested comparison must be possible; a shallow/missing base is not a clean scan.
base=${SDM_BASE_SHA:-}; mb=""
if [ -n "$base" ]; then
  if ! [[ $base =~ ^([[:xdigit:]]{40}|[[:xdigit:]]{64})$ ]] || ! mb=$(git merge-base HEAD "$base" 2>/dev/null); then
    echo "SDM-VERIFY: FAIL — SDM_BASE_SHA must be a full commit ID with available shared history." >&2
    exit 1
  fi
elif [ -z "${CI:-}" ]; then
  for b in main master origin/main origin/master; do
    if mb=$(git merge-base HEAD "$b" 2>/dev/null); then base=$b; break; fi
  done
fi

# 2 · Discover checks. A root Makefile defining test/lint/build wins; otherwise every detected stack contributes.
add() { checks+=("$1|$2"); }
if [ -f Makefile ] && grep -Eq '^(test|lint|build)[[:space:]]*:' Makefile; then
  for t in test lint build; do grep -Eq "^$t[[:space:]]*:" Makefile && add $t "make $t"; done
else
  if [ -f package.json ]; then
    pm=npm; [ -f pnpm-lock.yaml ] && pm=pnpm; [ -f yarn.lock ] && pm=yarn; { [ -f bun.lock ] || [ -f bun.lockb ]; } && pm=bun
    command -v node >/dev/null || warns+=("package.json found but node is not installed")
    for k in $(node -e 'const s=require("./package.json").scripts||{};for(const k of ["test","lint","typecheck","build"])if(s[k]&&!/no test specified/.test(s[k]))console.log(k)' 2>/dev/null); do
      case $k in typecheck) add lint "$pm run typecheck" ;; *) add $k "$pm run $k" ;; esac
    done
  fi
  if [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f setup.py ]; then
    py=python3; [ -x .venv/bin/python ] && py=.venv/bin/python
    [ -f poetry.lock ] && py="poetry run python"; [ -f uv.lock ] && py="uv run python"
    { [ -f conftest.py ] || [ -f pytest.ini ] || cat pyproject.toml setup.cfg tox.ini requirements*.txt 2>/dev/null | grep -q pytest; } && add test "$py -m pytest -q"
    { [ -f ruff.toml ] || [ -f .ruff.toml ] || grep -q '^\[tool\.ruff' pyproject.toml 2>/dev/null; } && add lint "$py -m ruff check ."
  fi
  if [ -f Cargo.toml ]; then add test "cargo test"; command -v cargo-clippy >/dev/null && add lint "cargo clippy --all-targets -- -D warnings"; add build "cargo build"; fi
  if [ -f go.mod ]; then add test "go test ./..."; add lint "go vet ./..."; add build "go build ./..."; fi
  for manifest in ./Package.swift Packages/*/Package.swift; do
    [ -f "$manifest" ] || continue
    printf -v package_path '%q' "${manifest%/Package.swift}"
    add test "swift test --package-path $package_path"
  done
  for project in *.xcodeproj *.xcworkspace; do
    [ -d "$project" ] || continue
    warns+=("Xcode project detected: package checks do not cover app builds, native UI, signing or project guardrails. Use the documented host checks.")
    break
  done
fi
printf '%s\n' "${checks[@]}" | grep -q '^test|' || {
  echo "SDM-VERIFY: FAIL — no supported test entry point was discovered."
  echo "Check this project's instructions and CI; expose existing checks through a root Makefile test target. Bootstrap only if no tests exist."
  exit 1; }

# 3 · Run each check non-interactively (CI=true, no stdin) and keep the logs.
i=0
for c in "${checks[@]}"; do
  i=$((i+1)); kind=${c%%|*}; cmd=${c#*|}; t0=$SECONDS; kinds="$kinds$kind "
  if CI=true bash -c "$cmd" </dev/null >"$LOG/$i-$kind.log" 2>&1; then st=PASS; else st=FAIL; fail=1; fi
  rows+=("$(printf '  %-4s  %-5s  %s  (%ss)' $st $kind "$cmd" $((SECONDS-t0)))")
  [ $st = PASS ] || { echo "---- FAILED: $cmd (last 40 lines; full log: $LOG/$i-$kind.log)"; tail -n 40 "$LOG/$i-$kind.log"; }
done

# 4 · Diff scan: referee changes, weakened tests, size.
if [ -n "$mb" ]; then
  [ -z "$(git status --porcelain)" ] || warns+=("checks created or changed files — keep build outputs in .gitignore: $(git status --porcelain | head -n 3 | tr '\n' ' ')")
  f=$(git diff --name-only "$mb" HEAD | grep -E '^(AGENTS\.md|CLAUDE\.md|\.agents/|\.claude/|\.github/|Makefile$)|(^|/)(\.eslintrc[^/]*|eslint\.config\.[^/]*|ruff\.toml|pytest\.ini|tox\.ini|setup\.cfg|tsconfig[^/]*\.json|\.golangci[^/]*)$' | head -n 8 | tr '\n' ' ')
  [ -n "$f" ] && warns+=("referee/check config changed: $f")
  git diff "$mb" HEAD -- package.json | grep -Eq '^[-+][[:space:]]*"(test|lint|typecheck|build)"[[:space:]]*:' && warns+=("package.json check scripts changed")
  f=$(git diff --name-only --diff-filter=D "$mb" HEAD | grep -E '(^|/)(tests?|__tests__|spec)/|[._-](test|spec)\.[A-Za-z]+$|_test\.go$|(^|/)test_[^/]*\.py$' | head -n 5 | tr '\n' ' ')
  [ -n "$f" ] && warns+=("test files deleted: $f")
  added=$(git diff -U0 "$mb" HEAD -- . ':(exclude).agents' ':(exclude).claude' | grep -E '^\+([^+]|$)')
  n=$(printf '%s\n' "$added" | grep -cE '\.(skip|only)\(|(^|[^A-Za-z0-9_])x(it|describe|test)\(|@pytest\.mark\.(skip|xfail)|pytest\.skip\(|@unittest\.skip|t\.Skip\(|#\[ignore\]')
  [ "$n" -gt 0 ] && warns+=("$n added test skip/only/xfail marker(s)")
  n=$(printf '%s\n' "$added" | grep -cE 'eslint-disable|@ts-(ignore|nocheck|expect-error)|#[[:space:]]*noqa|#[[:space:]]*type:[[:space:]]*ignore|pragma: no cover|#\[allow\(|//[[:space:]]*nolint')
  [ "$n" -gt 0 ] && warns+=("$n added lint/type suppression(s)")
  set -- $(git diff --numstat "$mb" HEAD -- . ':(exclude)*.lock' ':(exclude)*-lock.*' ':(exclude)*.lockb' ':(exclude)*go.sum' | awk '{a+=$1; d+=$2; n++} END {print n+0, a+0, d+0}')
  size="$(git rev-list --count "$mb..HEAD") commit(s), $1 file(s), +$2/-$3 lines (lockfiles excluded)"
  { [ "$1" -gt 30 ] || [ $(($2+$3)) -gt 1000 ]; } && warns+=("large change — consider splitting the work item")
fi

# 5 · Evidence — paste this block into the 验收包.
res=PASS; [ $fail = 0 ] || res=FAIL
echo "===== SDM VERIFY EVIDENCE ====="
echo "Result:  $res"
echo "Commit:  $(git rev-parse --short HEAD) on $(git symbolic-ref -q --short HEAD || echo detached) · $(date '+%Y-%m-%d %H:%M %z')"
if [ -n "$mb" ]; then
  echo "Diff scan: compared $mb..HEAD — $size"
else
  echo "Diff scan: NOT RUN (no comparison base; provide SDM_BASE_SHA with both histories available)"
fi
echo "Checks:"; printf '%s\n' "${rows[@]}"
for k in test lint build; do case $kinds in *" $k "*) ;; *) printf '  %-4s  %-5s  %s\n' "--" $k "not configured" ;; esac; done
[ ${#warns[@]} -gt 0 ] && { echo "Warnings (explain each in the 验收包 under 风险与注意):"; printf '  ! %s\n' "${warns[@]}"; }
echo "Logs:    $LOG"
echo "==============================="
echo "SDM-VERIFY: $res"
exit $fail
