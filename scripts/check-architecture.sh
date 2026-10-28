#!/usr/bin/env bash
# Checks the architecture rules of AGENTS.md that agents break silently, and that the Code map there
# matches the tree. Run from the project root: scripts/check-architecture.sh [root]
# `root` (default: the current directory) holds Sources/, App/ and AGENTS.md; the tests pass a fixture.
set -uo pipefail

root="${1:-.}"
cd "$root" || exit 2
failures=0

fail() {
  echo "architecture: $*"
  failures=$((failures + 1))
}

# forbid <dir> <regex> <why>: no line of a .swift file under <dir> may match <regex>.
forbid() {
  local dir="$1" pattern="$2" why="$3" hits
  [[ -d "$dir" ]] || return 0
  hits="$(grep -rnE --include='*.swift' -- "$pattern" "$dir" || true)"
  if [[ -n "$hits" ]]; then
    while IFS= read -r line; do fail "$line: $why"; done <<<"$hits"
  fi
}

ui='^[[:space:]]*(@_exported[[:space:]]+)?import[[:space:]]+(SwiftUI|AppKit|UIKit)\b'
db='^[[:space:]]*(@_exported[[:space:]]+)?import[[:space:]]+(GRDB|SwiftyDropbox|Dropbox)'

# The domain is pure Swift and imports nothing.
forbid Sources/LuthorDomain '^[[:space:]]*(@_exported[[:space:]]+)?(public[[:space:]]+|internal[[:space:]]+)?import[[:space:]]' \
  "the domain imports nothing"
# Reducers and commands are deterministic: clocks, IDs and randomness are injected.
forbid Sources/LuthorDomain '\b(Date\(\)|Date\.now|UUID\(\)|Calendar\.current|TimeZone\.current|ProcessInfo|FileManager|URLSession)|\.random\(|SystemRandomNumberGenerator' \
  "the domain does no I/O and reads no clock, ID or randomness"
# Layers point inwards: no SwiftUI in the package, no database or Dropbox code outside the store and sync.
forbid Sources "$ui" "SwiftUI and AppKit belong in App/ only"
forbid Sources/LuthorDomain "$db" "the domain never imports GRDB or Dropbox code"
forbid Sources/LuthorViewModels "$db" "view models never import GRDB or Dropbox code"
forbid Sources '^[[:space:]]*import[[:space:]]+Luthor(App)?[[:space:]]*$' "the package never depends on the app"
forbid Sources/LuthorStore '^[[:space:]]*import[[:space:]]+LuthorViewModels\b' "the store never depends on view models"
forbid Sources/LuthorDomain '^[[:space:]]*import[[:space:]]+Luthor' "the domain never depends on another module"

# Code map: every source file is named in it, and every file it names exists.
if [[ -f AGENTS.md ]]; then
  map="$(awk '/^### Code map/{on=1; next} /^\*\*Keep this map current/{on=0} on' AGENTS.md)"
  while IFS= read -r file; do
    name="$(basename "$file")"
    case "$file" in
      Sources/*) grep -qF -- "$name" <<<"$map" || fail "$file is not in the AGENTS.md code map" ;;
      # The app's views are listed by name, without the extension.
      *) grep -qwF -- "${name%.swift}" <<<"$map" || fail "$file is not in the AGENTS.md code map" ;;
    esac
  done < <(find Sources App -name '*.swift' 2>/dev/null | sort)
  while IFS= read -r name; do
    [[ -n "$(find . -name "$name" -not -path "./.build/*" 2>/dev/null | head -1)" ]] \
      || fail "the AGENTS.md code map names $name, which does not exist"
  done < <(grep -oE '[A-Za-z0-9+]+\.swift' <<<"$map" | sort -u)
else
  fail "AGENTS.md not found"
fi

((failures == 0)) && echo "architecture: all passed"
exit $((failures > 0))
