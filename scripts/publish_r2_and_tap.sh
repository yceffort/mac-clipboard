#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?Usage: publish_r2_and_tap.sh <version>}"
APP_NAME="yc.clipboard"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${ROOT_DIR}/dist/${DMG_NAME}"

: "${R2_ACCESS_KEY_ID:?R2_ACCESS_KEY_ID is required}"
: "${R2_SECRET_ACCESS_KEY:?R2_SECRET_ACCESS_KEY is required}"
: "${R2_ACCOUNT_ID:?R2_ACCOUNT_ID is required}"
: "${R2_BUCKET:?R2_BUCKET is required}"
: "${R2_PUBLIC_BASE_URL:?R2_PUBLIC_BASE_URL is required}"
: "${HOMEBREW_TAP_PAT:?HOMEBREW_TAP_PAT is required}"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found at $DMG_PATH" >&2
  exit 1
fi

TAP_DIR="$(mktemp -d)"
MANIFEST_PATH="$(mktemp -t latest_json.XXXXXX)"
trap 'rm -rf "$TAP_DIR" "$MANIFEST_PATH"' EXIT

R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
DOWNLOAD_URL="${R2_PUBLIC_BASE_URL%/}/${DMG_NAME}"

echo "Uploading ${DMG_NAME} to R2 bucket ${R2_BUCKET}"
AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
AWS_DEFAULT_REGION="auto" \
  aws s3 cp "$DMG_PATH" "s3://${R2_BUCKET}/${DMG_NAME}" \
    --endpoint-url "$R2_ENDPOINT" \
    --content-type "application/x-apple-diskimage"

SHA256="$(shasum -a 256 "$DMG_PATH" | cut -d' ' -f1)"
echo "SHA256: $SHA256"
echo "Download URL: $DOWNLOAD_URL"

cat > "$MANIFEST_PATH" <<EOF
{
  "version": "${VERSION}",
  "dmg_url": "${DOWNLOAD_URL}",
  "release_notes_url": "https://github.com/yceffort/mac-clipboard/releases/tag/v${VERSION}"
}
EOF

echo "Uploading latest.json to R2"
AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
AWS_DEFAULT_REGION="auto" \
  aws s3 cp "$MANIFEST_PATH" "s3://${R2_BUCKET}/latest.json" \
    --endpoint-url "$R2_ENDPOINT" \
    --content-type "application/json" \
    --cache-control "no-cache"

echo "Cloning homebrew-tap"
git clone \
  "https://x-access-token:${HOMEBREW_TAP_PAT}@github.com/yceffort/homebrew-tap.git" \
  "$TAP_DIR"

mkdir -p "$TAP_DIR/Casks"
CASK_PATH="$TAP_DIR/Casks/yc-clipboard.rb"

sed \
  -e "s|__VERSION__|${VERSION}|g" \
  -e "s|__SHA256__|${SHA256}|g" \
  -e "s|__DOWNLOAD_URL__|${DOWNLOAD_URL}|g" \
  "${ROOT_DIR}/scripts/cask_template.rb" > "$CASK_PATH"

cat "$CASK_PATH"

cd "$TAP_DIR"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add Casks/yc-clipboard.rb

if git diff --cached --quiet; then
  echo "No changes to Cask formula; skipping commit."
  exit 0
fi

git commit -m "release yc-clipboard ${VERSION}"
git push origin HEAD:main

echo "Published yc-clipboard ${VERSION} to homebrew-tap"
