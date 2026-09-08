import SwiftUI
import PhotosUI

struct CaseFileDetailView: View {
    let coupleId: String
    @ObservedObject var viewModel: CaseFilesViewModel
    let file: CaseFile
    let fileNumber: Int

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var selectedMediaItem: MediaItem?

    private var currentFile: CaseFile {
        viewModel.caseFiles.first(where: { $0.id == file.id }) ?? file
    }

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 4)]

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dosya No: \(String(format: "%03d", fileNumber))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(currentFile.title)
                            .font(.system(.title2, design: .serif, weight: .bold))
                            .foregroundStyle(Theme.navy)
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

                        ForEach(currentFile.mediaItems) { item in
                            squareCell {
                                MediaThumbnailView(item: item, viewModel: viewModel)
                            }
                            .onTapGesture {
                                HapticFeedback.tap()
                                selectedMediaItem = item
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 4)
                    .animation(.default, value: currentFile.mediaItems.count)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Dosya")
        .navigationBarTitleDisplayMode(.inline)
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
            MediaViewerView(item: item, viewModel: viewModel)
        }
    }

    /// Forces its content into a square that matches the grid column width,
    /// regardless of the content's own intrinsic size (an oversized source
    /// image would otherwise balloon its cell — content must be `.clipped()`
    /// internally too, since the shape below only clips the cell's edges).
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
