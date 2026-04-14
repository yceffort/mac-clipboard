#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="yceffort Clipboard"
APP_BUNDLE_PATH="$ROOT_DIR/dist/$APP_NAME.app"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/version.txt")"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
APP_ARCHIVE_PATH="$ROOT_DIR/dist/$APP_NAME-$VERSION.zip"
APP_DMG_PATH="$ROOT_DIR/dist/$APP_NAME-$VERSION.dmg"
DMG_STAGING_PATH="$ROOT_DIR/dist/.dmg-root"
ICONSET_PATH="$ROOT_DIR/.build/AppIcon.iconset"
APP_ICON_PATH="$ROOT_DIR/.build/AppIcon.icns"

if [[ -z "$VERSION" ]]; then
  echo "version.txt is missing a version value." >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/dist"

/usr/bin/swift "$ROOT_DIR/scripts/generate_app_icon.swift" "$ICONSET_PATH"
/usr/bin/iconutil -c icns "$ICONSET_PATH" -o "$APP_ICON_PATH"
rm -rf "$ICONSET_PATH"
"$ROOT_DIR/scripts/build.sh" release

BINARY_PATH="$(find "$ROOT_DIR/.build" -path '*release/MacClipboard' -type f | head -n 1)"

if [[ -z "$BINARY_PATH" ]]; then
  echo "Release binary not found."
  exit 1
fi

rm -rf "$APP_BUNDLE_PATH"
mkdir -p "$APP_BUNDLE_PATH/Contents/MacOS" "$APP_BUNDLE_PATH/Contents/Resources"

cp "$BINARY_PATH" "$APP_BUNDLE_PATH/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE_PATH/Contents/MacOS/$APP_NAME"
cp "$APP_ICON_PATH" "$APP_BUNDLE_PATH/Contents/Resources/AppIcon.icns"

cat > "$APP_BUNDLE_PATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.yceffort.clipboard</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon.icns</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

echo "Packaged app at: $APP_BUNDLE_PATH"

rm -f "$APP_ARCHIVE_PATH"
/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE_PATH" "$APP_ARCHIVE_PATH"

echo "Packaged archive at: $APP_ARCHIVE_PATH"

rm -rf "$DMG_STAGING_PATH"
mkdir -p "$DMG_STAGING_PATH"
cp -R "$APP_BUNDLE_PATH" "$DMG_STAGING_PATH/"
ln -s /Applications "$DMG_STAGING_PATH/Applications"

rm -f "$APP_DMG_PATH"
/usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING_PATH" \
  -ov \
  -format UDZO \
  "$APP_DMG_PATH"

rm -rf "$DMG_STAGING_PATH"

echo "Packaged disk image at: $APP_DMG_PATH"
