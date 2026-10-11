#!/bin/bash
# 从透明背景的品牌母版生成原生与网页图标。需要 macOS 的 sips / iconutil。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/Assets/Branding/QiliLogo.png"
RESOURCES="$ROOT/Sources/MoleApp/Resources"
ICON_WORK="$(mktemp -d)"
trap 'rm -rf "$ICON_WORK"' EXIT
ICONSET="$ICON_WORK/AppIcon.iconset"
mkdir -p "$ICONSET" "$RESOURCES" "$ROOT/site/public"

for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" "$SOURCE" --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    RETINA=$((SIZE * 2))
    sips -z "$RETINA" "$RETINA" "$SOURCE" --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"
sips -z 128 128 "$SOURCE" --out "$RESOURCES/QiliLogo.png" >/dev/null
cp "$RESOURCES/QiliLogo.png" "$ROOT/site/public/qili-logo.png"
sips -z 64 64 "$SOURCE" --out "$ROOT/site/public/favicon.png" >/dev/null
