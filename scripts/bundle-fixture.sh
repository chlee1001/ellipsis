#!/usr/bin/env bash
# Bundle the fixture app for the VM tests as build/FixtureN.app with the
# identifier au.ronny.EllipsisFixture.N. The status item's title is FixtureN.
# Usage: scripts/bundle-fixture.sh N   (N is one letter or word, e.g. A)
set -euo pipefail

suffix="${1:?usage: bundle-fixture.sh N}"
root="$(cd "$(dirname "$0")/.." && pwd)"
bin="$(swift build --package-path "$root" --product Fixture --show-bin-path)/Fixture"
name="Fixture$suffix"
identifier="au.ronny.EllipsisFixture.$suffix"
app="$root/build/$name.app"

swift build --package-path "$root" --product Fixture >&2

rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin" "$app/Contents/MacOS/$name"
cp "$root/Resources/Fixture-Info.plist" "$app/Contents/Info.plist"
echo -n "APPL????" > "$app/Contents/PkgInfo"
plist="$app/Contents/Info.plist"
plutil -replace CFBundleExecutable -string "$name" "$plist"
plutil -replace CFBundleName -string "$name" "$plist"
plutil -replace CFBundleIdentifier -string "$identifier" "$plist"
codesign --force --sign - --identifier "$identifier" "$app"
echo "$app"
