import Foundation
import FirebaseFirestore

struct Decision: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var date: Timestamp
    var description: String
    var addToCalendar: Bool
    var reminderEnabled: Bool
    var reminderLeadTime: Int
}
