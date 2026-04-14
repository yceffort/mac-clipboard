import Combine
import Foundation
import SQLite3

struct HistoryPersistence {
    func loadItems() -> [ClipboardItem] {
        guard let database = openDatabase() else {
            return loadLegacyJSONItems()
        }

        defer { sqlite3_close(database) }
        initializeSchema(in: database)
        migrateLegacyJSONIfNeeded(into: database)

        let sql = """
        SELECT
            id,
            kind,
            created_at,
            last_used_at,
            content_hash,
            text_content,
            image_path,
            source_app_bundle_id,
            is_pinned,
            url_string,
            file_paths_json,
            html_content,
            rich_text_path
        FROM clipboard_items
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        defer { sqlite3_finalize(statement) }

        var items: [ClipboardItem] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idString = sqliteText(statement, index: 0),
                let kindRawValue = sqliteText(statement, index: 1),
                let kind = ClipboardItemKind(rawValue: kindRawValue),
                let id = UUID(uuidString: idString)
            else {
                continue
            }

            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
            let lastUsedRaw =
                sqlite3_column_type(statement, 3) == SQLITE_NULL
                    ? nil
                    : sqlite3_column_double(
                        statement,
                        3
                    )
            let contentHash = sqliteText(statement, index: 4) ?? UUID().uuidString
            let textContent = sqliteText(statement, index: 5)
            let imagePath = sqliteText(statement, index: 6)
            let sourceAppBundleID = sqliteText(statement, index: 7)
            let isPinned = sqlite3_column_int(statement, 8) == 1
            let urlString = sqliteText(statement, index: 9)
            let filePaths = decodeJSONTextArray(sqliteText(statement, index: 10))
            let htmlContent = sqliteText(statement, index: 11)
            let richTextPath = sqliteText(statement, index: 12)

            items.append(
                ClipboardItem(
                    id: id,
                    kind: kind,
                    createdAt: createdAt,
                    lastUsedAt: lastUsedRaw.map(Date.init(timeIntervalSince1970:)),
                    contentHash: contentHash,
                    textContent: textContent,
                    imagePath: imagePath,
                    sourceAppBundleID: sourceAppBundleID,
                    isPinned: isPinned,
                    urlString: urlString,
                    filePaths: filePaths,
                    htmlContent: htmlContent,
                    richTextPath: richTextPath
                )
            )
        }

        return items
    }

    func save(items: [ClipboardItem]) throws {
        guard let database = openDatabase() else {
            throw PersistenceError.openDatabaseFailed
        }

        defer { sqlite3_close(database) }
        initializeSchema(in: database)

        guard execute(sql: "BEGIN IMMEDIATE TRANSACTION", in: database) else {
            throw PersistenceError.transactionFailed
        }

        do {
            guard execute(sql: "DELETE FROM clipboard_items", in: database) else {
                throw PersistenceError.clearFailed
            }

            let insertSQL = """
            INSERT INTO clipboard_items (
                id,
                kind,
                created_at,
                last_used_at,
                content_hash,
                text_content,
                image_path,
                source_app_bundle_id,
                is_pinned,
                url_string,
                file_paths_json,
                html_content,
                rich_text_path
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, insertSQL, -1, &statement, nil) == SQLITE_OK else {
                throw PersistenceError.prepareStatementFailed
            }

            defer { sqlite3_finalize(statement) }

            for item in items {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)

                bindText(item.id.uuidString, to: statement, index: 1)
                bindText(item.kind.rawValue, to: statement, index: 2)
                sqlite3_bind_double(statement, 3, item.createdAt.timeIntervalSince1970)

                if let lastUsedAt = item.lastUsedAt {
                    sqlite3_bind_double(statement, 4, lastUsedAt.timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(statement, 4)
                }

                bindText(item.contentHash, to: statement, index: 5)
                bindOptionalText(item.textContent, to: statement, index: 6)
                bindOptionalText(item.imagePath, to: statement, index: 7)
                bindOptionalText(item.sourceAppBundleID, to: statement, index: 8)
                sqlite3_bind_int(statement, 9, item.isPinned ? 1 : 0)
                bindOptionalText(item.urlString, to: statement, index: 10)
                bindText(encodeJSONTextArray(item.filePaths), to: statement, index: 11)
                bindOptionalText(item.htmlContent, to: statement, index: 12)
                bindOptionalText(item.richTextPath, to: statement, index: 13)

                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw PersistenceError.insertFailed
                }
            }

