#!/usr/bin/env bash
# Prints an `llvm-cov report` of line coverage for the package's Sources/, from the data that
# `swift test --enable-code-coverage` left behind. Tests/ and dependencies are not measured.
# Works with Xcode's toolchain on macOS and a swift.org toolchain on Linux.
#
#   coverage-report.sh
set -euo pipefail

if command -v xcrun >/dev/null 2>&1; then
  llvm_cov=(xcrun llvm-cov)
else
  llvm_cov=(llvm-cov)
fi

bin_path="$(swift build --show-bin-path)"
profdata="$(dirname "$(swift test --show-codecov-path)")/default.profdata"
bundle="$bin_path/LuthorPackageTests.xctest"
if [[ -d "$bundle/Contents/MacOS" ]]; then
  binary="$bundle/Contents/MacOS/LuthorPackageTests"
else
  binary="$bundle"
fi

for f in "$profdata" "$binary"; do
  if [[ ! -e "$f" ]]; then
    echo "no coverage data at $f: run 'swift test --enable-code-coverage' first" >&2
    exit 1
  fi
done

"${llvm_cov[@]}" report "$binary" -instr-profile="$profdata" \
  -show-region-summary=false -show-branch-summary=false \
  "$PWD/Sources"
