# Implementation Plan

## 1. Product Vision

Build a native macOS clipboard manager similar to Maccy, with a strong focus on speed, low friction, and reliable clipboard history.

Core user flow:

1. User copies text or an image.
2. The app detects the new pasteboard content and stores it in history.
3. The user opens the history window with a global shortcut.
4. The user searches, previews, and selects a previous item.
5. The app restores the selected item to the clipboard.
6. Optionally, the app triggers paste into the currently focused app.

## 2. MVP Scope

The first shippable version should support:

- menu bar app with no dock presence by default
- background clipboard monitoring
- clipboard history list with newest-first ordering
- text item preview
- image item preview and thumbnail
- keyboard-first search UI
- selecting an item to restore it to the clipboard
- optional auto-paste after selection
- persistence across app relaunch
- deduplication of repeated clipboard entries
- configurable history size limit

Out of scope for MVP:

- iCloud sync
- multi-device sync
- OCR over screenshots
- advanced snippet templates
- team sharing
- full rich-text fidelity across every pasteboard flavor

## 3. Platform And Tech Choices

Recommended stack:

- Language: `Swift`
- UI: `SwiftUI` with selective `AppKit` integration
- Packaging: native macOS app in Xcode
- Persistence: `SQLite` with a thin storage layer
- Image storage: thumbnail plus original asset on disk, metadata in SQLite

Why this stack:

- macOS pasteboard APIs are first-class in native Swift/AppKit.
- A menu bar utility feels more reliable and polished as a native app.
- SwiftUI is productive for list and settings screens, while AppKit covers the utility-app behaviors SwiftUI still handles awkwardly.
- SQLite is simple, fast, and durable for clipboard history.

## 4. Functional Requirements

### Clipboard Capture

- Detect clipboard changes with `NSPasteboard.general.changeCount`.
- Poll at a small interval at first, then optimize if needed.
Supported types for the first versions:

- plain text
- images
- file URLs
- URLs
- optionally HTML / rich text later

- Ignore empty entries.
- Ignore app-generated duplicate writes when possible.

### History

- Store items newest first.
- Deduplicate by normalized content hash.
- Allow pinning later, but not required for first MVP.
Retention controls:

- max number of items
- optional max age

### Search And Preview

- Global shortcut opens a floating search window.
- Search should match text content and metadata.
List rows should include:

- type icon
- short title or preview text
- timestamp
- thumbnail for images

Preview content should include:

- larger image preview
- full text preview with truncation controls

### Restore And Paste

- Selecting an entry writes it back to `NSPasteboard.general`.
- Optional auto-paste simulates `Cmd+V`.
- Auto-paste must be behind an explicit setting because it may require Accessibility permission.
- Fallback behavior should still work without auto-paste permission: restore only.

### Preferences

- Launch at login
- max history count
- ignored apps
- ignored content types
- global shortcut
- auto-paste on selection
- preview behavior

## 5. Non-Functional Requirements

- Fast open time for the history window
- Low idle CPU usage
- Low memory footprint
- No unexpected clipboard corruption
- Safe handling of sensitive data
- Predictable behavior across reboots and app relaunches

Performance targets for early development:

- history window visible within `150 ms` after shortcut
- clipboard capture reflected in UI within `500 ms`
- search over `5,000` items remains responsive

## 6. Proposed Architecture

Suggested modules:

### `ClipboardMonitor`

Responsibilities:

- watch pasteboard changes
- normalize pasteboard payloads
- emit domain items for storage

Implementation notes:

- start with timer-based monitoring on the main run loop or a lightweight background task
- compare `changeCount`
- ignore entries inserted by the app if restoring history items

### `ClipboardItem`

A domain model representing one history record.

Suggested fields:

- `id`
- `type`
- `createdAt`
- `sourceAppBundleID` if available
- `textContent`
- `imagePath`
- `thumbnailPath`
- `fileURL`
- `contentHash`
- `isFavorite`
- `lastUsedAt`

### `HistoryStore`

Responsibilities:

- save new items
- deduplicate
- load recent items
- search history
- enforce retention limits

Implementation notes:

- store metadata in SQLite
- keep large binary image data outside the database on disk
- delete orphaned image files during retention cleanup

### `PreviewService`

Responsibilities:

- generate thumbnails
- classify content into preview-friendly representations
- provide preview models to the UI

### `PasteService`

Responsibilities:

- write selected item back to the system pasteboard
- optionally trigger paste into the active app

Implementation notes:

- use `NSPasteboard` for restoration
- use `CGEvent` or similar only when auto-paste is enabled and permissions are granted

### `HotkeyManager`

Responsibilities:

- register the global shortcut
- reopen or focus the history window

### `AppShell`

Responsibilities:

- menu bar item
- settings window
- floating search panel
- app lifecycle

## 7. Data Model Sketch

Suggested table: `clipboard_items`

