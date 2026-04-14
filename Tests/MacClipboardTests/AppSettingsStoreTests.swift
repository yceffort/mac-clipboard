import Foundation
@testable import MacClipboard
import XCTest

@MainActor
final class AppSettingsStoreTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try configureTemporarySupportDirectory()
    }

    override func tearDownWithError() throws {
        unsetenv("YCEFFORT_CLIPBOARD_APP_SUPPORT_DIR")
        try super.tearDownWithError()
    }

    func testIgnoredPresetAddsAndRemovesAllBundleIDs() {
        let store = AppSettingsStore()

        store.setIgnored(.terminal, enabled: true)

        XCTAssertTrue(store.isIgnored(.terminal))
        XCTAssertTrue(store.shouldIgnore(bundleID: "com.apple.Terminal"))

        store.setIgnored(.terminal, enabled: false)

        XCTAssertFalse(store.isIgnored(.terminal))
        XCTAssertFalse(store.shouldIgnore(bundleID: "com.apple.Terminal"))
    }

    func testUpdateBookkeepingPersistsInMemoryState() {
        let store = AppSettingsStore()
        let checkDate = Date(timeIntervalSince1970: 1234)

        store.recordUpdateCheck(checkDate)
        store.dismissUpdateVersion("0.2.0")

        XCTAssertEqual(store.settings.lastUpdateCheckDate, checkDate)
        XCTAssertEqual(store.settings.dismissedUpdateVersion, "0.2.0")
    }

    func testAppearancePreferenceUpdatesInMemoryState() {
        let store = AppSettingsStore()

        store.settings.appearancePreference = .dark

        XCTAssertEqual(store.settings.appearancePreference, .dark)
    }

    func testLaunchAtLoginPreferenceUpdatesInMemoryState() {
        let store = AppSettingsStore()

        store.settings.launchAtLoginEnabled = true

        XCTAssertTrue(store.settings.launchAtLoginEnabled)
    }

    private nonisolated func configureTemporarySupportDirectory() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        setenv("YCEFFORT_CLIPBOARD_APP_SUPPORT_DIR", directoryURL.path, 1)
    }
}
