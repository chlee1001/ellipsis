#!/usr/bin/env bash
# Create the GitHub release for vX.Y.Z with the zip and the appcast.
# Usage: scripts/publish.sh X.Y.Z
# The tag must exist on GitHub, and build/Ellipsis-X.Y.Z.zip and
# build/appcast.xml must exist (release.sh writes them). Sparkle reads
# https://github.com/ronny/ellipsis/releases/latest/download/appcast.xml,
# which GitHub points at the newest release that is not a draft or
# pre-release, so the release is published, not a draft.
set -euo pipefail

version="${1:?usage: scripts/publish.sh X.Y.Z}"
root="$(cd "$(dirname "$0")/.." && pwd)"
tag="v$version"
zip="$root/build/Ellipsis-$version.zip"
appcast="$root/build/appcast.xml"

[[ -f "$zip" ]] || { echo "error: $zip does not exist. Run: scripts/release.sh $version" >&2; exit 1; }
[[ -f "$appcast" ]] || { echo "error: $appcast does not exist. Run: scripts/release.sh $version" >&2; exit 1; }
grep -q "Ellipsis-$version.zip" "$appcast" || { echo "error: $appcast is not for $version" >&2; exit 1; }

gh release create "$tag" --verify-tag --title "$tag" --generate-notes "$zip" "$appcast"
