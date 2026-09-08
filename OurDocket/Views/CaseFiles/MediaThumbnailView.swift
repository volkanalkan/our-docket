import SwiftUI

struct MediaThumbnailView: View {
    let item: MediaItem
    let viewModel: CaseFilesViewModel

    @State private var url: URL?

    var body: some View {
        ZStack {
            Theme.navy.opacity(0.06)

            if let url {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .clipped()
            }

            if item.type == .video {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
        }
        .task {
            url = try? await viewModel.downloadURL(for: item.thumbnailPath)
        }
    }
}
