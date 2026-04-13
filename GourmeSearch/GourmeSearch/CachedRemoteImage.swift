import SwiftUI
import UIKit
import Combine

@MainActor
final class RemoteImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?

    private static let cache = NSCache<NSURL, UIImage>()

    func load(from url: URL?) async {
        guard let url else {
            image = nil
            return
        }

        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return
            }
            guard let loaded = UIImage(data: data) else {
                return
            }

            Self.cache.setObject(loaded, forKey: url as NSURL, cost: data.count)
            image = loaded
        } catch let error {
#if DEBUG
            print("RemoteImageLoader failed: \(error.localizedDescription)")
#endif
        }
    }
}

struct CachedRemoteImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @StateObject private var loader = RemoteImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loader.load(from: url)
        }
    }
}
