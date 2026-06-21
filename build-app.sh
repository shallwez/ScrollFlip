#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
APP_NAME="ScrollFlip"
BUILD_DIR="$ROOT/.build/release"
APP_DIR="$ROOT/dist/滚动翻转.app"

cd "$ROOT"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
    <key>CFBundleDisplayName</key><string>滚动翻转</string>
    <key>CFBundleExecutable</key><string>ScrollFlip</string>
    <key>CFBundleIdentifier</key><string>com.shuaishuai.scrollflip</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>滚动翻转</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026</string>
</dict>
</plist>
PLIST

# Prefer the local Apple Development identity. Unlike an ad-hoc signature, this
# gives macOS a stable identity so Accessibility permission survives rebuilds.
SIGN_IDENTITY="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -n 1)"
if [[ -n "$SIGN_IDENTITY" ]]; then
    codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_DIR"
else
    codesign --force --deep --sign - "$APP_DIR"
fi
echo "已生成：$APP_DIR"
