import SwiftUI
import AVKit

struct MediaViewerView: View {
    let item: MediaItem
    let viewModel: CaseFilesViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var url: URL?
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if item.type == .video, let player {
                VideoPlayer(player: player)
                    .onDisappear { player.pause() }
            } else if let url {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView().tint(.white)
                }
            } else {
                ProgressView().tint(.white)
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .task {
            guard let resolvedURL = try? await viewModel.downloadURL(for: item.storagePath) else { return }
            url = resolvedURL
            if item.type == .video {
                player = AVPlayer(url: resolvedURL)
            }
        }
    }
}
