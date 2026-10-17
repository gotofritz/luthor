#!/usr/bin/env bash
# Table tests for check-conventional-commit.sh. Run: scripts/test-check-conventional-commit.sh
set -uo pipefail

script="$(dirname "$0")/check-conventional-commit.sh"
failures=0

expect() {
  local want="$1" max="$2" header="$3"
  if "$script" "$max" "$header" >/dev/null 2>&1; then got=pass; else got=fail; fi
  if [[ "$got" != "$want" ]]; then
    echo "FAIL: expected $want for (max $max) '$header', got $got"
    failures=$((failures + 1))
  fi
}

expect pass 72 "feat: add inbox"
expect pass 72 "feat(domain): add TaskDeferred event"
expect pass 72 "fix(cli)!: rename done to complete"
expect pass 72 "refactor!: drop the old store"
for type in feat fix refactor perf test docs build ci chore style revert; do
  expect pass 72 "$type: something"
done
expect pass 50 "docs: $(printf 'x%.0s' {1..44})"   # exactly 50
expect fail 50 "docs: $(printf 'x%.0s' {1..45})"   # 51
expect fail 72 "Add inbox"
expect fail 72 "feature: add inbox"
expect fail 72 "Feat: add inbox"
expect fail 72 "feat:add inbox"
expect fail 72 "feat: "
expect fail 72 "feat(): add inbox"
expect fail 72 "feat(Domain): add inbox"
expect fail 72 ""
expect pass 72 "Merge branch 'main' into feature/inbox"
expect pass 72 "fixup! feat: add inbox"

# commit-msg mode: first non-comment line of a file
tmp="$(mktemp)"
printf '# comment\nfeat: from a file\n\nbody line\n' >"$tmp"
if ! "$script" 72 --file "$tmp" >/dev/null 2>&1; then
  echo "FAIL: expected pass for message file"
  failures=$((failures + 1))
fi
printf 'not conventional\n' >"$tmp"
if "$script" 72 --file "$tmp" >/dev/null 2>&1; then
  echo "FAIL: expected fail for bad message file"
  failures=$((failures + 1))
fi
rm -f "$tmp"

if ((failures > 0)); then
  echo "$failures check(s) failed"
  exit 1
fi
echo "check-conventional-commit: all checks passed"