- `id TEXT PRIMARY KEY`
- `type TEXT NOT NULL`
- `created_at REAL NOT NULL`
- `source_app_bundle_id TEXT`
- `title TEXT`
- `text_content TEXT`
- `image_path TEXT`
- `thumbnail_path TEXT`
- `file_url TEXT`
- `content_hash TEXT NOT NULL`
- `is_favorite INTEGER NOT NULL DEFAULT 0`
- `last_used_at REAL`

Suggested indexes:

- `INDEX idx_clipboard_items_created_at`
- `INDEX idx_clipboard_items_content_hash`
- `INDEX idx_clipboard_items_last_used_at`

## 8. UI Plan

### Menu Bar

- single menu bar icon
Menu bar actions:

- open history
- pause monitoring
- settings
- quit

### History Window

Recommended layout:

- top search field
- left or single-column list of history items
- right-side preview pane on larger widths, inline preview on compact layouts

Keyboard behavior:

- `Up` / `Down` to navigate
- `Enter` to restore or restore-and-paste
- `Cmd+1` or similar for favorite actions later
- `Esc` to close

### Item Presentation

Text item:

- first line as title
- multi-line snippet as preview

Image item:

- thumbnail in list
- larger preview in detail pane
- optional dimensions metadata

## 9. Implementation Phases

### Phase 0: Project Setup

- create Xcode app project
- configure menu bar utility app behavior
- set up project folders
- choose package manager approach for dependencies

Deliverable:

- app launches as a menu bar app and opens a placeholder history window

### Phase 1: Text Clipboard MVP

- implement `ClipboardMonitor`
- support plain text capture
- persist history to SQLite
- build searchable list UI
- restore selected text to clipboard

Deliverable:

- reliable text history with search and restore

### Phase 2: Image Support

- detect image content from pasteboard
- persist image files on disk
- generate thumbnails
- show list thumbnails and detail preview

Deliverable:

- image history with preview and restore

### Phase 3: Auto-Paste And Permissions

- add optional auto-paste flow
- detect and explain Accessibility permission
- handle denied-permission fallback cleanly

Deliverable:

- one-step restore-and-paste workflow when enabled

### Phase 4: Preferences And Stability

- settings screen
- ignored apps
- retention rules
- launch at login
- improved deduplication
- cleanup jobs

Deliverable:

- daily-driver quality utility app

### Phase 5: Polish

- performance tuning
- better preview UX
- empty states
- import/export ideas if needed
- app icon and release packaging

## 10. Risks And Edge Cases

### Pasteboard Complexity

The same clipboard action can expose multiple pasteboard representations. We should avoid treating each flavor as a separate history item.

Mitigation:

- define a primary representation per item
- hash normalized content, not raw pasteboard payload order

### Auto-Paste Reliability

Simulating paste may fail or behave inconsistently without proper permissions or when focus changes.

Mitigation:

- make auto-paste optional
- default to restore-only
- show clear permission guidance

### Image Storage Growth

Clipboard screenshots can grow storage quickly.

Mitigation:

- configurable retention limit
- thumbnail generation
- cleanup of old binaries

### Sensitive Content

Users may copy passwords or secrets.

Mitigation:

- optional ignored apps
- future support for private mode or ignored content rules
- clear data retention settings

## 11. Suggested Repository Structure

Once implementation starts, a structure like this should work well:

```text
mac-clipboard/
  README.md
  docs/
    IMPLEMENTATION_PLAN.md
  MacClipboard/
    App/
    Features/
      History/
      Preview/
      Settings/
    Services/
      Clipboard/
      Persistence/
      Hotkeys/
      Paste/
    Models/
    Resources/
  MacClipboardTests/
  MacClipboardUITests/
```

## 12. Testing Strategy

Unit tests:

- deduplication logic
- content classification
- retention cleanup
- thumbnail generation bookkeeping

Integration tests:

- clipboard capture pipeline
- persistence load and restore

Manual test matrix:

- copy text from multiple apps
- copy images and screenshots
- restore after app relaunch
- restore with auto-paste on and off
- permission denied scenarios
- large history collections

## 13. First Build Sprint Recommendation

The fastest path to momentum is:

1. Scaffold the Xcode app as a menu bar utility.
2. Build text-only clipboard monitoring first.
3. Add the searchable history window.
4. Add image storage and preview after the text loop feels solid.

This avoids getting blocked early on image persistence or Accessibility permissions before the core loop is proven.

## 14. Immediate Next Tasks

When we move from planning to implementation, the first concrete tasks should be:

1. Create the Xcode project and app target.
2. Add a basic menu bar item and floating panel.
3. Implement `ClipboardMonitor` for plain text.
4. Add a minimal local store and history list.
5. Verify end-to-end copy, list, restore.

## 15. Recommended Decision

If starting today, the best initial version is:

- native macOS app
- `SwiftUI` for UI
- `AppKit` only where needed
- text plus image support in the first real milestone
- restore first, auto-paste second

That gives the best balance of speed, reliability, and a realistic path to a polished Maccy-like experience.
