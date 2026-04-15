import AppKit
import Foundation

/// In-memory cache for decoded clipboard thumbnails.
///
/// SwiftUI frequently recomputes views, which previously forced `NSImage(contentsOfFile:)`
/// to re-read and re-decode image files from disk on every row render and selection
/// change. This cache keeps decoded `NSImage` objects keyed by their on-disk path so the
/// main thread does not repeat the file I/O and decode work per frame.
final class ClipboardImageCache: @unchecked Sendable {
    static let shared = ClipboardImageCache()

    private let cache: NSCache<NSString, NSImage>

    init(countLimit: Int = 256) {
        cache = NSCache<NSString, NSImage>()
        cache.countLimit = countLimit
    }

    func image(forPath path: String) -> NSImage? {
        let key = path as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let image = NSImage(contentsOfFile: path) else {
            return nil
        }

        cache.setObject(image, forKey: key)
        return image
    }

    func invalidate(path: String) {
        cache.removeObject(forKey: path as NSString)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}
