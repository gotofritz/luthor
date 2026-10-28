#!/usr/bin/env bash
# Table tests for app-version.sh. Run: scripts/test-app-version.sh
set -uo pipefail

script="$(dirname "$0")/app-version.sh"
failures=0

# expect <want> <make VERSION value>   (want "" means: no usable version)
expect() {
  local got
  got="$("$script" "$2" 2>/dev/null)"
  if [[ "$got" != "$1" ]]; then
    echo "FAIL: expected '$1' from '$2'; got '$got'"
    failures=$((failures + 1))
  fi
}

expect "0.3.0" "v0.3.0"
expect "1.12.4" "v1.12.4"
expect "0.3.0" "0.3.0"
expect "0.3.0" "v0.3.0-5-gabc1234"
expect "0.3.0" "v0.3.0-5-gabc1234-dirty"
expect "" "abc1234"
expect "" "abc1234-dirty"
expect "" ""

((failures == 0)) && echo "app-version: all passed"
exit $((failures > 0))
