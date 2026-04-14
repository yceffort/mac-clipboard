import Foundation

enum ClipboardItemKind: String, Codable {
    case text
    case image
    case url
    case file
    case html
    case richText
}

struct ClipboardItem: Codable, Identifiable, Hashable {
    var id: UUID
    var kind: ClipboardItemKind
    var createdAt: Date
    var lastUsedAt: Date?
    var contentHash: String
    var textContent: String?
    var imagePath: String?
    var sourceAppBundleID: String?
    var isPinned: Bool
    var urlString: String?
    var filePaths: [String]
    var htmlContent: String?
    var richTextPath: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case createdAt
        case lastUsedAt
        case contentHash
        case textContent
        case imagePath
        case sourceAppBundleID
        case isPinned
        case urlString
        case filePaths
        case htmlContent
        case richTextPath
    }

    init(
        id: UUID,
        kind: ClipboardItemKind,
        createdAt: Date,
        lastUsedAt: Date?,
        contentHash: String,
        textContent: String?,
        imagePath: String?,
        sourceAppBundleID: String?,
        isPinned: Bool,
        urlString: String?,
        filePaths: [String],
        htmlContent: String?,
        richTextPath: String?
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.contentHash = contentHash
        self.textContent = textContent
        self.imagePath = imagePath
        self.sourceAppBundleID = sourceAppBundleID
        self.isPinned = isPinned
        self.urlString = urlString
        self.filePaths = filePaths
        self.htmlContent = htmlContent
        self.richTextPath = richTextPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(ClipboardItemKind.self, forKey: .kind)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        contentHash = try container.decode(String.self, forKey: .contentHash)
        textContent = try container.decodeIfPresent(String.self, forKey: .textContent)
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        sourceAppBundleID = try container.decodeIfPresent(String.self, forKey: .sourceAppBundleID)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        urlString = try container.decodeIfPresent(String.self, forKey: .urlString)
        filePaths = try container.decodeIfPresent([String].self, forKey: .filePaths) ?? []
        htmlContent = try container.decodeIfPresent(String.self, forKey: .htmlContent)
        richTextPath = try container.decodeIfPresent(String.self, forKey: .richTextPath)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(lastUsedAt, forKey: .lastUsedAt)
        try container.encode(contentHash, forKey: .contentHash)
        try container.encodeIfPresent(textContent, forKey: .textContent)
        try container.encodeIfPresent(imagePath, forKey: .imagePath)
        try container.encodeIfPresent(sourceAppBundleID, forKey: .sourceAppBundleID)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encodeIfPresent(urlString, forKey: .urlString)
        try container.encode(filePaths, forKey: .filePaths)
        try container.encodeIfPresent(htmlContent, forKey: .htmlContent)
        try container.encodeIfPresent(richTextPath, forKey: .richTextPath)
    }

    var effectiveSortDate: Date {
        lastUsedAt ?? createdAt
    }

    var storedAssetPaths: [String] {
        [imagePath, richTextPath].compactMap(\.self)
    }

    var fileNames: [String] {
        filePaths.map { URL(fileURLWithPath: $0).lastPathComponent }
    }

    var searchableText: String {
        [
            textContent,
            sourceAppBundleID,
            displayTitle,
            urlString,
            fileNames.joined(separator: " "),
        ]
        .compactMap(\.self)
        .joined(separator: " ")
        .lowercased()
    }

    var displayTitle: String {
        switch kind {
        case .text:
            let candidate = textContent?
                .split(whereSeparator: { $0.isNewline })
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let candidate, candidate.isEmpty == false {
                return String(candidate.prefix(70))
            }

            return "Text snippet"

        case .image:
            return "Image"

        case .url:
            return urlString ?? "URL"

        case .file:
            if fileNames.count == 1 {
                return fileNames[0]
            }

            if fileNames.isEmpty == false {
                return "\(fileNames.count) files"
            }

            return "Files"

        case .html:
            return firstMeaningfulLine(from: textContent) ?? "HTML snippet"

        case .richText:
            return firstMeaningfulLine(from: textContent) ?? "Rich text"
        }
    }

    var displaySubtitle: String {
        switch kind {
        case .text:
            guard let textContent else {
                return "Empty text item"
            }

            let singleLine =
                textContent
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

            if singleLine.count <= 90 {
                return singleLine
            }

            return String(singleLine.prefix(90)) + "..."

        case .image:
            if let sourceAppBundleID {
                return sourceAppBundleID
            }

            return "Copied image"

        case .url:
            return urlString ?? sourceAppBundleID ?? "Copied URL"

        case .file:
            if fileNames.isEmpty {
                return "Copied file"
            }

            return fileNames.joined(separator: ", ")

        case .html:
            return condensedPreviewText(from: textContent) ?? sourceAppBundleID ?? "Copied HTML"

        case .richText:
            return condensedPreviewText(from: textContent) ?? sourceAppBundleID ?? "Copied rich text"
        }
    }

    var symbolName: String {
        switch kind {
        case .text:
            "text.alignleft"
        case .image:
            "photo"
        case .url:
            "link"
        case .file:
            "doc"
        case .html:
            "chevron.left.forwardslash.chevron.right"
        case .richText:
            "text.quote"
        }
    }

    var kindLabel: String {
        switch kind {
        case .text:
            "Text"
        case .image:
            "Image"
        case .url:
            "URL"
        case .file:
            filePaths.count == 1 ? "File" : "Files"
        case .html:
            "HTML"
        case .richText:
            "Rich Text"
        }
    }

    static func text(
        content: String,
        contentHash: String,
        sourceAppBundleID: String?
    ) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .text,
            createdAt: Date(),
            lastUsedAt: nil,
            contentHash: contentHash,
            textContent: content,
            imagePath: nil,
            sourceAppBundleID: sourceAppBundleID,
            isPinned: false,
            urlString: nil,
            filePaths: [],
            htmlContent: nil,
            richTextPath: nil
        )
    }

    static func image(
        imagePath: String,
        contentHash: String,
        sourceAppBundleID: String?
    ) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .image,
            createdAt: Date(),
            lastUsedAt: nil,
            contentHash: contentHash,
            textContent: nil,
            imagePath: imagePath,
            sourceAppBundleID: sourceAppBundleID,
            isPinned: false,
            urlString: nil,
            filePaths: [],
            htmlContent: nil,
            richTextPath: nil
        )
    }

    static func url(
        value: String,
        contentHash: String,
        sourceAppBundleID: String?
    ) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .url,
            createdAt: Date(),
            lastUsedAt: nil,
            contentHash: contentHash,
            textContent: value,
            imagePath: nil,
            sourceAppBundleID: sourceAppBundleID,
            isPinned: false,
            urlString: value,
            filePaths: [],
            htmlContent: nil,
            richTextPath: nil
        )
    }

    static func files(
        paths: [String],
        contentHash: String,
        sourceAppBundleID: String?
    ) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .file,
            createdAt: Date(),
            lastUsedAt: nil,
            contentHash: contentHash,
            textContent: paths.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: "\n"),
            imagePath: nil,
            sourceAppBundleID: sourceAppBundleID,
            isPinned: false,
            urlString: nil,
            filePaths: paths,
            htmlContent: nil,
            richTextPath: nil
        )
    }

    static func html(
        previewText: String,
        htmlContent: String,
        contentHash: String,
        sourceAppBundleID: String?
    ) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .html,
            createdAt: Date(),
            lastUsedAt: nil,
            contentHash: contentHash,
            textContent: previewText,
            imagePath: nil,
            sourceAppBundleID: sourceAppBundleID,
            isPinned: false,
            urlString: nil,
            filePaths: [],
            htmlContent: htmlContent,
            richTextPath: nil
        )
    }

    static func richText(
        previewText: String,
        richTextPath: String,
        contentHash: String,
        sourceAppBundleID: String?
    ) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .richText,
            createdAt: Date(),
            lastUsedAt: nil,
            contentHash: contentHash,
            textContent: previewText,
            imagePath: nil,
            sourceAppBundleID: sourceAppBundleID,
            isPinned: false,
            urlString: nil,
            filePaths: [],
            htmlContent: nil,
            richTextPath: richTextPath
        )
    }

    private func firstMeaningfulLine(from text: String?) -> String? {
        text?
            .split(whereSeparator: { $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { $0.isEmpty == false })
            .map { String($0) }
    }

    private func condensedPreviewText(from text: String?) -> String? {
        guard let text else {
            return nil
        }

        let singleLine =
            text
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

        guard singleLine.isEmpty == false else {
            return nil
        }

        if singleLine.count <= 90 {
            return singleLine
        }

        return String(singleLine.prefix(90)) + "..."
    }
}
