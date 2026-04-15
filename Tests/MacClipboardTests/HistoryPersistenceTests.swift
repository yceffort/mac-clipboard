import Foundation
@testable import MacClipboard
import XCTest

final class HistoryPersistenceTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try configureTemporarySupportDirectory()
    }

    override func tearDownWithError() throws {
        unsetenv("YCEFFORT_CLIPBOARD_APP_SUPPORT_DIR")
        try super.tearDownWithError()
    }

    func testSQLiteRoundTripPreservesExtendedClipboardMetadata() throws {
        let persistence = HistoryPersistence()
        let createdAt = Date(timeIntervalSince1970: 1_717_171_717)
        let lastUsedAt = createdAt.addingTimeInterval(42)

        let items = try [
            ClipboardItem(
                id: XCTUnwrap(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")),
                kind: .file,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                contentHash: "hash-file",
                textContent: "notes.pdf",
                imagePath: nil,
                sourceAppBundleID: "com.apple.finder",
                isPinned: true,
                urlString: nil,
                filePaths: ["/tmp/notes.pdf"],
                htmlContent: nil,
                richTextPath: nil
            ),
            ClipboardItem(
                id: XCTUnwrap(UUID(uuidString: "11111111-2222-3333-4444-555555555555")),
                kind: .url,
                createdAt: createdAt.addingTimeInterval(5),
                lastUsedAt: nil,
                contentHash: "hash-url",
                textContent: "https://example.com",
                imagePath: nil,
                sourceAppBundleID: "com.apple.Safari",
                isPinned: false,
                urlString: "https://example.com",
                filePaths: [],
                htmlContent: "<p>Hello</p>",
                richTextPath: "/tmp/example.rtf"
            ),
        ]

        try persistence.save(items: items)
        let loadedItems = persistence.loadItems()

        XCTAssertEqual(loadedItems, items)
    }

    func testApplyChangesUpsertsNewAndExistingRows() throws {
        let persistence = HistoryPersistence()
        let original = try makeItem(
            idString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            hash: "hash-a",
            text: "A",
            isPinned: false
        )
        let addition = try makeItem(
            idString: "11111111-2222-3333-4444-555555555555",
            hash: "hash-b",
            text: "B",
            isPinned: false
        )

        try persistence.save(items: [original])

        var updated = original
        updated.isPinned = true
        updated.textContent = "A updated"

        try persistence.applyChanges(upserts: [updated, addition], deletedIDs: [])

        let loaded = persistence.loadItems()
            .sorted { $0.contentHash < $1.contentHash }

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].id, updated.id)
        XCTAssertEqual(loaded[0].textContent, "A updated")
        XCTAssertTrue(loaded[0].isPinned)
        XCTAssertEqual(loaded[1].id, addition.id)
    }

    func testApplyChangesDeletesRequestedIDs() throws {
        let persistence = HistoryPersistence()
        let first = try makeItem(
            idString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            hash: "hash-a",
            text: "A",
            isPinned: false
        )
        let second = try makeItem(
            idString: "11111111-2222-3333-4444-555555555555",
            hash: "hash-b",
            text: "B",
            isPinned: false
        )

        try persistence.save(items: [first, second])
        try persistence.applyChanges(upserts: [], deletedIDs: [first.id])

        let loaded = persistence.loadItems()
        XCTAssertEqual(loaded.map(\.id), [second.id])
    }

    private func makeItem(idString: String, hash: String, text: String, isPinned: Bool) throws -> ClipboardItem {
        try ClipboardItem(
            id: XCTUnwrap(UUID(uuidString: idString)),
            kind: .text,
            createdAt: Date(timeIntervalSince1970: 1_717_171_717),
            lastUsedAt: nil,
            contentHash: hash,
            textContent: text,
            imagePath: nil,
            sourceAppBundleID: "com.apple.TextEdit",
            isPinned: isPinned,
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
