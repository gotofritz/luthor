#!/usr/bin/env bash
# Table tests for check-coverage.sh. Run: scripts/test-check-coverage.sh
set -uo pipefail

script="$(dirname "$0")/check-coverage.sh"
failures=0
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# A report shaped like `llvm-cov report` with the region and branch columns turned off.
report() {
  local lines="$1" missed="$2"
  cat <<REPORT
Filename                      Functions  Missed Functions  Executed       Lines      Missed Lines     Cover
-----------------------------------------------------------------------------------------------------------
LuthorDomain/Commands.swift          13                 0   100.00%          37                 0   100.00%
-----------------------------------------------------------------------------------------------------------
TOTAL                                96                 2    97.92%       $lines             $missed    96.05%
REPORT
}

expect() {
  local want="$1" min="$2" lines="$3" missed="$4"
  report "$lines" "$missed" >"$tmp"
  if "$script" "$min" "$tmp" >/dev/null 2>&1; then got=pass; else got=fail; fi
  if [[ "$got" != "$want" ]]; then
    echo "FAIL: expected $want for min $min, $missed of $lines lines missed, got $got"
    failures=$((failures + 1))
  fi
}

expect pass 90 430 17   # 96.05%
expect pass 90 100 10   # exactly 90%
expect fail 90 1000 101 # 89.9%, never rounded up
expect fail 90 100 50
expect pass 0 100 100
expect fail 90 0 0     # no lines measured means the report is wrong

# A report without a TOTAL line is an error, not a pass.
printf 'error: no coverage data\n' >"$tmp"
if "$script" 90 "$tmp" >/dev/null 2>&1; then
  echo "FAIL: expected fail for a report without totals"
  failures=$((failures + 1))
fi
# A missing report is an error.
if "$script" 90 "$tmp.missing" >/dev/null 2>&1; then
  echo "FAIL: expected fail for a missing report"
  failures=$((failures + 1))
fi

if ((failures > 0)); then
  echo "$failures check(s) failed"
  exit 1
fi
echo "check-coverage: all checks passed"
