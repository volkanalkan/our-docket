import Foundation
import FirebaseFirestore

struct Couple: Codable, Identifiable {
    @DocumentID var id: String?
    var memberUids: [String]
    var relationshipStartDate: Timestamp?
    @ServerTimestamp var createdAt: Timestamp?
}
