import Foundation
import FirebaseFirestore

struct AppUser: Codable, Identifiable {
    @DocumentID var id: String?
    var displayName: String
    var appleUserId: String
    var coupleId: String?
    @ServerTimestamp var createdAt: Timestamp?
}
