#!/bin/bash
# 把 SwiftPM 可执行文件打包成标准 .app(内嵌 Sparkle 自动更新),并生成 DMG。
# DMG 既用于首次安装(拖入 Applications),也是 Sparkle 的更新包。
# 用法: ./scripts/package_app.sh <version> [output-directory]
# 可选环境变量:
#   SPARKLE_FEED_URL       覆盖更新源(默认本仓库 releases/latest 的 appcast.xml)
#   SPARKLE_PUBLIC_ED_KEY  覆盖 EdDSA 公钥(默认使用下面内嵌的常量)
set -euo pipefail

VERSION="${1:?usage: package_app.sh <version>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Sparkle 更新源与 EdDSA 公钥。公钥可以公开;私钥只存在于维护者钥匙串与 GitHub Secret。
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://github.com/csic21/qili/releases/latest/download/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-SpAtOrj49qX9ORjeZ1ZZayiyFy/7uT0e3JPvto0eTjc=}"

echo "==> swift build -c release"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
DIST_DIR="${2:-dist}"
APP_DIR="$DIST_DIR/Qili.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$APP_DIR/Contents/Frameworks"

cp "$BIN_DIR/MoleApp" "$APP_DIR/Contents/MacOS/MoleApp"
cp -R "$BIN_DIR/MoleApp_MoleApp.bundle" "$APP_DIR/Contents/Resources/"
cp "Sources/MoleApp/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

echo "==> embed Sparkle.framework"
SPARKLE_FRAMEWORK="$(find .build/artifacts -type d -name Sparkle.framework -print -quit 2>/dev/null || true)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
    SPARKLE_FRAMEWORK="$(find .build -type d -name Sparkle.framework -print -quit)"
fi
[[ -n "$SPARKLE_FRAMEWORK" ]] || { echo "Sparkle.framework not found; run swift build first" >&2; exit 1; }
# ditto 保留符号链接与可执行权限,否则框架签名会失效。
ditto "$SPARKLE_FRAMEWORK" "$APP_DIR/Contents/Frameworks/Sparkle.framework"

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
	<key>SUFeedURL</key>
	<string>${SPARKLE_FEED_URL}</string>
	<key>SUPublicEDKey</key>
	<string>${SPARKLE_PUBLIC_ED_KEY}</string>
	<key>SUEnableAutomaticChecks</key>
	<true/>
</dict>
</plist>
PLIST

echo "==> codesign (ad-hoc; Sparkle 嵌套组件由内到外)"
FW="$APP_DIR/Contents/Frameworks/Sparkle.framework"
for nested in \
    "$FW/Versions/B/XPCServices/Downloader.xpc" \
    "$FW/Versions/B/XPCServices/Installer.xpc" \
    "$FW/Versions/B/Autoupdate" \
    "$FW/Versions/B/Updater.app"; do
    if [[ -e "$nested" ]]; then
        codesign --force --sign - "$nested"
    fi
done
codesign --force --sign - "$FW"
codesign --force --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "==> dmg"
STAGE="$DIST_DIR/.dmg-staging"
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$APP_DIR" "$STAGE/Qili.app"
ln -s /Applications "$STAGE/Applications"
DMG="$DIST_DIR/Qili-${VERSION}.dmg"
rm -f "$DMG"
hdiutil create -quiet -volname "Qili" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

echo "==> done: $DMG"
ls -lh "$DMG"
