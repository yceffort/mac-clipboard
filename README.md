# mac-clipboard

A native macOS clipboard manager inspired by Maccy.

Current display name: `yceffort Clipboard`

## Goal

Build a lightweight macOS app that:

- records clipboard history
- lets you search and preview previous items
- restores an item back to the clipboard on demand
- supports both text and images
- can optionally auto-paste the selected item

## Current State

- native `Swift` package that Xcode can open directly
- `SwiftUI` history window and preview pane
- `AppKit` menu bar integration and clipboard access
- searchable history with pinning, clear history, and recent items in the menu bar
- clipboard capture for text, images, URLs, files, HTML, and rich text
- restore-to-clipboard and optional auto-paste with accessibility guidance
- settings for history size, appearance, startup behavior, launch at login, ignored apps, and private mode
- SQLite-backed persistence in `Application Support/yceffort Clipboard`

## Plan

The original product and technical plan lives here:

- [docs/IMPLEMENTATION_PLAN.md](/Users/yceffort/private/mac-clipboard/docs/IMPLEMENTATION_PLAN.md)

## Local Development

Open [Package.swift](/Users/yceffort/private/mac-clipboard/Package.swift) in Xcode and run the `MacClipboard` executable target, or use the helper scripts below.

For local CLI tools, install the repo's macOS dependencies once with [Brewfile](/Users/yceffort/private/mac-clipboard/Brewfile):

```bash
brew bundle install --file Brewfile
```

The repo uses a small [Makefile](/Users/yceffort/private/mac-clipboard/Makefile) as the task runner, which is a more typical fit for a Swift project than `npm`.

- install local tooling: `make tools`
- format in place: `make format`
- check formatting only: `make format-check`
- run lint: `make lint`
- run build: `make build`
- run tests: `make test`
- run the full quality gate: `make quality`
- package the app: `make package`

Formatting uses [swiftformat](/Users/yceffort/private/mac-clipboard/.swiftformat), linting uses [.swiftlint.yml](/Users/yceffort/private/mac-clipboard/.swiftlint.yml), and build/test/package helpers stay in [scripts](/Users/yceffort/private/mac-clipboard/scripts).

`swiftlint` installation expects a full `Xcode.app` install on the local machine, which matches the normal setup for macOS app development. GitHub's macOS runners already satisfy that requirement in CI.

For packaging helpers that are still easier as shell entrypoints:

- build debug with module-cache isolation: `./scripts/build.sh debug`
- build release with module-cache isolation: `./scripts/build.sh release`
- run local tests with Xcode detection: `./scripts/test.sh`
- build `.app`, `.zip`, and `.dmg`: `./scripts/package_app.sh`

## Package App

To build a local `.app` bundle, zipped archive, and installable DMG:

- run [scripts/package_app.sh](/Users/yceffort/private/mac-clipboard/scripts/package_app.sh)
- the outputs will appear at `dist/yceffort Clipboard.app`, `dist/yceffort Clipboard-<version>.zip`, and `dist/yceffort Clipboard-<version>.dmg`
- the package script also generates and embeds a native app icon automatically

The package version comes from [version.txt](/Users/yceffort/private/mac-clipboard/version.txt).

## Release Workflow

GitHub release automation is set up for `main`:

- pull requests run the shared quality gate via [.github/workflows/ci.yml](/Users/yceffort/private/mac-clipboard/.github/workflows/ci.yml)
- the PR and release workflows both reuse the shared composite quality action at [.github/actions/quality/action.yml](/Users/yceffort/private/mac-clipboard/.github/actions/quality/action.yml)
- every merge to `main` runs the quality gate and then evaluates the commits since the latest release tag
- the release workflow bumps the version automatically from Conventional Commits, updates [version.txt](/Users/yceffort/private/mac-clipboard/version.txt) and [CHANGELOG.md](/Users/yceffort/private/mac-clipboard/CHANGELOG.md), packages the app, and publishes the next GitHub release via [.github/workflows/release.yml](/Users/yceffort/private/mac-clipboard/.github/workflows/release.yml)
- when a release is created, the workflow packages the macOS app on an Apple Silicon macOS runner and uploads both the zip and DMG artifacts to the GitHub release
- if Apple signing secrets are present, the same workflow signs the app, notarizes the DMG, and staples both artifacts

### When A Release Happens

- a pull request merge alone does not guarantee a release
- a new release is created when commits pushed to `main` include at least one releasable Conventional Commit
- commits such as `chore:`, `docs:`, `style:`, `test:`, or `ci:` do not create a release by themselves

Version bumps follow this rule set:

- `feat:` -> minor
- `fix:`, `perf:`, `refactor:`, `revert:` -> patch
- any `!` commit or `BREAKING CHANGE:` footer -> major

Examples:

- `feat: add clipboard deduplication` -> `0.1.0` to `0.2.0`
- `fix: close history window on escape` -> `0.2.0` to `0.2.1`
- `feat!: change storage format` -> next major release
- `chore: update README` -> no release

This setup treats [version.txt](/Users/yceffort/private/mac-clipboard/version.txt) `0.1.0` as the current baseline. Create the initial tag once before relying on automated releases so the first automatic release starts from the right version.

```bash
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

Recommended commit prefixes:

- `feat:` for user-facing features
- `fix:` for bug fixes
- `perf:` for performance work
- `chore:` for maintenance work that should not trigger a release by itself
- `feat!:` or `fix!:` for breaking changes

### Optional Release Secrets

Add these GitHub Actions secrets if you want signed and notarized public releases:

- `APPLE_DEVELOPER_ID_CERT_BASE64`: base64-encoded Developer ID Application `.p12`
- `APPLE_DEVELOPER_ID_CERT_PASSWORD`: password for that `.p12`
- `APPLE_KEYCHAIN_PASSWORD`: temporary CI keychain password
- `APPLE_SIGNING_IDENTITY`: full Developer ID signing identity string
- `APPLE_NOTARY_KEY_ID`: App Store Connect API key ID
- `APPLE_NOTARY_ISSUER_ID`: App Store Connect issuer ID
- `APPLE_NOTARY_KEY_BASE64`: base64-encoded App Store Connect `.p8` key

Without these secrets, releases still build and upload unsigned `.zip` and `.dmg` assets.
