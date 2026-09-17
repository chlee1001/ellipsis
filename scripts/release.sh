#!/usr/bin/env bash
# Build, sign, notarize and zip a release, and write its Sparkle appcast.
# Usage: scripts/release.sh X.Y.Z
# Writes build/Ellipsis-X.Y.Z.zip and build/appcast.xml. See sign.sh and
# notarize.sh for the DEVELOPER_ID and NOTARY_PROFILE variables. The appcast
# is signed with the EdDSA key in the login keychain (see docs/development.md)
# and points at the GitHub release for the tag vX.Y.Z.
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

# generate_appcast lists every archive in a directory, so the zip goes in an
# empty one and the appcast has one item: this release.
sparkle="$root/.build/artifacts/sparkle/Sparkle/bin"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp "$zip" "$work/"
"$sparkle/generate_appcast" \
  --download-url-prefix "https://github.com/ronny/ellipsis/releases/download/v$version/" \
  --link "https://github.com/ronny/ellipsis/releases" \
  -o "$root/build/appcast.xml" "$work"
echo "$zip"
echo "$root/build/appcast.xml"
