#!/usr/bin/env bash
# SDM-GUARD — installed by .agents/skills/sdm/scripts/setup.sh as the pre-commit and pre-push hooks.
# Edit the template (.agents/skills/sdm/hooks/guard.sh), never the installed copy: preflight checks they match.
protected='^(main|master)$'; zero='^0+$'
case $(basename "$0") in
  pre-commit)
    br=$(git symbolic-ref -q --short HEAD) || exit 0      # detached HEAD (rebase etc.): allow
    if [[ $br =~ $protected ]] && ! git rev-parse -q --verify MERGE_HEAD >/dev/null; then
      echo "SDM: 不能直接在 $br 上提交 / no direct commits on $br." >&2
      echo "     先建工作分支 / create a work branch first: git switch -c feature/<id>" >&2
      exit 1
    fi ;;
  pre-push)
    while read -r _ _ rref rsha; do
      b=${rref#refs/heads/}
      if [[ $b =~ $protected ]] && ! [[ $rsha =~ $zero ]]; then   # only the very first push of main is allowed
        echo "SDM: 不能直接推送到远端 $b / no direct push to $b — push the work branch and open a PR." >&2
        exit 1
      fi
    done ;;
esac
exit 0
