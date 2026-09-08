import UIKit

/// Every reopen of a case file was re-resolving each thumbnail's Storage
/// download URL and re-downloading its bytes from scratch, even for media
/// already seen this session. An in-memory cache keyed by storage path
/// skips both round-trips on repeat views; NSCache evicts under memory
/// pressure on its own, so there's no manual cap or invalidation to manage.
final class ImageCache {
    static let shared = ImageCache()

    private let imageCache = NSCache<NSString, UIImage>()
    private var resolvedURLs: [String: URL] = [:]

    func image(for key: String) -> UIImage? {
        imageCache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, for key: String) {
        imageCache.setObject(image, forKey: key as NSString)
    }

    func url(for key: String) -> URL? {
        resolvedURLs[key]
    }

    func setURL(_ url: URL, for key: String) {
        resolvedURLs[key] = url
    }
}
