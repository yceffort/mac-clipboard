import AppKit
import CryptoKit
import Foundation

private enum ClipboardSnapshot {
    case image(data: Data, fileExtension: String, sourceAppBundleID: String?)
    case files(paths: [String], sourceAppBundleID: String?)
    case url(value: String, sourceAppBundleID: String?)
    case html(data: Data, sourceAppBundleID: String?)
    case richText(data: Data, sourceAppBundleID: String?)
    case text(content: String, normalizedText: String, sourceAppBundleID: String?)
}

@MainActor
final class ClipboardMonitor {
    private nonisolated static let activePollingInterval: TimeInterval = 0.25
    private nonisolated static let idlePollingInterval: TimeInterval = 0.9
    private nonisolated static let idlePollThreshold = 12
    private nonisolated static let previewParsingDataLimit = 256_000
    private nonisolated static let previewCharacterLimit = 4096
    private nonisolated static let htmlFallbackScanLimit = 16384

    private let pasteboard = NSPasteboard.general
    private let historyStore: HistoryStore
    private let settingsStore: AppSettingsStore
    private let assetStore = ClipboardAssetStore()
    private let processingQueue = DispatchQueue(
        label: "com.yceffort.clipboard.capture-processing",
        qos: .userInitiated
    )

    private var timer: Timer?
    private var lastChangeCount: Int
    private var currentPollingInterval: TimeInterval
    private var consecutiveIdlePolls = 0
    var loopProtector: ClipboardLoopProtector?

    var isRunning: Bool {
        timer != nil
    }

    init(historyStore: HistoryStore, settingsStore: AppSettingsStore) {
        self.historyStore = historyStore
        self.settingsStore = settingsStore
        lastChangeCount = pasteboard.changeCount
        currentPollingInterval = Self.activePollingInterval
    }

    func start() {
        guard timer == nil else {
            return
        }

        scheduleTimer(withInterval: currentPollingInterval)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        currentPollingInterval = Self.activePollingInterval
        consecutiveIdlePolls = 0
    }

