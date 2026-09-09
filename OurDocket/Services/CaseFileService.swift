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
            return AppLanguage.localized("This file type isn't supported.")
        case .encodingFailed:
            return AppLanguage.localized("The media couldn't be processed, please try again.")
        }
    }
}

@MainActor
final class CaseFileService {
    private let storage = Storage.storage()

    private func caseFilesCollection(coupleId: String) -> CollectionReference {
        Firestore.firestore().collection("couples").document(coupleId).collection("caseFiles")
    }

    private func categoriesCollection(coupleId: String) -> CollectionReference {
        Firestore.firestore().collection("couples").document(coupleId).collection("caseFileCategories")
    }

    func createCaseFile(
        coupleId: String,
        title: String,
        category: String,
        createdBy: String,
        iconName: String,
        colorHex: String,
        eventStartDate: Date?,
        eventEndDate: Date?
    ) async throws -> String {
        let newFile = CaseFile(
            title: title,
            createdBy: createdBy,
            category: category,
            mediaItems: [],
            iconName: iconName,
            colorHex: colorHex,
            eventStartDate: eventStartDate.map(Timestamp.init(date:)),
            eventEndDate: eventEndDate.map(Timestamp.init(date:))
        )
        let ref = caseFilesCollection(coupleId: coupleId).document()
        try await ref.setData(from: newFile)
        return ref.documentID
    }

    func updateCaseFile(
        coupleId: String,
        fileId: String,
        title: String,
        category: String,
        iconName: String,
        colorHex: String,
        eventStartDate: Date?,
        eventEndDate: Date?
    ) async throws {
        try await caseFilesCollection(coupleId: coupleId).document(fileId).updateData([
            "title": title,
            "category": category,
            "iconName": iconName,
            "colorHex": colorHex,
            "eventStartDate": eventStartDate.map(Timestamp.init(date:)) as Any,
            "eventEndDate": eventEndDate.map(Timestamp.init(date:)) as Any
        ])
    }

    func deleteCaseFile(coupleId: String, fileId: String) async throws {
        try await caseFilesCollection(coupleId: coupleId).document(fileId).delete()
    }

    func deleteMedia(_ item: MediaItem, coupleId: String, fileId: String) async throws {
        let encoded = try Firestore.Encoder().encode(item)
        try await caseFilesCollection(coupleId: coupleId).document(fileId)
            .updateData(["mediaItems": FieldValue.arrayRemove([encoded])])
        try? await storage.reference(withPath: item.storagePath).delete()
        try? await storage.reference(withPath: item.thumbnailPath).delete()
    }

    // MARK: - Categories

    func ensureDefaultCategories(coupleId: String) async throws {
        let snapshot = try await categoriesCollection(coupleId: coupleId).limit(to: 1).getDocuments()
        guard snapshot.documents.isEmpty else { return }
        for name in CaseFileCategoryOption.defaultNames {
            try await createCategory(coupleId: coupleId, name: name)
        }
    }

    @discardableResult
    func createCategory(coupleId: String, name: String) async throws -> String {
        let ref = categoriesCollection(coupleId: coupleId).document()
        try await ref.setData(from: CaseFileCategoryOption(name: name))
        return ref.documentID
    }

    func renameCategory(coupleId: String, categoryId: String, newName: String) async throws {
        try await categoriesCollection(coupleId: coupleId).document(categoryId).updateData(["name": newName])
    }

    func deleteCategory(coupleId: String, categoryId: String) async throws {
        try await categoriesCollection(coupleId: coupleId).document(categoryId).delete()
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
