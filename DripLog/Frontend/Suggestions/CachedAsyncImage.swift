import SwiftUI
import UIKit

/// A SwiftUI image view that checks `ImageCache` first before hitting the network.
/// Shows a spinner while loading and a gray placeholder on failure.
struct CachedAsyncImage<Content: View>: View {
    let url: URL
    let showsLoadingIndicator: Bool
    let content: (Image) -> Content

    @State private var uiImage: UIImage?
    @State private var loadedURL: URL?
    @State private var failed = false

    init(
        url: URL,
        showsLoadingIndicator: Bool = true,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.url = url
        self.showsLoadingIndicator = showsLoadingIndicator
        self.content = content
    }

    var body: some View {
        Group {
            if loadedURL == url, let uiImage {
                content(Image(uiImage: uiImage))
            } else if let cached = ImageCache.shared.image(for: url) {
                content(Image(uiImage: cached))
            } else if failed {
                Color.black.opacity(0.10)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(.black.opacity(0.28))
                    }
            } else {
                Color.black.opacity(0.08)
                    .overlay {
                        if showsLoadingIndicator {
                            ProgressView()
                        }
                    }
            }
        }
        .task(id: url) {
            if loadedURL != url {
                uiImage = nil
                loadedURL = nil
                failed = false
            }

            if let cached = ImageCache.shared.image(for: url) {
                uiImage = cached
                loadedURL = url
                return
            }
            if let fetched = await ImageCache.shared.prefetch(url: url) {
                uiImage = fetched
                loadedURL = url
            } else {
                failed = true
            }
        }
    }
}
