import Foundation
import UIKit
import FirebaseStorage
import FirebaseFirestore

enum PortraitServiceError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        AppLanguage.localized("The image couldn't be processed, please try another photo.")
    }
}

@MainActor
final class PortraitService {
    private let storage = Storage.storage()

    /// Uploads the original untouched (per the app's zero-quality-loss rule)
    /// alongside a smaller display copy used for fast loading on the home
    /// screen, then points the couple doc at the display copy.
    @discardableResult
    func uploadPortrait(_ image: UIImage, coupleId: String) async throws -> String {
        guard let originalData = image.jpegData(compressionQuality: 1.0) else {
            throw PortraitServiceError.encodingFailed
        }
        guard let displayData = image.resized(maxDimension: 1600).jpegData(compressionQuality: 0.85) else {
            throw PortraitServiceError.encodingFailed
        }

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        let folder = storage.reference().child("couples/\(coupleId)/homePortrait")
        _ = try await folder.child("original.jpg").putDataAsync(originalData, metadata: metadata)
        _ = try await folder.child("display.jpg").putDataAsync(displayData, metadata: metadata)

        let displayPath = folder.child("display.jpg").fullPath
        try await Firestore.firestore().collection("couples").document(coupleId)
            .updateData(["homePortraitPath": displayPath])

        return displayPath
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
