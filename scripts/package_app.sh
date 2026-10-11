#!/bin/bash
# 把 SwiftPM 可执行文件打包成标准 .app(zip 分发),供 CI 与本地使用。
# 用法: ./scripts/package_app.sh <version> [output-directory]
set -euo pipefail

VERSION="${1:?usage: package_app.sh <version>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> swift build -c release"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
DIST_DIR="${2:-dist}"
APP_DIR="$DIST_DIR/Qili.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_DIR/MoleApp" "$APP_DIR/Contents/MacOS/MoleApp"
cp -R "$BIN_DIR/MoleApp_MoleApp.bundle" "$APP_DIR/Contents/Resources/"
cp "Sources/MoleApp/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

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
	<string>Qili</string>
	<key>CFBundleDisplayName</key>
	<string>栖理</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
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
(cd "$DIST_DIR" && rm -f "Qili-${VERSION}.zip" && zip -qry "Qili-${VERSION}.zip" "Qili.app")

echo "==> done: $DIST_DIR/Qili-${VERSION}.zip"
ls -lh "$DIST_DIR/Qili-${VERSION}.zip"
