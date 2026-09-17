#!/usr/bin/env bash
# Sign build/Ellipsis.app with a Developer ID and the hardened runtime.
# Usage: scripts/sign.sh [path/to/Ellipsis.app]
# DEVELOPER_ID names the identity. Default: the first "Developer ID
# Application" identity in the keychain.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="${1:-$root/build/Ellipsis.app}"

identity="${DEVELOPER_ID:-}"
if [[ -z "$identity" ]]; then
  identity="$(security find-identity -v -p codesigning |
    sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)"
fi
if [[ -z "$identity" ]]; then
  echo "No Developer ID Application identity in the keychain. Set DEVELOPER_ID." >&2
  exit 1
fi
# `security find-identity -v` lists a revoked certificate as valid and only
# marks it in the text. Gatekeeper treats an app signed with one as malware.
if security find-identity -v -p codesigning | grep -F "$identity" | grep -q CSSMERR_TP_CERT_REVOKED; then
  echo "The certificate '$identity' is revoked. Remove it from the keychain." >&2
  exit 1
fi

echo "Signing with $identity" >&2
"$root/scripts/sign-sparkle.sh" "$app" "$identity"
codesign --force --options runtime --timestamp \
  --entitlements "$root/Resources/Ellipsis.entitlements" \
  --sign "$identity" "$app"
codesign --verify --strict --verbose=2 "$app"
