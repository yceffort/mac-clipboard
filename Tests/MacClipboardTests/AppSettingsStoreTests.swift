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

    func testIgnoredAppCanBeAddedAndRemoved() {
        let store = AppSettingsStore()

        store.addIgnoredApp(bundleID: "com.apple.Terminal")

        XCTAssertTrue(store.shouldIgnore(bundleID: "com.apple.Terminal"))
        XCTAssertEqual(store.settings.ignoredAppBundleIDs, ["com.apple.Terminal"])

        store.removeIgnoredApp(bundleID: "com.apple.Terminal")

        XCTAssertFalse(store.shouldIgnore(bundleID: "com.apple.Terminal"))
        XCTAssertTrue(store.settings.ignoredAppBundleIDs.isEmpty)
    }

    func testAddingSameBundleIDTwiceKeepsUniqueEntry() {
        let store = AppSettingsStore()

        store.addIgnoredApp(bundleID: "com.apple.Terminal")
        store.addIgnoredApp(bundleID: "com.apple.Terminal")

        XCTAssertEqual(store.settings.ignoredAppBundleIDs, ["com.apple.Terminal"])
    }

    func testAddingBlankBundleIDIsIgnored() {
        let store = AppSettingsStore()

        store.addIgnoredApp(bundleID: "   ")

        XCTAssertTrue(store.settings.ignoredAppBundleIDs.isEmpty)
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
