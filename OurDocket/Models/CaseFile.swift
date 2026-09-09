import Foundation
import FirebaseFirestore

enum MediaType: String, Codable {
    case photo
    case video
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
    var iconName: String
    var colorHex: String
    /// Both nil means "no date" (sorts to the bottom of the timeline).
    /// eventEndDate equal to eventStartDate represents a single day;
    /// a later eventEndDate represents a range (e.g. a week-long trip).
    var eventStartDate: Timestamp?
    var eventEndDate: Timestamp?
}

/// A couple's case-file categories are editable, but every couple starts
/// with the same native defaults — stored per-couple in Firestore rather
/// than hardcoded, so editing one couple's list can't affect anyone else's.
struct CaseFileCategoryOption: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    @ServerTimestamp var createdAt: Timestamp?

    /// Resolved in the couple's language at bootstrap time; these are
    /// persisted data afterwards, not UI strings, so they don't follow
    /// later language switches.
    static var defaultNames: [String] {
        [
            AppLanguage.localized("Holiday"),
            AppLanguage.localized("Special Day"),
            AppLanguage.localized("Daily"),
            AppLanguage.localized("Other")
        ]
    }
}
