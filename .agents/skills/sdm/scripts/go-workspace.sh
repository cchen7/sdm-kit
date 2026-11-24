#!/usr/bin/env bash
# Run one Go check over the checkout's workspace modules, including a module at its root.
set -e
case ${1:-} in test|vet|build) ;; *) exit 2;; esac
root=$(pwd -P)
export GOWORK="$root/go.work"
dirs=$(go list -m -f '{{.Dir}}')
[ -n "$dirs" ] || { echo 'SDM: no modules in go.work' >&2; exit 1; }
patterns=()
while IFS= read -r dir; do
  physical=$(cd -P -- "$dir" && pwd -P)
  case $physical in
    "$root") patterns+=("./...");;
    "$root"/*) patterns+=("./${physical#"$root"/}/...");;
    *) echo 'SDM: go.work includes a module outside this checkout; define the intended scope with make test.' >&2; exit 1;;
  esac
done <<< "$dirs"
go "$1" "${patterns[@]}"
