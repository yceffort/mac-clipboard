import AppKit
import Foundation

struct ClipboardAssetStore {
    func persistImageData(_ imageData: Data, fileExtension: String = "png") throws -> String {
        let sanitizedExtension = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedExtension = sanitizedExtension.isEmpty ? "png" : sanitizedExtension
        let fileURL = AppPaths.imagesDirectory().appendingPathComponent("\(UUID().uuidString).\(resolvedExtension)")
        try imageData.write(to: fileURL, options: .atomic)
        return fileURL.path
    }

    func persistRichTextData(_ data: Data) throws -> String {
        let fileURL = AppPaths.richTextDirectory().appendingPathComponent("\(UUID().uuidString).rtf")
        try data.write(to: fileURL, options: .atomic)
        return fileURL.path
    }

    func deleteAsset(at path: String?) {
        guard let path else {
            return
        }

        ClipboardImageCache.shared.invalidate(path: path)
        try? FileManager.default.removeItem(atPath: path)
    }
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiffRepresentation,
              let bitmapRepresentation = NSBitmapImageRep(data: tiffRepresentation)
        else {
            return nil
        }

        return bitmapRepresentation.representation(using: .png, properties: [:])
    }
}
