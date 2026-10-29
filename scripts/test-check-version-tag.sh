#!/usr/bin/env bash
# Table tests for check-version-tag.sh. Run: scripts/test-check-version-tag.sh
set -uo pipefail

script="$(dirname "$0")/check-version-tag.sh"
failures=0

# expect <ok|bad> <tag>
expect() {
  local status=ok
  "$script" "$2" >/dev/null 2>&1 || status=bad
  if [[ "$status" != "$1" ]]; then
    echo "FAIL: expected $1 for '$2'"
    failures=$((failures + 1))
  fi
}

expect ok "v0.3.0"
expect ok "v1.12.4"
expect bad "0.3.0"
expect bad "v0.3"
expect bad "v0.3.0-rc1"
expect bad "v0.3.0 --draft"
expect bad 'v0.3.0$(id)'
expect bad "v0.3.0
x"
expect bad ""

((failures == 0)) && echo "check-version-tag: all passed"
exit $((failures > 0))
