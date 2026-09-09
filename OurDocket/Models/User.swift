import Foundation
import FirebaseFirestore

struct AppUser: Codable, Identifiable {
    @DocumentID var id: String?
    var displayName: String
    var appleUserId: String
    var coupleId: String?
    /// "en" | "tr" — the in-app choice, mirrored here so a new device picks
    /// it up without asking again.
    var preferredLanguage: String?
    @ServerTimestamp var createdAt: Timestamp?
}