            guard execute(sql: "COMMIT TRANSACTION", in: database) else {
                throw PersistenceError.transactionFailed
            }
        } catch {
            _ = execute(sql: "ROLLBACK TRANSACTION", in: database)
            throw error
        }
    }

    private func openDatabase() -> OpaquePointer? {
        var database: OpaquePointer?
        let path = AppPaths.historyDatabaseURL().path

        guard sqlite3_open(path, &database) == SQLITE_OK else {
            if let database {
                sqlite3_close(database)
            }
            return nil
        }

        return database
    }

    private func initializeSchema(in database: OpaquePointer) {
        let sql = """
        CREATE TABLE IF NOT EXISTS clipboard_items (
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            created_at REAL NOT NULL,
            last_used_at REAL,
            content_hash TEXT NOT NULL,
            text_content TEXT,
            image_path TEXT,
            source_app_bundle_id TEXT,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            url_string TEXT,
            file_paths_json TEXT NOT NULL DEFAULT '[]',
            html_content TEXT,
            rich_text_path TEXT
        );
        """

        _ = execute(sql: sql, in: database)
    }

    private func migrateLegacyJSONIfNeeded(into database: OpaquePointer) {
        guard countItems(in: database) == 0 else {
            return
        }

        let legacyItems = loadLegacyJSONItems()
        guard legacyItems.isEmpty == false else {
            return
        }

        try? save(items: legacyItems)
        try? FileManager.default.removeItem(at: AppPaths.historyFileURL())
    }

    private func countItems(in database: OpaquePointer) -> Int {
        let sql = "SELECT COUNT(*) FROM clipboard_items"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return 0
        }

        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return 0
        }

        return Int(sqlite3_column_int(statement, 0))
    }

    private func execute(sql: String, in database: OpaquePointer) -> Bool {
        sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK
    }

    private func loadLegacyJSONItems() -> [ClipboardItem] {
        let fileURL = AppPaths.historyFileURL()

        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return (try? decoder.decode([ClipboardItem].self, from: data)) ?? []
    }

    private func sqliteText(_ statement: OpaquePointer?, index: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else {
            return nil
        }

        return String(cString: cString)
    }

    private func bindText(_ value: String, to statement: OpaquePointer?, index: Int32) {
        sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
    }

    private func bindOptionalText(_ value: String?, to statement: OpaquePointer?, index: Int32) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }

        bindText(value, to: statement, index: index)
    }

    private func encodeJSONTextArray(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let string = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }

        return string
    }

    private func decodeJSONTextArray(_ value: String?) -> [String] {
        guard let value,
              let data = value.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }

        return decoded
    }
}

private enum PersistenceError: Error {
    case openDatabaseFailed
    case transactionFailed
    case clearFailed
    case prepareStatementFailed
    case insertFailed
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private let persistence = HistoryPersistence()
    private let assetStore = ClipboardAssetStore()
    private var maxItems = 200
    private var pendingPersistTask: Task<Void, Never>?

    func loadPersistedItems() {
        items = sortItems(persistence.loadItems())
        enforceItemLimit()
    }

    func capture(_ item: ClipboardItem) {
        var nextItems = items
        var capturedItem = item

        if nextItems.first?.contentHash == item.contentHash {
            return
        }

        if let duplicateIndex = nextItems.firstIndex(where: { $0.contentHash == item.contentHash }) {
            let duplicate = nextItems.remove(at: duplicateIndex)
            capturedItem.isPinned = duplicate.isPinned
            capturedItem.lastUsedAt = duplicate.lastUsedAt

            for oldAssetPath in duplicate.storedAssetPaths
                where capturedItem.storedAssetPaths.contains(oldAssetPath) == false
            {
                assetStore.deleteAsset(at: oldAssetPath)
            }
        }

        nextItems.insert(capturedItem, at: 0)
        nextItems = sortItems(nextItems)

        while nextItems.count > maxItems {
            let removed = nextItems.removeLast()
            removed.storedAssetPaths.forEach { assetStore.deleteAsset(at: $0) }
        }

        items = nextItems
        schedulePersist()
    }

    func markItemAsUsed(_ item: ClipboardItem) {
        guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        items[itemIndex].lastUsedAt = Date()
        items = sortItems(items)
        schedulePersist()
    }

    func togglePinned(_ item: ClipboardItem) {
        guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        items[itemIndex].isPinned.toggle()
        items[itemIndex].lastUsedAt = Date()
        items = sortItems(items)
        schedulePersist()
    }

    @discardableResult
    func remove(_ item: ClipboardItem) -> Bool {
        guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return false
        }

        let removedItem = items.remove(at: itemIndex)
        removedItem.storedAssetPaths.forEach { assetStore.deleteAsset(at: $0) }
        schedulePersist()
        return true
    }

    func search(matching query: String) -> [ClipboardItem] {
        let normalizedQuery =
            query
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

        guard normalizedQuery.isEmpty == false else {
            return items
        }

        return items.filter { item in
            item.searchableText.contains(normalizedQuery)
        }
    }

    func persistNow() {
        pendingPersistTask?.cancel()
        pendingPersistTask = nil
        try? persistence.save(items: items)
    }

    func clearAll() {
        pendingPersistTask?.cancel()
        pendingPersistTask = nil

        for item in items {
            item.storedAssetPaths.forEach { assetStore.deleteAsset(at: $0) }
        }

        items = []
        try? persistence.save(items: [])
    }

    func configure(maxItems: Int) {
        self.maxItems = max(20, maxItems)
        enforceItemLimit()
        schedulePersist()
    }

    private func schedulePersist() {
        pendingPersistTask?.cancel()
        let snapshot = items

        pendingPersistTask = Task.detached(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(200))

            guard Task.isCancelled == false else {
                return
            }

            let persistence = HistoryPersistence()
            try? persistence.save(items: snapshot)
        }
    }

    private func enforceItemLimit() {
        guard items.count > maxItems else {
            return
        }

        while items.count > maxItems {
            let removed = items.removeLast()
            removed.storedAssetPaths.forEach { assetStore.deleteAsset(at: $0) }
        }
    }

    private func sortItems(_ values: [ClipboardItem]) -> [ClipboardItem] {
        values.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && rhs.isPinned == false
            }

            return lhs.effectiveSortDate > rhs.effectiveSortDate
        }
    }
}
