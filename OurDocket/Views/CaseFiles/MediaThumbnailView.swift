import SwiftUI

struct MediaThumbnailView: View {
    let item: MediaItem
    let viewModel: CaseFilesViewModel

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Theme.navy.opacity(0.06)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                ProgressView()
            }

            if item.type == .video {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
        }
        .task(id: item.thumbnailPath) {
            await loadImage()
        }
    }

    private func loadImage() async {
        if let cached = ImageCache.shared.image(for: item.thumbnailPath) {
            image = cached
            return
        }
        do {
            let url: URL
            if let cachedURL = ImageCache.shared.url(for: item.thumbnailPath) {
                url = cachedURL
            } else {
                url = try await viewModel.downloadURL(for: item.thumbnailPath)
                ImageCache.shared.setURL(url, for: item.thumbnailPath)
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else { return }
            ImageCache.shared.setImage(uiImage, for: item.thumbnailPath)
            image = uiImage
        } catch {
            // Leave the placeholder up; the grid isn't the place to surface
            // a per-thumbnail network error.
        }
    }
}
