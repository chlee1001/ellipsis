#!/usr/bin/env bash
# Assemble the app bundle from the SwiftPM binary and sign it ad hoc.
# A debug build is build/EllipsisDev.app with the identifier
# au.ronny.EllipsisDev, so it sits next to the release app in /Applications
# and in the Accessibility list, with its own settings. A release build is
# build/Ellipsis.app with au.ronny.Ellipsis.
# Usage: scripts/bundle.sh [debug|release]   (default: debug)
# VERSION and BUILD override CFBundleShortVersionString and CFBundleVersion.
set -euo pipefail

config="${1:-debug}"
root="$(cd "$(dirname "$0")/.." && pwd)"
bin="$(swift build -c "$config" --package-path "$root" --show-bin-path)/Ellipsis"

name="Ellipsis"
[[ "$config" == "release" ]] || name="EllipsisDev"
identifier="au.ronny.$name"
app="$root/build/$name.app"

swift build -c "$config" --package-path "$root" >&2

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/$name"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"
cp "$root/Resources/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
echo -n "APPL????" > "$app/Contents/PkgInfo"

plist="$app/Contents/Info.plist"
plutil -replace CFBundleExecutable -string "$name" "$plist"
plutil -replace CFBundleName -string "$name" "$plist"
plutil -replace CFBundleIdentifier -string "$identifier" "$plist"
[[ -z "${VERSION:-}" ]] || plutil -replace CFBundleShortVersionString -string "$VERSION" "$plist"
[[ -z "${BUILD:-}" ]] || plutil -replace CFBundleVersion -string "$BUILD" "$plist"

codesign --force --sign - --identifier "$identifier" "$app"
echo "$app"
