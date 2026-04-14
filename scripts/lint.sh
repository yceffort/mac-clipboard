#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SWIFTLINT_BIN="${SWIFTLINT_BIN:-swiftlint}"

if ! command -v "$SWIFTLINT_BIN" >/dev/null 2>&1; then
  echo "swiftlint is required." >&2
  echo "Install it with: brew bundle install --file Brewfile" >&2
  exit 1
fi

cd "$ROOT_DIR"
"$SWIFTLINT_BIN" lint --strict --config "$ROOT_DIR/.swiftlint.yml"
