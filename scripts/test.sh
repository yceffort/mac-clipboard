#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
HOME_OVERRIDE_PATH="$ROOT_DIR/.home"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Full Xcode is not installed in this environment. Skipping XCTest suite."
  exit 0
fi

mkdir -p "$MODULE_CACHE_PATH" "$HOME_OVERRIDE_PATH"

cd "$ROOT_DIR"

HOME="$HOME_OVERRIDE_PATH" \
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_PATH" \
SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_PATH" \
swift test -Xswiftc -module-cache-path -Xswiftc "$MODULE_CACHE_PATH"
