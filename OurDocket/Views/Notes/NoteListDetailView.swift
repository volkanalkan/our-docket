import SwiftUI

struct NoteListDetailView: View {
    @ObservedObject var viewModel: NotesViewModel
    let list: NoteList

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var newItemText = ""
    @State private var editingItem: NoteItem?
    @State private var editText = ""

    var body: some View {
        VStack(spacing: 0) {
            if list.items.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.gold)
                    Text("Bu listede henüz madde yok")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(list.items) { item in
                        HStack(spacing: 12) {
                            Button {
                                HapticFeedback.selection()
                                Task { await viewModel.toggleItem(item, in: list) }
                            } label: {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isDone ? Theme.gold : Theme.navy.opacity(0.4))
                                    .animation(.snappy, value: item.isDone)
                            }
                            .buttonStyle(.plain)

                            Text(item.text)
                                .strikethrough(item.isDone)
                                .foregroundStyle(item.isDone ? .secondary : Theme.navy)
                                .animation(.default, value: item.isDone)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                HapticFeedback.tap()
                                editingItem = item
                                editText = item.text
                            } label: {
                                Label("Düzenle", systemImage: "pencil")
                            }
                            .tint(Theme.navy)
                        }
                    }
                    .onDelete { offsets in
                        HapticFeedback.tap()
                        Task { await viewModel.deleteItems(at: offsets, from: list) }
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            HStack(spacing: 8) {
                TextField("Yeni madde ekle", text: $newItemText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await addItem() } }

                Button {
                    HapticFeedback.tap()
                    Task { await addItem() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.navy)
                }
                .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .alert("Maddeyi Düzenle", isPresented: Binding(get: { editingItem != nil }, set: { if !$0 { editingItem = nil } })) {
            TextField("Madde", text: $editText)
            Button("İptal", role: .cancel) { editingItem = nil }
            Button("Kaydet") {
                HapticFeedback.tap()
                if let editingItem {
                    Task { await viewModel.editItem(editingItem, newText: editText, in: list) }
                }
                editingItem = nil
            }
        }
    }

    private func addItem() async {
        guard let uid = authViewModel.currentUserId else { return }
        let text = newItemText
        newItemText = ""
        await viewModel.addItem(text: text, to: list, addedBy: uid)
    }
}
