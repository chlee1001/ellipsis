#!/usr/bin/env bash
# Bundle, install to /Applications, and launch.
# MenuBarAgent matches the allow-list only against apps in /Applications, so
# a build run from anywhere else hides its own icon. See docs/phase0.md.
# Usage: scripts/run.sh [debug|release]   (default: debug)
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$("$root/scripts/bundle.sh" "${1:-debug}")"
target="/Applications/Ellipsis.app"

pkill -x Ellipsis || true
rm -rf "$target"
ditto "$app" "$target"
open "$target"
