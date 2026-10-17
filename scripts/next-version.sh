#!/usr/bin/env bash
# Works out the next release tag from the Conventional Commit subjects since the last one.
#
#   git log --format=%s <last-tag>..HEAD | next-version.sh [<last-tag>]
#
# feat bumps the minor version, fix and perf the patch, and a "!" after any type is a breaking change,
# which bumps the major version (while it is 0, the minor version instead, so 1.0.0 is a decision and not
# a side effect). Other types do not release. Prints the tag, e.g. v0.2.0, or nothing if no commit
# releases. Without a last tag the first release is v0.1.0.
set -euo pipefail

current="${1:-}"
pattern='^([a-z]+)(\([a-z0-9._/-]+\))?(!)?: [^ ]'

# 0 none, 1 patch, 2 minor, 3 major
level=0
while IFS= read -r subject || [[ -n "$subject" ]]; do
  [[ "$subject" =~ $pattern ]] || continue
  type="${BASH_REMATCH[1]}"
  if [[ -n "${BASH_REMATCH[3]}" ]]; then
    this=3
  else
    case "$type" in
      feat) this=2 ;;
      fix | perf) this=1 ;;
      *) this=0 ;;
    esac
  fi
  ((this > level)) && level=$this
done

((level > 0)) || exit 0

if [[ -z "$current" ]]; then
  echo "v0.1.0"
  exit 0
fi

if [[ ! "$current" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "not a version: '$current'" >&2
  exit 65
fi
major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"

if ((level == 3 && major == 0)); then
  level=2
fi
case "$level" in
  3) major=$((major + 1)) minor=0 patch=0 ;;
  2) minor=$((minor + 1)) patch=0 ;;
  1) patch=$((patch + 1)) ;;
esac
echo "v$major.$minor.$patch"
