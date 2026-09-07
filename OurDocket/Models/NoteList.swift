import Foundation
import FirebaseFirestore

struct NoteItem: Codable, Identifiable {
    var id: String
    var text: String
    var isDone: Bool
    var addedBy: String
    var updatedAt: Timestamp
}

struct NoteList: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var items: [NoteItem]
}
