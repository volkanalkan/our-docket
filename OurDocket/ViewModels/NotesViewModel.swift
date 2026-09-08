import Foundation
import FirebaseFirestore

@MainActor
final class NotesViewModel: ObservableObject {
    @Published private(set) var lists: [NoteList] = []
    @Published var errorMessage: String?

    private let coupleId: String
    private let service = NotesService()
    private var listener: ListenerRegistration?
    private var didEnsureDefaultList = false

    init(coupleId: String) {
        self.coupleId = coupleId
        listener = Firestore.firestore().collection("couples").document(coupleId)
            .collection("noteLists")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                self.lists = snapshot?.documents.compactMap { try? $0.data(as: NoteList.self) } ?? []

                if self.lists.isEmpty, !self.didEnsureDefaultList {
                    self.didEnsureDefaultList = true
                    Task { try? await self.service.ensureDefaultList(coupleId: self.coupleId) }
                }
            }
    }

    deinit {
        listener?.remove()
    }

    func createList(title: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        errorMessage = nil
        do {
            try await service.createList(coupleId: coupleId, title: trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addItem(text: String, to list: NoteList, addedBy: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var items = list.items
        items.append(NoteItem(id: UUID().uuidString, text: trimmed, isDone: false, addedBy: addedBy, updatedAt: Timestamp(date: .now)))
        await save(items: items, listId: list.id)
    }

    func toggleItem(_ item: NoteItem, in list: NoteList) async {
        var items = list.items
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isDone.toggle()
        items[index].updatedAt = Timestamp(date: .now)
        await save(items: items, listId: list.id)
    }

    func editItem(_ item: NoteItem, newText: String, in list: NoteList) async {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var items = list.items
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].text = trimmed
        items[index].updatedAt = Timestamp(date: .now)
        await save(items: items, listId: list.id)
    }

    func deleteItems(at offsets: IndexSet, from list: NoteList) async {
        var items = list.items
        items.remove(atOffsets: offsets)
        await save(items: items, listId: list.id)
    }

    func renameList(_ list: NoteList, newTitle: String) async {
        guard let listId = list.id else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await service.renameList(coupleId: coupleId, listId: listId, newTitle: trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteList(_ list: NoteList) async {
        guard let listId = list.id else { return }
        do {
            try await service.deleteList(coupleId: coupleId, listId: listId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(items: [NoteItem], listId: String?) async {
        guard let listId else { return }
        errorMessage = nil
        do {
            try await service.updateItems(coupleId: coupleId, listId: listId, items: items)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
