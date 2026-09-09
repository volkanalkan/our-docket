import Foundation
import FirebaseFirestore

@MainActor
final class NotesService {
    private func noteListsCollection(coupleId: String) -> CollectionReference {
        Firestore.firestore().collection("couples").document(coupleId).collection("noteLists")
    }

    func ensureDefaultList(coupleId: String) async throws {
        let snapshot = try await noteListsCollection(coupleId: coupleId).limit(to: 1).getDocuments()
        guard snapshot.documents.isEmpty else { return }
        try await createList(coupleId: coupleId, title: AppLanguage.localized("To-Do"))
    }

    @discardableResult
    func createList(coupleId: String, title: String) async throws -> String {
        let ref = noteListsCollection(coupleId: coupleId).document()
        try await ref.setData(from: NoteList(title: title, items: []))
        return ref.documentID
    }

    func updateItems(coupleId: String, listId: String, items: [NoteItem]) async throws {
        let encoded = try items.map { try Firestore.Encoder().encode($0) }
        try await noteListsCollection(coupleId: coupleId).document(listId).updateData(["items": encoded])
    }

    func renameList(coupleId: String, listId: String, newTitle: String) async throws {
        try await noteListsCollection(coupleId: coupleId).document(listId).updateData(["title": newTitle])
    }

    func deleteList(coupleId: String, listId: String) async throws {
        try await noteListsCollection(coupleId: coupleId).document(listId).delete()
    }
}
