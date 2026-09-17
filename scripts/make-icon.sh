#!/usr/bin/env bash
# Build Resources/AppIcon.icns from Resources/AppIcon.png (1024x1024) with iconutil.
# Draw the PNG first with scripts/make-icon-art.swift if it is missing.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
png="$root/Resources/AppIcon.png"
icns="$root/Resources/AppIcon.icns"

if [[ ! -f "$png" ]]; then
  mkdir -p "$root/build"
  swiftc -O -o "$root/build/iconrender" "$root/scripts/make-icon-art.swift"
  "$root/build/iconrender" "$png"
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
iconset="$work/AppIcon.iconset"
mkdir -p "$iconset"

for spec in 16:1 16:2 32:1 32:2 128:1 128:2 256:1 256:2 512:1 512:2; do
  points="${spec%%:*}"
  scale="${spec##*:}"
  pixels=$((points * scale))
  name="icon_${points}x${points}.png"
  [[ "$scale" == 1 ]] || name="icon_${points}x${points}@${scale}x.png"
  sips -z "$pixels" "$pixels" "$png" --out "$iconset/$name" >/dev/null
done

iconutil --convert icns --output "$icns" "$iconset"
echo "$icns"
