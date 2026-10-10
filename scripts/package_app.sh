#!/bin/bash
# 把 SwiftPM 可执行文件打包成标准 .app(zip 分发),供 CI 与本地使用。
# 用法: ./scripts/package_app.sh <version>  例如 ./scripts/package_app.sh 0.1.0
set -euo pipefail

VERSION="${1:?usage: package_app.sh <version>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> swift build -c release"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="dist/MoleApp.app"

rm -rf dist
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_DIR/MoleApp" "$APP_DIR/Contents/MacOS/MoleApp"

cat > "$APP_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>zh_CN</string>
	<key>CFBundleExecutable</key>
	<string>MoleApp</string>
	<key>CFBundleIdentifier</key>
	<string>com.csic21.moleapp</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>MoleApp</string>
	<key>CFBundleDisplayName</key>
	<string>Mole 研究版</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>${VERSION}</string>
	<key>CFBundleVersion</key>
	<string>${VERSION}</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.utilities</string>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
PLIST

echo "==> codesign (ad-hoc)"
codesign --force --deep --sign - "$APP_DIR"

echo "==> zip"
(cd dist && zip -qry "MoleApp-${VERSION}.zip" "MoleApp.app")

echo "==> done: dist/MoleApp-${VERSION}.zip"
ls -lh "dist/MoleApp-${VERSION}.zip"
