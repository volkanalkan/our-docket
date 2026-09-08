import Foundation
import FirebaseFirestore

enum MediaType: String, Codable {
    case photo
    case video
}

enum CaseFileCategory: String, CaseIterable, Identifiable {
    case tatil = "Tatil"
    case ozelGun = "Özel Gün"
    case gunluk = "Günlük"
    case diger = "Diğer"

    var id: String { rawValue }
}

struct MediaItem: Codable, Identifiable {
    var id: String { storagePath }
    var storagePath: String
    var thumbnailPath: String
    var type: MediaType
    var uploadedAt: Timestamp
    var uploadedBy: String
}

struct CaseFile: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var createdBy: String
    @ServerTimestamp var createdAt: Timestamp?
    var category: String
    var mediaItems: [MediaItem]
}
