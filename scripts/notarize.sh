#!/usr/bin/env bash
# Notarize a signed build/Ellipsis.app and staple the ticket.
# Usage: scripts/notarize.sh [path/to/Ellipsis.app]
# NOTARY_PROFILE names a notarytool keychain profile (default: ellipsis).
# Create it once:
#   xcrun notarytool store-credentials ellipsis \
#     --apple-id you@example.com --team-id TEAMID --password app-specific-password
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="${1:-$root/build/Ellipsis.app}"
profile="${NOTARY_PROFILE:-ellipsis}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
ditto -c -k --keepParent "$app" "$work/Ellipsis.zip"

xcrun notarytool submit "$work/Ellipsis.zip" --keychain-profile "$profile" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type exec --verbose=2 "$app"
