#!/usr/bin/env bash
# Sign the nested code in Sparkle.framework, innermost first. codesign does
# not descend into a framework's XPC services and helper app, and notarization
# rejects them with the upstream signature.
# Usage: scripts/sign-sparkle.sh path/to/App.app identity
set -euo pipefail

app="${1:?usage: scripts/sign-sparkle.sh path/to/App.app identity}"
identity="${2:?usage: scripts/sign-sparkle.sh path/to/App.app identity}"
framework="$app/Contents/Frameworks/Sparkle.framework"

sign() {
  codesign --force --options runtime --timestamp --sign "$identity" "$@"
}
sign --preserve-metadata=entitlements "$framework/Versions/B/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$framework/Versions/B/XPCServices/Downloader.xpc"
sign "$framework/Versions/B/Autoupdate"
sign "$framework/Versions/B/Updater.app"
sign "$framework"
