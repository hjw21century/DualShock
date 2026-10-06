#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
iconset="dist/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" Resources/Artwork/AppIcon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
  retina=$((size * 2))
  sips -z "$retina" "$retina" Resources/Artwork/AppIcon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil --convert icns "$iconset" --output dist/AppIcon.icns
cp "$iconset/icon_512x512@2x.png" dist/AppIcon-1024.png
test -s dist/AppIcon.icns
echo "已生成：dist/AppIcon.icns 和 dist/AppIcon-1024.png"
