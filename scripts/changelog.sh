#!/usr/bin/env sh
# CHANGELOG.md is curated by hand (Keep a Changelog style) and is the source of
# truth for release notes. This helper is used locally and by CI:
#
#   scripts/changelog.sh verify <version>   the section "## [<version>] - YYYY-MM-DD"
#                                           exists, is dated and is not empty
#   scripts/changelog.sh notes  <version>   print that section's body (release notes)
#
# <version> may carry a leading "v" (e.g. $CI_COMMIT_TAG).
set -eu

usage() { echo "usage: $0 verify|notes <version>" >&2; exit 2; }
[ $# -eq 2 ] || usage
cmd=$1
version=${2#v}
file=${CHANGELOG:-CHANGELOG.md}
label=${CHANGELOG_LABEL:-$file}
[ -f "$file" ] || { echo "error: $file not found" >&2; exit 1; }

# Body of the "## [<version>]" section, up to the next "## [" heading.
section() {
  awk -v v="$version" '
    index($0, "## [" v "]") == 1 { found = 1; next }
    found && /^## \[/ { exit }
    found { print }
  ' "$file"
}

heading=$(grep -m1 -F "## [$version]" "$file" || true)

case $cmd in
  verify)
    if [ -z "$heading" ]; then
      echo "error: $file has no \"## [$version]\" section. Add one before tagging v$version." >&2
      exit 1
    fi
    if ! printf '%s\n' "$heading" | grep -Eq "^## \[$version\] - [0-9]{4}-[0-9]{2}-[0-9]{2}( |\$)"; then
      echo "error: the $version section is not dated (\"$heading\")." >&2
      echo "       Replace \"Unreleased\" with the release date, e.g. \"## [$version] - $(date +%Y-%m-%d)\"." >&2
      exit 1
    fi
    if ! section | grep -q '[^[:space:]]'; then
      echo "error: the $version section of $file is empty." >&2
      exit 1
    fi
    echo "$label: $heading"
    ;;
  notes)
    [ -n "$heading" ] || { echo "error: no \"## [$version]\" section in $file" >&2; exit 1; }
    section | sed -e '/./,$!d'   # drop leading blank lines
    ;;
  *) usage ;;
esac
