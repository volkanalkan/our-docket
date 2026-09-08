import SwiftUI
import PhotosUI

struct CaseFileDetailView: View {
    let coupleId: String
    @ObservedObject var viewModel: CaseFilesViewModel
    let file: CaseFile

    private enum MediaSort: String, CaseIterable, Identifiable {
        case newestFirst = "Yeniden Eskiye"
        case oldestFirst = "Eskiden Yeniye"
        case shuffled = "Karışık"
        var id: String { rawValue }
    }

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var selectedMediaItem: MediaItem?
    @State private var deletingMediaItem: MediaItem?
    @State private var sort: MediaSort = .newestFirst
    @State private var shuffleSeed = UUID()
    @State private var columnCount = 3

    private var currentFile: CaseFile {
        viewModel.caseFiles.first(where: { $0.id == file.id }) ?? file
    }

    private var sortedMedia: [MediaItem] {
        switch sort {
        case .newestFirst:
            return currentFile.mediaItems.sorted { $0.uploadedAt.dateValue() > $1.uploadedAt.dateValue() }
        case .oldestFirst:
            return currentFile.mediaItems.sorted { $0.uploadedAt.dateValue() < $1.uploadedAt.dateValue() }
        case .shuffled:
            var generator = SeededGenerator(seed: shuffleSeed)
            return currentFile.mediaItems.shuffled(using: &generator)
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: columnCount)
    }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderBar(title: currentFile.title) {
                    Menu {
                        ForEach(MediaSort.allCases) { option in
                            Button {
                                HapticFeedback.selection()
                                if option == .shuffled { shuffleSeed = UUID() }
                                sort = option
                            } label: {
                                Label(option.rawValue, systemImage: sort == option ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.navy)
                            .frame(width: 36, height: 36)
                            .background(Theme.navy.opacity(0.08), in: Circle())
                    }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(currentFile.category)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.navy.opacity(0.08))
                                .clipShape(Capsule())
                                .foregroundStyle(Theme.navy)
                        }
                        .padding(.horizontal)

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }

                        LazyVGrid(columns: columns, spacing: 4) {
                            PhotosPicker(selection: $selectedPickerItems, matching: .any(of: [.images, .videos])) {
                                squareCell {
                                    ZStack {
                                        Theme.navy.opacity(0.06)
                                        if isUploading {
                                            ProgressView()
                                        } else {
                                            Image(systemName: "plus")
                                                .font(.title2)
                                                .foregroundStyle(Theme.navy)
                                        }
                                    }
                                }
                            }
                            .disabled(isUploading)

                            ForEach(sortedMedia) { item in
                                squareCell {
                                    MediaThumbnailView(item: item, viewModel: viewModel)
                                }
                                .onTapGesture {
                                    HapticFeedback.tap()
                                    selectedMediaItem = item
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deletingMediaItem = item
                                    } label: {
                                        Label("Sil", systemImage: "trash")
                                    }
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 4)
                        .animation(.default, value: currentFile.mediaItems.count)
                        .gesture(pinchToResizeGrid)
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationBarHidden(true)
        .onChange(of: selectedPickerItems) { _, newItems in
            guard !newItems.isEmpty, let uid = authViewModel.currentUserId, let fileId = file.id else { return }
            Task {
                isUploading = true
                await viewModel.uploadMedia(newItems, fileId: fileId, uploadedBy: uid)
                selectedPickerItems = []
                isUploading = false
                if viewModel.errorMessage == nil {
                    HapticFeedback.success()
                } else {
                    HapticFeedback.error()
                }
            }
        }
        .fullScreenCover(item: $selectedMediaItem) { item in
            MediaViewerView(item: item, viewModel: viewModel) {
                deletingMediaItem = item
                selectedMediaItem = nil
            }
        }
        .confirmationDialog(
            "Bu fotoğrafı/videoyu silmek istediğine emin misin?",
            isPresented: Binding(get: { deletingMediaItem != nil }, set: { if !$0 { deletingMediaItem = nil } }),
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) {
                if let deletingMediaItem {
                    HapticFeedback.tap()
                    Task { await viewModel.deleteMedia(deletingMediaItem, from: currentFile) }
                }
                deletingMediaItem = nil
            }
            Button("İptal", role: .cancel) { deletingMediaItem = nil }
        }
    }

    /// Pinching out (fingers apart) reveals fewer, larger tiles; pinching in
    /// shows more, smaller tiles at once — the same relationship Photos
    /// uses, implemented here as discrete column-count steps rather than a
    /// continuously-resizing grid.
    private var pinchToResizeGrid: some Gesture {
        MagnificationGesture()
            .onEnded { value in
                withAnimation(.default) {
                    if value > 1.15 {
                        columnCount = max(2, columnCount - 1)
                    } else if value < 0.85 {
                        columnCount = min(6, columnCount + 1)
                    }
                }
            }
    }

    private func squareCell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let built = content()
        return GeometryReader { geometry in
            built
                .frame(width: geometry.size.width, height: geometry.size.width)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// A tiny deterministic PRNG so "shuffled" order stays stable across view
/// updates within the same shuffleSeed instead of re-randomizing on every
/// re-render (which would make thumbnails visibly jump around).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UUID) {
        state = UInt64(bitPattern: Int64(seed.hashValue))
        if state == 0 { state = 0x9E3779B97F4A7C15 }
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
