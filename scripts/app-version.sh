#!/usr/bin/env bash
# The marketing version for the app (CFBundleShortVersionString) from a `git describe` style version:
#
#   app-version.sh v0.3.0-5-gabc1234   # prints 0.3.0
#
# Prints nothing when there is no x.y.z in it (a build from a repo with no tag), so the project's own
# version stays.
set -euo pipefail

if [[ "${1:-}" =~ ^v?([0-9]+\.[0-9]+\.[0-9]+) ]]; then
  echo "${BASH_REMATCH[1]}"
fi
