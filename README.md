# yc.clipboard

`yc.clipboard` is a lightweight macOS clipboard manager inspired by Maccy.

It keeps clipboard history for text, images, URLs, files, HTML, and rich text, lets you search and preview previous items, and can either copy an item back to the clipboard or paste it directly into the previously focused app.

## Features

- menu bar app with a global history window
- searchable clipboard history with pinning and item deletion
- previews for text, images, files, URLs, HTML, and rich text
- `Copy` and `Paste` actions, plus double-click / Enter shortcuts
- ignored apps, private mode, launch at login, and appearance settings
- SQLite-backed persistence

## Install

- Latest release: [GitHub Releases](https://github.com/yceffort/mac-clipboard/releases)
- Current packaged artifacts use the `yc.clipboard` name:
  - `yc.clipboard.app`
  - `yc.clipboard-<version>.zip`
  - `yc.clipboard-<version>.dmg`

If you use the local installer path, the app lives at `/Applications/yc.clipboard.app`.

## Local Development

Open [Package.swift](/Users/yceffort/private/mac-clipboard/Package.swift) in Xcode and run the `MacClipboard` executable target.

Install local tooling once:

```bash
brew bundle install --file Brewfile
```

Common commands:

- `make tools`
- `make format`
- `make format-check`
- `make lint`
- `make build`
- `make test`
- `make quality`
- `make package`

Lower-level helpers still exist in [scripts](/Users/yceffort/private/mac-clipboard/scripts), including:

- `./scripts/build.sh debug`
- `./scripts/build.sh release`
- `./scripts/test.sh`
- `./scripts/package_app.sh`

## Release Flow

- pull requests run the shared quality gate from [.github/workflows/ci.yml](/Users/yceffort/private/mac-clipboard/.github/workflows/ci.yml)
- pushes to `main` run the release workflow from [.github/workflows/release.yml](/Users/yceffort/private/mac-clipboard/.github/workflows/release.yml)
- releasable Conventional Commits automatically bump the version, update [CHANGELOG.md](/Users/yceffort/private/mac-clipboard/CHANGELOG.md), and publish a GitHub release

Version rules:

- `feat:` -> minor
- `fix:`, `perf:`, `refactor:`, `revert:` -> patch
- `!` or `BREAKING CHANGE:` -> major
- `chore:`, `docs:`, `test:`, `ci:` -> no release by themselves

## Notes

- The app display name is now `yc.clipboard`.
- The Application Support directory intentionally remains `yceffort Clipboard` so existing history and settings are preserved across upgrades.
- Unsigned local builds may still require `right click > Open` on another Mac unless Apple signing and notarization secrets are configured in GitHub Actions.
