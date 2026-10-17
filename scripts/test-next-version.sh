#!/usr/bin/env bash
# Table tests for next-version.sh. Run: scripts/test-next-version.sh
set -uo pipefail

script="$(dirname "$0")/next-version.sh"
failures=0

# expect <want> <current tag> <commit subject>...   (want "" means: no release)
expect() {
  local want="$1" current="$2"
  shift 2
  local got
  got="$(printf '%s\n' "$@" | "$script" "$current" 2>/dev/null)"
  if [[ "$got" != "$want" ]]; then
    echo "FAIL: expected '$want' from '$current' with: $*; got '$got'"
    failures=$((failures + 1))
  fi
}

# the first release
expect "v0.1.0" "" "feat: first"
expect "v0.1.0" "" "fix: first"
expect "" "" "docs: readme"

# what each type bumps
expect "v0.2.0" "v0.1.0" "feat(app): add a thing"
expect "v0.1.1" "v0.1.0" "fix(store): mend a thing"
expect "v0.1.1" "v0.1.0" "perf(domain): faster replay"
expect "v1.3.0" "v1.2.5" "feat: add a thing"
expect "v1.2.6" "v1.2.5" "fix: mend a thing"

# types that do not release
for type in docs test ci chore style build refactor; do
  expect "" "v0.1.0" "$type: something"
  expect "" "v0.1.0" "$type(scope): something"
done
expect "" "v0.1.0" "Merge branch 'main' into feature/x"
expect "" "v0.1.0" "not a conventional commit"
expect "" "v0.1.0"

# the biggest bump wins, in any order
expect "v0.2.0" "v0.1.0" "fix: a" "feat: b" "docs: c"
expect "v0.2.0" "v0.1.0" "feat: b" "fix: a"
expect "v0.1.1" "v0.1.0" "chore: a" "fix: b"

# breaking changes: major, but 0.x moves to the next minor instead of jumping to 1.0.0
expect "v2.0.0" "v1.2.5" "feat(app)!: drop the old store"
expect "v2.0.0" "v1.2.5" "fix: a" "refactor!: b"
expect "v0.2.0" "v0.1.5" "feat!: drop the old store"
expect "v0.2.0" "v0.1.5" "chore!: drop the old store"
expect "v0.2.0" "v0.1.5" "docs!: drop the old store"

# a tag without the v is accepted, the output always has it
expect "v0.2.0" "0.1.0" "feat: a"

# a current version that is not x.y.z is an error
if printf 'feat: a\n' | "$script" "latest" >/dev/null 2>&1; then
  echo "FAIL: expected an error for a tag that is not a version"
  failures=$((failures + 1))
fi

if ((failures > 0)); then
  echo "$failures check(s) failed"
  exit 1
fi
echo "next-version: all checks passed"
