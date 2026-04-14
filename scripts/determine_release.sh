#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/version.txt"
NOTES_PATH="$ROOT_DIR/.build/release-notes.md"

mkdir -p "$ROOT_DIR/.build"

release_level="none"
typeset -a added_notes
typeset -a fixed_notes
typeset -a changed_notes

write_output() {
  local key="$1"
  local value="$2"

  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf '%s=%s\n' "$key" "$value" >> "$GITHUB_OUTPUT"
  else
    printf '%s=%s\n' "$key" "$value"
  fi
}

set_release_level() {
  local candidate="$1"

  case "$candidate" in
    major)
      release_level="major"
      ;;
    minor)
      if [[ "$release_level" != "major" ]]; then
        release_level="minor"
      fi
      ;;
    patch)
      if [[ "$release_level" == "none" ]]; then
        release_level="patch"
      fi
      ;;
  esac
}

increment_version() {
  local version="$1"
  local level="$2"
  local major minor patch

  IFS='.' read -r major minor patch <<< "$version"

  case "$level" in
    major)
      printf '%d.0.0\n' "$((major + 1))"
      ;;
    minor)
      printf '%d.%d.0\n' "$major" "$((minor + 1))"
      ;;
    patch)
      printf '%d.%d.%d\n' "$major" "$minor" "$((patch + 1))"
      ;;
    *)
      printf '%s\n' "$version"
      ;;
  esac
}

clean_subject() {
  local subject="$1"
  printf '%s' "$subject" | sed -E 's/^[a-z]+(\([^)]+\))?(!)?:[[:space:]]*//'
}

last_tag="$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)"
base_version="$(tr -d '[:space:]' < "$VERSION_FILE")"

if [[ -n "$last_tag" ]]; then
  base_version="${last_tag#v}"
  git_log_command=(git log --no-merges --format=%s%x1f%b%x1e "$last_tag..HEAD")
else
  git_log_command=(git log --no-merges --format=%s%x1f%b%x1e)
fi

while IFS=$'\x1f' read -r -d $'\x1e' subject body; do
  [[ -z "$subject" ]] && continue

  commit_type="$(printf '%s' "$subject" | sed -nE 's/^([a-z]+)(\([^)]+\))?(!)?: .*/\1/p')"

  if [[ -z "$commit_type" ]]; then
    continue
  fi

  is_breaking=false
  if printf '%s' "$subject" | grep -Eq '^[a-z]+(\([^)]+\))?!: '; then
    is_breaking=true
  fi

  if printf '%s' "$body" | grep -Eq 'BREAKING CHANGE:'; then
    is_breaking=true
  fi

  cleaned_subject="$(clean_subject "$subject")"

  case "$commit_type" in
    feat)
      if [[ "$is_breaking" == true ]]; then
        set_release_level major
        added_notes+=("$cleaned_subject (breaking)")
      else
        set_release_level minor
        added_notes+=("$cleaned_subject")
      fi
      ;;
    fix)
      if [[ "$is_breaking" == true ]]; then
        set_release_level major
        fixed_notes+=("$cleaned_subject (breaking)")
      else
        set_release_level patch
        fixed_notes+=("$cleaned_subject")
      fi
      ;;
    perf|refactor|revert)
      if [[ "$is_breaking" == true ]]; then
        set_release_level major
        changed_notes+=("$cleaned_subject (breaking)")
      else
        set_release_level patch
        changed_notes+=("$cleaned_subject")
      fi
      ;;
    *)
      if [[ "$is_breaking" == true ]]; then
        set_release_level major
        changed_notes+=("$cleaned_subject (breaking)")
      fi
      ;;
  esac
done < <("${git_log_command[@]}")

if [[ "$release_level" == "none" ]]; then
  rm -f "$NOTES_PATH"
  write_output should_release false
  write_output version ""
  write_output tag ""
  write_output notes_path ""
  exit 0
fi

next_version="$(increment_version "$base_version" "$release_level")"

{
  if (( ${#added_notes[@]} > 0 )); then
    printf '### Added\n\n'
    for note in "${added_notes[@]}"; do
      printf -- '- %s\n' "$note"
    done
    printf '\n'
  fi

  if (( ${#fixed_notes[@]} > 0 )); then
    printf '### Fixed\n\n'
    for note in "${fixed_notes[@]}"; do
      printf -- '- %s\n' "$note"
    done
    printf '\n'
  fi

  if (( ${#changed_notes[@]} > 0 )); then
    printf '### Changed\n\n'
    for note in "${changed_notes[@]}"; do
      printf -- '- %s\n' "$note"
    done
  fi
} > "$NOTES_PATH"

write_output should_release true
write_output version "$next_version"
write_output tag "v$next_version"
write_output notes_path "$NOTES_PATH"
