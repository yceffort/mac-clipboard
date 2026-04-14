#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?Usage: update_changelog.sh <version> <notes-path>}"
NOTES_PATH="${2:?Usage: update_changelog.sh <version> <notes-path>}"
CHANGELOG_PATH="$ROOT_DIR/CHANGELOG.md"
VERSION_FILE="$ROOT_DIR/version.txt"
DATE_STAMP="$(date '+%Y-%m-%d')"
TMP_CHANGELOG="$(mktemp "$ROOT_DIR/.build/changelog.XXXXXX")"
EXISTING_ENTRIES="$(mktemp "$ROOT_DIR/.build/changelog-existing.XXXXXX")"

trap 'rm -f "$TMP_CHANGELOG" "$EXISTING_ENTRIES"' EXIT

if [[ -f "$CHANGELOG_PATH" ]]; then
  awk -v version="$VERSION" '
    BEGIN { capture = 0; skip = 0 }
    /^## \[/ { capture = 1 }
    capture {
      if ($0 ~ "^## \\[" version "\\] - ") {
        skip = 1
        next
      }

      if (skip && $0 ~ "^## \\[") {
        skip = 0
      }

      if (!skip) {
        print
      }
    }
  ' "$CHANGELOG_PATH" > "$EXISTING_ENTRIES"
fi

printf '%s\n' "$VERSION" > "$VERSION_FILE"

{
  printf '# Changelog\n\n'
  printf 'All notable changes to this project will be documented in this file.\n\n'
  printf '## [%s] - %s\n\n' "$VERSION" "$DATE_STAMP"
  cat "$NOTES_PATH"

  if [[ -s "$EXISTING_ENTRIES" ]]; then
    printf '\n\n'
    cat "$EXISTING_ENTRIES"
  fi
} > "$TMP_CHANGELOG"

mv "$TMP_CHANGELOG" "$CHANGELOG_PATH"
