import Foundation
import SwiftUI
import UIKit
import AVFoundation
import PhotosUI
import FirebaseFirestore
import FirebaseStorage

enum CaseFileServiceError: LocalizedError {
    case unsupportedMedia
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedMedia:
            return "Bu dosya türü desteklenmiyor."
        case .encodingFailed:
            return "Medya işlenemedi, lütfen tekrar dene."
        }
    }
}

@MainActor
final class CaseFileService {
    private let storage = Storage.storage()

    private func caseFilesCollection(coupleId: String) -> CollectionReference {
        Firestore.firestore().collection("couples").document(coupleId).collection("caseFiles")
    }

    func createCaseFile(coupleId: String, title: String, category: String, createdBy: String) async throws -> String {
        let newFile = CaseFile(title: title, createdBy: createdBy, category: category, mediaItems: [])
        let ref = caseFilesCollection(coupleId: coupleId).document()
        try await ref.setData(from: newFile)
        return ref.documentID
    }

    /// Uploads the original file untouched (per the app's zero-quality-loss
    /// rule) alongside a small thumbnail for the gallery grid, then appends
    /// the resulting MediaItem to the case file's mediaItems array.
    func uploadMedia(_ item: PhotosPickerItem, coupleId: String, fileId: String, uploadedBy: String) async throws {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw CaseFileServiceError.unsupportedMedia
        }

        let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
        let mediaId = UUID().uuidString
        let folder = storage.reference().child("couples/\(coupleId)/caseFiles/\(fileId)")

        let mediaItem: MediaItem
        if isVideo {
            mediaItem = try await uploadVideo(data: data, mediaId: mediaId, folder: folder, uploadedBy: uploadedBy)
        } else {
            mediaItem = try await uploadImage(data: data, mediaId: mediaId, folder: folder, uploadedBy: uploadedBy)
        }

        let encoded = try Firestore.Encoder().encode(mediaItem)
        try await caseFilesCollection(coupleId: coupleId).document(fileId)
            .updateData(["mediaItems": FieldValue.arrayUnion([encoded])])
    }

    private func uploadImage(data: Data, mediaId: String, folder: StorageReference, uploadedBy: String) async throws -> MediaItem {
        guard let image = UIImage(data: data) else {
            throw CaseFileServiceError.unsupportedMedia
        }
        guard let thumbnailData = image.resized(maxDimension: 600).jpegData(compressionQuality: 0.8) else {
            throw CaseFileServiceError.encodingFailed
        }

        let originalMetadata = StorageMetadata()
        originalMetadata.contentType = "image/jpeg"
        let thumbnailMetadata = StorageMetadata()
        thumbnailMetadata.contentType = "image/jpeg"

        let originalRef = folder.child("\(mediaId)/original.jpg")
        let thumbnailRef = folder.child("\(mediaId)/thumbnail.jpg")

        _ = try await originalRef.putDataAsync(data, metadata: originalMetadata)
        _ = try await thumbnailRef.putDataAsync(thumbnailData, metadata: thumbnailMetadata)

        return MediaItem(
            storagePath: originalRef.fullPath,
            thumbnailPath: thumbnailRef.fullPath,
            type: .photo,
            uploadedAt: Timestamp(date: .now),
            uploadedBy: uploadedBy
        )
    }

    private func uploadVideo(data: Data, mediaId: String, folder: StorageReference, uploadedBy: String) async throws -> MediaItem {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(mediaId).mov")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let thumbnailImage = try await Self.extractVideoThumbnail(url: tempURL)
        guard let thumbnailData = thumbnailImage.resized(maxDimension: 600).jpegData(compressionQuality: 0.8) else {
            throw CaseFileServiceError.encodingFailed
        }

        let originalMetadata = StorageMetadata()
        originalMetadata.contentType = "video/quicktime"
        let thumbnailMetadata = StorageMetadata()
        thumbnailMetadata.contentType = "image/jpeg"

        let originalRef = folder.child("\(mediaId)/original.mov")
        let thumbnailRef = folder.child("\(mediaId)/thumbnail.jpg")

        _ = try await originalRef.putDataAsync(data, metadata: originalMetadata)
        _ = try await thumbnailRef.putDataAsync(thumbnailData, metadata: thumbnailMetadata)

        return MediaItem(
            storagePath: originalRef.fullPath,
            thumbnailPath: thumbnailRef.fullPath,
            type: .video,
            uploadedAt: Timestamp(date: .now),
            uploadedBy: uploadedBy
        )
    }

    private static func extractVideoThumbnail(url: URL) async throws -> UIImage {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let cgImage = try await generator.image(at: .zero).image
        return UIImage(cgImage: cgImage)
    }

    func downloadURL(for path: String) async throws -> URL {
        try await storage.reference(withPath: path).downloadURL()
    }
}

private extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension else { return self }

        let scale = maxDimension / largestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
