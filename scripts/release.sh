#!/usr/bin/env bash
# Build, sign, notarize and zip a release.
# Usage: scripts/release.sh X.Y.Z
# Writes build/Ellipsis-X.Y.Z.zip. See sign.sh and notarize.sh for the
# DEVELOPER_ID and NOTARY_PROFILE variables.
set -euo pipefail

version="${1:?usage: scripts/release.sh X.Y.Z}"
root="$(cd "$(dirname "$0")/.." && pwd)"

# The number of commits, so every release gets a larger CFBundleVersion.
build="$(jj log -R "$root" -r '::@' --no-graph -T '"."' | wc -c | tr -d ' ')"

app="$(VERSION="$version" BUILD="$build" "$root/scripts/bundle.sh" release)"
"$root/scripts/sign.sh" "$app"
"$root/scripts/notarize.sh" "$app"

zip="$root/build/Ellipsis-$version.zip"
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
echo "$zip"
