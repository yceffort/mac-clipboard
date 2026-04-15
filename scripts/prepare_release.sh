#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?Usage: prepare_release.sh <version> [build-number]}"
BUILD_NUMBER="${2:-1}"
APP_NAME="yc.clipboard"
APP_PATH="$ROOT_DIR/dist/$APP_NAME.app"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$APP_NAME"
DMG_PATH="$ROOT_DIR/dist/$APP_NAME-$VERSION.dmg"
ZIP_PATH="$ROOT_DIR/dist/$APP_NAME-$VERSION.zip"
DMG_STAGING_PATH="$ROOT_DIR/dist/.signed-dmg-root"
KEYCHAIN_PATH="$ROOT_DIR/.build/signing.keychain-db"
CERTIFICATE_PATH="$ROOT_DIR/.build/developer-id.p12"
NOTARY_KEY_PATH="$ROOT_DIR/.build/AuthKey_${APPLE_NOTARY_KEY_ID:-missing}.p8"

printf '%s\n' "$VERSION" > "$ROOT_DIR/version.txt"

BUILD_NUMBER="$BUILD_NUMBER" "$ROOT_DIR/scripts/package_app.sh"

if [[ -n "${APPLE_SIGNING_IDENTITY:-}" ]]; then
  if [[ -n "${APPLE_DEVELOPER_ID_CERT_BASE64:-}" && -n "${APPLE_DEVELOPER_ID_CERT_PASSWORD:-}" ]]; then
    : "${APPLE_KEYCHAIN_PASSWORD:=temporary-signing-password}"

    mkdir -p "$ROOT_DIR/.build"
    echo "$APPLE_DEVELOPER_ID_CERT_BASE64" | base64 --decode > "$CERTIFICATE_PATH"

    security create-keychain -p "$APPLE_KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" 2>/dev/null || true
    security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
    security unlock-keychain -p "$APPLE_KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
    security import "$CERTIFICATE_PATH" \
      -k "$KEYCHAIN_PATH" \
      -P "$APPLE_DEVELOPER_ID_CERT_PASSWORD" \
      -T /usr/bin/codesign \
      -T /usr/bin/security
    security set-key-partition-list -S apple-tool:,apple: -s -k "$APPLE_KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
    security list-keychains -d user -s "$KEYCHAIN_PATH" login.keychain-db
  fi

  /usr/bin/codesign \
    --force \
    --keychain "$KEYCHAIN_PATH" \
    --timestamp \
    --options runtime \
    --sign "$APPLE_SIGNING_IDENTITY" \
    "$EXECUTABLE_PATH"

  /usr/bin/codesign \
    --force \
    --keychain "$KEYCHAIN_PATH" \
    --timestamp \
    --options runtime \
    --sign "$APPLE_SIGNING_IDENTITY" \
    "$APP_PATH"

  /usr/bin/codesign --display --verbose=4 "$EXECUTABLE_PATH"
  /usr/bin/codesign --verify --deep --strict "$APP_PATH"

  rm -f "$ZIP_PATH"
  /usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

  rm -rf "$DMG_STAGING_PATH"
  mkdir -p "$DMG_STAGING_PATH"
  cp -R "$APP_PATH" "$DMG_STAGING_PATH/"
  ln -s /Applications "$DMG_STAGING_PATH/Applications"

  rm -f "$DMG_PATH"
  /usr/bin/hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING_PATH" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

  rm -rf "$DMG_STAGING_PATH"

  /usr/bin/codesign --force --timestamp --sign "$APPLE_SIGNING_IDENTITY" "$DMG_PATH"
  /usr/bin/codesign --verify --strict "$DMG_PATH"
fi

if [[ -n "${APPLE_SIGNING_IDENTITY:-}" && -n "${APPLE_NOTARY_KEY_ID:-}" && -n "${APPLE_NOTARY_ISSUER_ID:-}" && -n "${APPLE_NOTARY_KEY_BASE64:-}" ]]; then
  mkdir -p "$ROOT_DIR/.build"
  echo "$APPLE_NOTARY_KEY_BASE64" | base64 --decode > "$NOTARY_KEY_PATH"
  chmod 600 "$NOTARY_KEY_PATH"

  submission_output="$(
    /usr/bin/xcrun notarytool submit \
      "$DMG_PATH" \
      --key "$NOTARY_KEY_PATH" \
      --key-id "$APPLE_NOTARY_KEY_ID" \
      --issuer "$APPLE_NOTARY_ISSUER_ID" \
      --wait \
      --output-format json
  )"

  submission_id="$(printf '%s' "$submission_output" | /usr/bin/plutil -extract id raw -)"
  submission_status="$(printf '%s' "$submission_output" | /usr/bin/plutil -extract status raw -)"
  printf '%s\n' "$submission_output"

  if [[ "$submission_status" != "Accepted" ]]; then
    /usr/bin/xcrun notarytool log \
      "$submission_id" \
      --key "$NOTARY_KEY_PATH" \
      --key-id "$APPLE_NOTARY_KEY_ID" \
      --issuer "$APPLE_NOTARY_ISSUER_ID"
    exit 1
  fi

  /usr/bin/xcrun stapler staple "$DMG_PATH"
  /usr/bin/xcrun stapler validate "$DMG_PATH"
fi
