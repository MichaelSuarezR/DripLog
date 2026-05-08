import UIKit

/// Shared in-memory image cache used for suggestion card images.
final class ImageCache {
    static let shared = ImageCache()

    private let cache: NSCache<NSURL, UIImage> = {
        let c = NSCache<NSURL, UIImage>()
        c.countLimit = 60
        c.totalCostLimit = 150 * 1024 * 1024 // 150 MB
        return c
    }()

    private init() {}

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    /// Downloads and caches an image if not already cached.
    /// Returns immediately if already in cache.
    @discardableResult
    func prefetch(url: URL) async -> UIImage? {
        if let cached = image(for: url) { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let img = UIImage(data: data) else { return nil }
        store(img, for: url)
        return img
    }

    /// Prefetches multiple URLs in parallel.
    func prefetch(urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask { await self.prefetch(url: url) }
            }
        }
    }
}
