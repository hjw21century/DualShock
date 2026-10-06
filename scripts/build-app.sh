#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo "请在安装 Xcode Command Line Tools 的 macOS 14 或更新系统运行。" >&2
  exit 1
fi
export MACOSX_DEPLOYMENT_TARGET=14.0
bash scripts/build-icon.sh
swift build -c release --arch arm64 --arch x86_64
bin_dir="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
app_dir="dist/DualShock.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/DualShock" "$app_dir/Contents/MacOS/DualShock"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp dist/AppIcon.icns "$app_dir/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" dist/DualShock-macOS-universal.zip
echo "已构建：dist/DualShock.app 和 dist/DualShock-macOS-universal.zip"
