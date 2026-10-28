#!/usr/bin/env bash
# Tests for check-architecture.sh on small fixture trees. Run: scripts/test-check-architecture.sh
set -uo pipefail

script="$(cd "$(dirname "$0")" && pwd)/check-architecture.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0

# fixture <name>: a clean tree whose code map names every file, in $tmp/<name>.
fixture() {
  local dir="$tmp/$1"
  mkdir -p "$dir/Sources/LuthorDomain" "$dir/Sources/LuthorStore" "$dir/Sources/LuthorViewModels" "$dir/App/Luthor"
  echo 'struct Event {}' >"$dir/Sources/LuthorDomain/Events.swift"
  printf 'import LuthorDomain\nimport Foundation\n' >"$dir/Sources/LuthorStore/Log.swift"
  printf 'import LuthorStore\n' >"$dir/Sources/LuthorViewModels/Model.swift"
  printf 'import SwiftUI\n' >"$dir/App/Luthor/TodayView.swift"
  cat >"$dir/AGENTS.md" <<'MAP'
### Code map

Events.swift Log.swift Model.swift TodayView

**Keep this map current.** Rest.
MAP
  echo "$dir"
}

# expect <pass|fail> <dir> <text the output must hold> <description>
expect() {
  local out status=0
  out="$("$script" "$2" 2>&1)" || status=$?
  if [[ "$1" == pass && $status -ne 0 ]] || [[ "$1" == fail && $status -eq 0 ]]; then
    echo "FAIL: $4 (exit $status)"
    echo "$out"
    failures=$((failures + 1))
  elif [[ -n "$3" && "$out" != *"$3"* ]]; then
    echo "FAIL: $4: output lacks '$3'"
    echo "$out"
    failures=$((failures + 1))
  fi
}

d="$(fixture clean)"
expect pass "$d" "all passed" "a clean tree passes"

d="$(fixture domain-import)"
echo 'import Foundation' >"$d/Sources/LuthorDomain/Events.swift"
expect fail "$d" "the domain imports nothing" "the domain imports Foundation"

d="$(fixture domain-clock)"
echo 'let now = Date()' >>"$d/Sources/LuthorDomain/Events.swift"
expect fail "$d" "reads no clock" "the domain reads the clock"

d="$(fixture domain-uuid)"
echo 'let id = UUID()' >>"$d/Sources/LuthorDomain/Events.swift"
expect fail "$d" "reads no clock" "the domain makes a UUID"

d="$(fixture domain-random)"
echo 'let n = Int.random(in: 0..<3)' >>"$d/Sources/LuthorDomain/Events.swift"
expect fail "$d" "reads no clock" "the domain uses randomness"

d="$(fixture domain-grdb)"
echo 'import GRDB' >>"$d/Sources/LuthorDomain/Events.swift"
expect fail "$d" "never imports GRDB" "the domain imports GRDB"

d="$(fixture store-swiftui)"
echo 'import SwiftUI' >>"$d/Sources/LuthorStore/Log.swift"
expect fail "$d" "App/ only" "the store imports SwiftUI"

d="$(fixture viewmodels-swiftui)"
echo 'import AppKit' >>"$d/Sources/LuthorViewModels/Model.swift"
expect fail "$d" "App/ only" "a view model imports AppKit"

d="$(fixture store-viewmodels)"
echo 'import LuthorViewModels' >>"$d/Sources/LuthorStore/Log.swift"
expect fail "$d" "never depends on view models" "the store imports view models"

d="$(fixture unmapped-source)"
echo 'struct Extra {}' >"$d/Sources/LuthorDomain/Extra.swift"
expect fail "$d" "Extra.swift is not in the AGENTS.md code map" "a source file is missing from the map"

d="$(fixture unmapped-view)"
echo 'struct V {}' >"$d/App/Luthor/NewView.swift"
expect fail "$d" "NewView.swift is not in the AGENTS.md code map" "an app file is missing from the map"

d="$(fixture stale-map)"
# Not `sed -i`: its argument differs between macOS and Linux.
sed 's/^Events.swift/Events.swift Gone.swift/' "$d/AGENTS.md" >"$d/AGENTS.new" && mv "$d/AGENTS.new" "$d/AGENTS.md"
expect fail "$d" "names Gone.swift, which does not exist" "the map names a file that is gone"

((failures == 0)) && echo "check-architecture: all passed"
exit $((failures > 0))
