# Changelog

All notable changes to this project will be documented in this file.

## [0.3.3] - 2026-04-15

### Fixed

- satisfy clipboard monitor release lint rules
- 
restore clipboard monitor release build

### Changed

- 
move clipboard capture work off the main thread


## [0.3.2] - 2026-04-15

### Fixed

- serialize incremental persistence writes
- 
drop redundant self in scheduled persist closure

### Changed

- 
persist clipboard history changes incrementally
- 
debounce history search and cache searchable text


## [0.3.1] - 2026-04-15

### Changed

- cache decoded clipboard thumbnails in memory


## [0.3.0] - 2026-04-14

### Added

- rename the app to yc.clipboard and polish paste flow



## [0.2.0] - 2026-04-14

### Added

- add single clipboard item deletion



## [0.1.2] - 2026-04-14

### Fixed

- make semantic app version equality consistent



## [0.1.1] - 2026-04-14

- Added a launch-at-login setting for the installed app and wired it to macOS login via LaunchAgents.
- Improved settings so startup and appearance preferences can be managed directly in the app.

## [0.1.0] - 2026-04-13

- Added a native macOS clipboard manager with a menu bar app, searchable history, and preview pane.
- Added clipboard capture and restore support for text, images, URLs, files, HTML, and rich text.
- Added settings, ignored apps/private mode, pinning, accessibility-aware paste, and local `.app` packaging.
