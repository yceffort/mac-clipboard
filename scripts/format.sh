#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-write}"
SWIFTFORMAT_BIN="${SWIFTFORMAT_BIN:-swiftformat}"

if ! command -v "$SWIFTFORMAT_BIN" >/dev/null 2>&1; then
  echo "swiftformat is required." >&2
  echo "Install it with: brew bundle --file Brewfile --no-lock" >&2
  exit 1
fi

TARGETS=(
  "$ROOT_DIR/Package.swift"
  "$ROOT_DIR/Sources"
  "$ROOT_DIR/Tests"
  "$ROOT_DIR/scripts"
)

case "$MODE" in
  write|format)
    "$SWIFTFORMAT_BIN" --config "$ROOT_DIR/.swiftformat" "${TARGETS[@]}"
    ;;
  check|lint)
    "$SWIFTFORMAT_BIN" --lint --config "$ROOT_DIR/.swiftformat" "${TARGETS[@]}"
    ;;
  *)
    echo "Unsupported mode: $MODE" >&2
    echo "Usage: ./scripts/format.sh [write|check]" >&2
    exit 1
    ;;
esac
