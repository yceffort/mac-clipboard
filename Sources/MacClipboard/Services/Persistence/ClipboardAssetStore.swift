import AppKit
import Foundation

struct ClipboardAssetStore {
    func persistImageData(_ imageData: Data) throws -> String {
        let fileURL = AppPaths.imagesDirectory().appendingPathComponent("\(UUID().uuidString).png")
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