    private func scheduleTimer(withInterval interval: TimeInterval) {
        timer?.invalidate()
        currentPollingInterval = interval

        let scheduledTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pollPasteboard()
            }
        }
        scheduledTimer.tolerance = interval * 0.25
        RunLoop.main.add(scheduledTimer, forMode: .common)
        timer = scheduledTimer
    }

    private func pollPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else {
            handleIdlePoll()
            return
        }

        lastChangeCount = pasteboard.changeCount
        consecutiveIdlePolls = 0

        if currentPollingInterval != Self.activePollingInterval {
            scheduleTimer(withInterval: Self.activePollingInterval)
        }

        guard let snapshot = makeClipboardSnapshot() else {
            return
        }

        process(snapshot)
    }

    private func handleIdlePoll() {
        consecutiveIdlePolls += 1

        guard
            consecutiveIdlePolls >= Self.idlePollThreshold,
            currentPollingInterval != Self.idlePollingInterval
        else {
            return
        }

        scheduleTimer(withInterval: Self.idlePollingInterval)
    }

    private func makeClipboardSnapshot() -> ClipboardSnapshot? {
        if settingsStore.settings.privateModeEnabled {
            return nil
        }

        let sourceAppBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        if settingsStore.shouldIgnore(bundleID: sourceAppBundleID) {
            return nil
        }

        if let pngData = pasteboard.data(forType: .png) {
            return .image(data: pngData, fileExtension: "png", sourceAppBundleID: sourceAppBundleID)
        }

        if let tiffData = pasteboard.data(forType: .tiff) {
            return .image(data: tiffData, fileExtension: "tiff", sourceAppBundleID: sourceAppBundleID)
        }

        if let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL],
            fileURLs.isEmpty == false
        {
            return .files(paths: fileURLs.map(\.path), sourceAppBundleID: sourceAppBundleID)
        }

        if let urlObjects = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urlObjects.first(where: { $0.isFileURL == false })
        {
            return .url(value: url.absoluteString, sourceAppBundleID: sourceAppBundleID)
        }

        if let htmlData = pasteboard.data(forType: .html) {
            return .html(data: htmlData, sourceAppBundleID: sourceAppBundleID)
        }

        if let rtfData = pasteboard.data(forType: .rtf) {
            return .richText(data: rtfData, sourceAppBundleID: sourceAppBundleID)
        }

        if let text = pasteboard.string(forType: .string) {
            let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard normalizedText.isEmpty == false else {
                return nil
            }

            return .text(
                content: text,
                normalizedText: normalizedText,
                sourceAppBundleID: sourceAppBundleID
            )
        }

        return nil
    }

    private func process(_ snapshot: ClipboardSnapshot) {
        let assetStore = assetStore
        let deliverItem: @Sendable (ClipboardItem) -> Void = { [weak self] item in
            Task { @MainActor [weak self] in
                guard let self else {
                    item.storedAssetPaths.forEach { assetStore.deleteAsset(at: $0) }
                    return
                }

                if self.loopProtector?.shouldIgnore(hash: item.contentHash) == true {
                    item.storedAssetPaths.forEach { assetStore.deleteAsset(at: $0) }
                    return
                }

                self.historyStore.capture(item)
            }
        }

        processingQueue.async {
            guard let item = Self.makeClipboardItem(from: snapshot, assetStore: assetStore) else {
                return
            }

            deliverItem(item)
        }
    }

    private nonisolated static func makeClipboardItem(
        from snapshot: ClipboardSnapshot,
        assetStore: ClipboardAssetStore
    ) -> ClipboardItem? {
        switch snapshot {
        case let .image(data, fileExtension, sourceAppBundleID):
            let hash = hash(for: data)

            do {
                let imagePath = try assetStore.persistImageData(data, fileExtension: fileExtension)
                return .image(
                    imagePath: imagePath,
                    contentHash: hash,
                    sourceAppBundleID: sourceAppBundleID
                )
            } catch {
                return nil
            }

        case let .files(paths, sourceAppBundleID):
            let hash = hash(for: Data(paths.joined(separator: "\n").utf8))
            return .files(
                paths: paths,
                contentHash: hash,
                sourceAppBundleID: sourceAppBundleID
            )

        case let .url(value, sourceAppBundleID):
            let hash = hash(for: Data(value.utf8))
            return .url(
                value: value,
                contentHash: hash,
                sourceAppBundleID: sourceAppBundleID
            )

        case let .html(data, sourceAppBundleID):
            let hash = hash(for: data)
            guard let htmlContent = String(data: data, encoding: .utf8) else {
                return nil
            }

            return .html(
                previewText: htmlPreviewText(from: data, htmlContent: htmlContent),
                htmlContent: htmlContent,
                contentHash: hash,
                sourceAppBundleID: sourceAppBundleID
            )

        case let .richText(data, sourceAppBundleID):
            let hash = hash(for: data)

            do {
                let richTextPath = try assetStore.persistRichTextData(data)
                return .richText(
                    previewText: richTextPreviewText(from: data),
                    richTextPath: richTextPath,
                    contentHash: hash,
                    sourceAppBundleID: sourceAppBundleID
                )
            } catch {
                return nil
            }

        case let .text(content, normalizedText, sourceAppBundleID):
            let hash = hash(for: Data(normalizedText.utf8))
            return .text(
                content: content,
                contentHash: hash,
                sourceAppBundleID: sourceAppBundleID
            )
        }
    }

    private nonisolated static func hash(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private nonisolated static func htmlPreviewText(from data: Data, htmlContent: String) -> String {
        if data.count > previewParsingDataLimit {
            return fallbackHTMLPreview(from: htmlContent)
        }

        return normalizedPreviewText(
            from: previewText(from: data, documentType: .html) ?? fallbackHTMLPreview(from: htmlContent),
            fallback: "HTML content"
        )
    }

    private nonisolated static func richTextPreviewText(from data: Data) -> String {
        guard data.count <= previewParsingDataLimit else {
            return "Large rich text content"
        }

        return normalizedPreviewText(
            from: previewText(from: data, documentType: .rtf),
            fallback: "Rich text"
        )
    }

    private nonisolated static func previewText(
        from data: Data,
        documentType: NSAttributedString.DocumentType
    ) -> String? {
        let attributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: documentType],
            documentAttributes: nil
        )

        return attributedString?.string
    }

    private nonisolated static func fallbackHTMLPreview(from htmlContent: String) -> String {
        let sample = String(htmlContent.prefix(Self.htmlFallbackScanLimit))
        let strippedTags = sample.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        let decodedEntities =
            strippedTags
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")

        return normalizedPreviewText(from: decodedEntities, fallback: "HTML content")
    }

    private nonisolated static func normalizedPreviewText(from text: String?, fallback: String) -> String {
        guard let text else {
            return fallback
        }

        let normalized =
            text
                .replacingOccurrences(of: "\u{00A0}", with: " ")
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.isEmpty == false }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.isEmpty == false else {
            return fallback
        }

        if normalized.count <= Self.previewCharacterLimit {
            return normalized
        }

        return String(normalized.prefix(Self.previewCharacterLimit)) + "..."
    }
}
