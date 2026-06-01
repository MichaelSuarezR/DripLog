import ImageIO
import UIKit

/// Shared in-memory image cache used for suggestion card images.
final class ImageCache {
    static let shared = ImageCache()

    private var pinnedImages: [NSURL: UIImage] = [:]
    private let pinnedImagesLock = NSLock()

    private let cache: NSCache<NSURL, UIImage> = {
        let c = NSCache<NSURL, UIImage>()
        c.countLimit = 30
        c.totalCostLimit = 80 * 1024 * 1024 // 80 MB
        return c
    }()

    private init() {}

    func image(for url: URL) -> UIImage? {
        let key = url as NSURL
        pinnedImagesLock.lock()
        let pinnedImage = pinnedImages[key]
        pinnedImagesLock.unlock()
        return pinnedImage ?? cache.object(forKey: key)
    }

    func store(_ image: UIImage, for url: URL) {
        let pixelWidth = image.cgImage?.width ?? Int(image.size.width * image.scale)
        let pixelHeight = image.cgImage?.height ?? Int(image.size.height * image.scale)
        let cost = pixelWidth * pixelHeight * 4
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    func pin(_ image: UIImage, for url: URL) {
        let key = url as NSURL
        pinnedImagesLock.lock()
        pinnedImages[key] = image
        pinnedImagesLock.unlock()
        store(image, for: url)
    }

    /// Downloads and caches an image if not already cached.
    /// Returns immediately if already in cache.
    @discardableResult
    func prefetch(url: URL) async -> UIImage? {
        if let cached = image(for: url) { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let img = Self.downsampleImage(data: data, maxPixelSize: 1600) else { return nil }
        store(img, for: url)
        return img
    }

    @discardableResult
    func prefetchAndPin(url: URL) async -> UIImage? {
        guard let image = await prefetch(url: url) else { return nil }
        pin(image, for: url)
        return image
    }

    /// Prefetches multiple URLs in parallel.
    func prefetch(urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls.prefix(12) {
                group.addTask { await self.prefetch(url: url) }
            }
        }
    }

    func prefetchAndPin(urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls.prefix(24) {
                group.addTask { await self.prefetchAndPin(url: url) }
            }
        }
    }

    private static func downsampleImage(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
            return UIImage(data: data)
        }

        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
            return UIImage(data: data)
        }

        return UIImage(cgImage: cgImage)
    }
}
