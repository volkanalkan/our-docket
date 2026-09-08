import SwiftUI
import PhotosUI

struct PortraitCropView: View {
    let coupleId: String
    var onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var sourceImage: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isUploading = false
    @State private var errorMessage: String?

    private let frameSize = CGSize(width: 260, height: 260)

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    if let sourceImage {
                        cropArea(image: sourceImage)
                        Text("Konumlamak için sürükle, büyütmek için sıkıştır")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        PhotosPicker(selection: $photosPickerItem, matching: .images) {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 40))
                                Text("Fotoğraf Seç")
                            }
                            .foregroundStyle(Theme.navy)
                            .frame(width: frameSize.width, height: frameSize.height)
                            .background(Theme.navy.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Spacer()

                    if sourceImage != nil {
                        Button {
                            HapticFeedback.tap()
                            Task { await save() }
                        } label: {
                            Group {
                                if isUploading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Kaydet")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.navy)
                        .padding(.horizontal, 32)
                        .disabled(isUploading)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Fotoğrafı Ayarla")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { HapticFeedback.tap(); dismiss() }
                }
            }
            .onChange(of: photosPickerItem) { _, newValue in
                Task { await loadImage(from: newValue) }
            }
        }
    }

    private func cropArea(image: UIImage) -> some View {
        let dragGesture = DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = clampedOffset(for: image.size, scale: scale, offset: offset)
                withAnimation(.spring(duration: 0.25)) { offset = lastOffset }
            }

        let magnifyGesture = MagnificationGesture()
            .onChanged { value in
                scale = max(1, lastScale * value)
            }
            .onEnded { _ in
                lastScale = scale
                lastOffset = clampedOffset(for: image.size, scale: scale, offset: offset)
                withAnimation(.spring(duration: 0.25)) { offset = lastOffset }
            }

        return Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: frameSize.width, height: frameSize.height)
            .scaleEffect(scale)
            .offset(offset)
            .frame(width: frameSize.width, height: frameSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.gold, lineWidth: 2))
            .contentShape(Rectangle())
            .gesture(SimultaneousGesture(dragGesture, magnifyGesture))
    }

    /// Keeps the image edges from being dragged past the frame boundary.
    private func clampedOffset(for imageSize: CGSize, scale: CGFloat, offset: CGSize) -> CGSize {
        let fillScale = max(frameSize.width / imageSize.width, frameSize.height / imageSize.height) * scale
        let scaledSize = CGSize(width: imageSize.width * fillScale, height: imageSize.height * fillScale)
        let maxX = max(0, (scaledSize.width - frameSize.width) / 2)
        let maxY = max(0, (scaledSize.height - frameSize.height) / 2)
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        errorMessage = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Fotoğraf yüklenemedi."
                return
            }
            sourceImage = image
            scale = 1
            lastScale = 1
            offset = .zero
            lastOffset = .zero
        } catch {
            errorMessage = "Fotoğraf yüklenemedi."
        }
    }

    private func save() async {
        guard let sourceImage else { return }
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }

        let cropped = renderCroppedImage(source: sourceImage)
        do {
            try await PortraitService().uploadPortrait(cropped, coupleId: coupleId)
            HapticFeedback.success()
            onFinished()
        } catch {
            HapticFeedback.error()
            errorMessage = error.localizedDescription
        }
    }

    private func renderCroppedImage(source: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: frameSize)
        return renderer.image { _ in
            let fillScale = max(frameSize.width / source.size.width, frameSize.height / source.size.height) * scale
            let drawSize = CGSize(width: source.size.width * fillScale, height: source.size.height * fillScale)
            let origin = CGPoint(
                x: (frameSize.width - drawSize.width) / 2 + offset.width,
                y: (frameSize.height - drawSize.height) / 2 + offset.height
            )
            source.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
}

#Preview {
    PortraitCropView(coupleId: "preview") {}
}
