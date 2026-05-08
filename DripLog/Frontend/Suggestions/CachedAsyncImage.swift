import SwiftUI
import UIKit

/// A SwiftUI image view that checks `ImageCache` first before hitting the network.
/// Shows a spinner while loading and a gray placeholder on failure.
struct CachedAsyncImage<Content: View>: View {
    let url: URL
    let content: (Image) -> Content

    @State private var uiImage: UIImage?
    @State private var failed = false

    init(url: URL, @ViewBuilder content: @escaping (Image) -> Content) {
        self.url = url
        self.content = content
    }

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else if failed {
                Color.black.opacity(0.10)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(.black.opacity(0.28))
                    }
            } else {
                Color.black.opacity(0.08)
                    .overlay { ProgressView() }
            }
        }
        .task(id: url) {
            if let cached = ImageCache.shared.image(for: url) {
                uiImage = cached
                return
            }
            if let fetched = await ImageCache.shared.prefetch(url: url) {
                uiImage = fetched
            } else {
                failed = true
            }
        }
    }
}
