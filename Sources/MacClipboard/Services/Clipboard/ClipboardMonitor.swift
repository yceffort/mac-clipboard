import AppKit
import CryptoKit
import Foundation

@MainActor
final class ClipboardMonitor {
    private let pasteboard = NSPasteboard.general
    private let historyStore: HistoryStore
    private let settingsStore: AppSettingsStore
    private let assetStore = ClipboardAssetStore()

    private var timer: Timer?
    private var lastChangeCount: Int
    var loopProtector: ClipboardLoopProtector?

    var isRunning: Bool {
        timer != nil
    }

    init(historyStore: HistoryStore, settingsStore: AppSettingsStore) {
        self.historyStore = historyStore
        self.settingsStore = settingsStore
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else {
            return
        }

        timer = Timer.scheduledTimer(
            withTimeInterval: 0.6,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pollPasteboard()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func pollPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else {
            return
        }

        lastChangeCount = pasteboard.changeCount

        guard let item = makeClipboardItem() else {
            return
        }

        historyStore.capture(item)
    }

    private func makeClipboardItem() -> ClipboardItem? {
        if settingsStore.settings.privateModeEnabled {
            return nil
        }

        let sourceAppBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        if settingsStore.shouldIgnore(bundleID: sourceAppBundleID) {
            return nil
        }

        if let image = pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage,
           let imageData = image.pngData()
        {
            let hash = Self.hash(for: imageData)

            if loopProtector?.shouldIgnore(hash: hash) == true {
                return nil
            }

            do {
                let imagePath = try assetStore.persistImageData(imageData)
                return .image(
                    imagePath: imagePath,
                    contentHash: hash,
                    sourceAppBundleID: sourceAppBundleID
                )
            } catch {
                return nil
            }
        }

        if let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL],
            fileURLs.isEmpty == false
        {
            let paths = fileURLs.map(\.path)
            let hash = Self.hash(for: Data(paths.joined(separator: "\n").utf8))

            if loopProtector?.shouldIgnore(hash: hash) == true {
                return nil
            }

            return .files(
                paths: paths,
                contentHash: hash,
                sourceAppBundleID: sourceAppBundleID
            )
        }

        if let urlObjects = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urlObjects.first(where: { $0.isFileURL == false })
        {
            let value = url.absoluteString
            let hash = Self.hash(for: Data(value.utf8))

            if loopProtector?.shouldIgnore(hash: hash) == true {
                return nil
            }

            return .url(
                value: value,
                contentHash: hash,
                sourceAppBundleID: sourceAppBundleID
            )
        }

        if let htmlData = pasteboard.data(forType: .html),
           let htmlContent = String(data: htmlData, encoding: .utf8)
        {
            let hash = Self.hash(for: htmlData)

            if loopProtector?.shouldIgnore(hash: hash) == true {
                return nil
            }

            return .html(
                previewText: Self.previewText(from: htmlData, documentType: .html) ?? htmlContent,
                htmlContent: htmlContent,
                contentHash: hash,
                sourceAppBundleID: sourceAppBundleID
            )
        }

        if let rtfData = pasteboard.data(forType: .rtf) {
            let hash = Self.hash(for: rtfData)

            if loopProtector?.shouldIgnore(hash: hash) == true {
                return nil
            }

            do {
                let richTextPath = try assetStore.persistRichTextData(rtfData)
                return .richText(
                    previewText: Self.previewText(from: rtfData, documentType: .rtf) ?? "Rich text",
                    richTextPath: richTextPath,
                    contentHash: hash,
                    sourceAppBundleID: sourceAppBundleID
                )
            } catch {
                return nil
            }
        }

        if let text = pasteboard.string(forType: .string) {
            let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard normalizedText.isEmpty == false else {
                return nil
            }

            let hash = Self.hash(for: Data(normalizedText.utf8))

            if loopProtector?.shouldIgnore(hash: hash) == true {
                return nil
            }

            return .text(
                content: text,
                contentHash: hash,
                sourceAppBundleID: sourceAppBundleID
            )
        }

        return nil
    }

    private static func hash(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private static func previewText(from data: Data, documentType: NSAttributedString.DocumentType) -> String? {
        let attributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: documentType],
            documentAttributes: nil
        )

        return attributedString?.string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
