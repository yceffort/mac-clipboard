import Foundation
@testable import MacClipboard
import XCTest

@MainActor
final class HistoryStoreTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try configureTemporarySupportDirectory()
    }

    override func tearDownWithError() throws {
        unsetenv("YCEFFORT_CLIPBOARD_APP_SUPPORT_DIR")
        try super.tearDownWithError()
    }

    func testCaptureSkipsConsecutiveDuplicateContentHashes() {
        let store = HistoryStore()
        let firstItem = makeTextItem(
            id: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            hash: "same-hash",
            text: "hello"
        )
        let duplicateItem = makeTextItem(
            id: "11111111-2222-3333-4444-555555555555",
            hash: "same-hash",
            text: "hello"
        )

        store.capture(firstItem)
        store.capture(duplicateItem)

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.id, firstItem.id)
    }

    func testCaptureStillPromotesNonConsecutiveDuplicatesWithoutDuplicatingThem() {
        let store = HistoryStore()
        let firstItem = makeTextItem(
            id: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            hash: "hash-a",
            text: "A"
        )
        let secondItem = makeTextItem(
            id: "11111111-2222-3333-4444-555555555555",
            hash: "hash-b",
            text: "B"
        )
        let repeatedFirstItem = makeTextItem(
            id: "99999999-8888-7777-6666-555555555555",
            hash: "hash-a",
            text: "A"
        )

        store.capture(firstItem)
        store.capture(secondItem)
        store.capture(repeatedFirstItem)

        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items.first?.contentHash, firstItem.contentHash)
        XCTAssertEqual(store.items.last?.contentHash, secondItem.contentHash)
    }

    private func makeTextItem(id: String, hash: String, text: String) -> ClipboardItem {
        ClipboardItem(
            id: UUID(uuidString: id) ?? UUID(),
            kind: .text,
            createdAt: Date(timeIntervalSince1970: 1_717_171_717),
            lastUsedAt: nil,
            contentHash: hash,
            textContent: text,
            imagePath: nil,
            sourceAppBundleID: "com.apple.TextEdit",
            isPinned: false,
            urlString: nil,
            filePaths: [],
            htmlContent: nil,
            richTextPath: nil
        )
    }

    private func configureTemporarySupportDirectory() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        setenv("YCEFFORT_CLIPBOARD_APP_SUPPORT_DIR", directoryURL.path, 1)
    }
}
