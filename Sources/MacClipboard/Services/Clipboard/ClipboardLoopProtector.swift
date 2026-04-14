import Foundation

@MainActor
final class ClipboardLoopProtector {
    private var ignoredHashes: [String: Date] = [:]
    private let protectionWindow: TimeInterval = 2.0

    func registerRestoredHash(_ hash: String) {
        pruneExpiredEntries()
        ignoredHashes[hash] = Date().addingTimeInterval(protectionWindow)
    }

    func shouldIgnore(hash: String) -> Bool {
        pruneExpiredEntries()

        guard let expiration = ignoredHashes[hash], expiration > Date() else {
            ignoredHashes.removeValue(forKey: hash)
            return false
        }

        ignoredHashes.removeValue(forKey: hash)
        return true
    }

    private func pruneExpiredEntries() {
        let now = Date()
        ignoredHashes = ignoredHashes.filter { $0.value > now }
    }
}
