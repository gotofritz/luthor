#!/usr/bin/env bash
# Fails when line coverage in an `llvm-cov report` is below a minimum percentage.
# Reads the TOTAL row's Lines and Missed Lines columns, so the report must be made with
# -show-region-summary=false -show-branch-summary=false, as scripts/coverage-report.sh does.
#
#   check-coverage.sh <min-percent> <report-file>
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <min-percent> <report-file>" >&2
  exit 64
fi
min="$1"
report="$2"

# TOTAL  functions  missed  executed%  lines  missed-lines  cover%
totals="$(awk '$1 == "TOTAL" { print $5, $6 }' "$report")"
if [[ -z "$totals" ]]; then
  echo "no TOTAL row in coverage report $report" >&2
  exit 1
fi
read -r lines missed <<<"$totals"
if ((lines == 0)); then
  echo "coverage report $report measured no lines" >&2
  exit 1
fi
covered=$((lines - missed))

# Integer arithmetic, so 89.99% never rounds up to pass: covered / lines >= min / 100.
percent="$(awk -v c="$covered" -v l="$lines" 'BEGIN { printf "%.2f", 100 * c / l }')"
if ((covered * 100 < min * lines)); then
  echo "line coverage ${percent}% ($covered of $lines lines) is below the ${min}% minimum" >&2
  exit 1
fi
echo "line coverage ${percent}% ($covered of $lines lines), minimum ${min}%"
