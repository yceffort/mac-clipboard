#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
HOME_OVERRIDE_PATH="$ROOT_DIR/.home"
CONFIGURATION="${1:-debug}"

case "$CONFIGURATION" in
  debug|release) ;;
  *)
    echo "Unsupported build configuration: $CONFIGURATION" >&2
    echo "Usage: ./scripts/build.sh [debug|release]" >&2
    exit 1
    ;;
esac

mkdir -p "$MODULE_CACHE_PATH" "$HOME_OVERRIDE_PATH"

cd "$ROOT_DIR"

HOME="$HOME_OVERRIDE_PATH" \
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_PATH" \
SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_PATH" \
swift build -c "$CONFIGURATION" -Xswiftc -module-cache-path -Xswiftc "$MODULE_CACHE_PATH"
