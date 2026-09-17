#!/usr/bin/env bash
# Assemble build/Ellipsis.app from the SwiftPM binary and sign it ad hoc.
# Usage: scripts/bundle.sh [debug|release]   (default: debug)
# VERSION and BUILD override CFBundleShortVersionString and CFBundleVersion.
set -euo pipefail

config="${1:-debug}"
root="$(cd "$(dirname "$0")/.." && pwd)"
bin="$(swift build -c "$config" --package-path "$root" --show-bin-path)/Ellipsis"
app="$root/build/Ellipsis.app"

swift build -c "$config" --package-path "$root" >&2

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/Ellipsis"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"
cp "$root/Resources/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
echo -n "APPL????" > "$app/Contents/PkgInfo"

plist="$app/Contents/Info.plist"
[[ -z "${VERSION:-}" ]] || plutil -replace CFBundleShortVersionString -string "$VERSION" "$plist"
[[ -z "${BUILD:-}" ]] || plutil -replace CFBundleVersion -string "$BUILD" "$plist"

codesign --force --sign - --identifier au.ronny.Ellipsis "$app"
echo "$app"
