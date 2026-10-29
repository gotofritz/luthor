#!/usr/bin/env bash
# Fails unless the argument is a release tag, vX.Y.Z: the release workflow checks a version before it
# builds, signs or publishes anything under that name.
#
#   check-version-tag.sh v0.3.0
set -euo pipefail

# A newline would pass a line-by-line match, so the whole value is matched.
if [[ ! "${1:-}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "${1}" == *$'\n'* ]]; then
  echo "not a release tag (want vX.Y.Z): '${1:-}'" >&2
  exit 1
fi
