import SwiftUI

struct NotesView: View {
    let coupleId: String

    @StateObject private var viewModel: NotesViewModel
    @State private var selectedListId: String?
    @State private var showingNewListAlert = false
    @State private var newListTitle = ""
    @State private var renamingList: NoteList?
    @State private var renameText = ""
    @State private var deletingList: NoteList?

    init(coupleId: String) {
        self.coupleId = coupleId
        _viewModel = StateObject(wrappedValue: NotesViewModel(coupleId: coupleId))
    }

    private var selectedList: NoteList? {
        viewModel.lists.first(where: { $0.id == selectedListId }) ?? viewModel.lists.first
    }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 12) {
                HeaderBar(title: "Notes") {
                    HeaderIconButton(systemImage: "plus") {
                        newListTitle = ""
                        showingNewListAlert = true
                    }
                }

                if !viewModel.lists.isEmpty {
                    tabBar
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                if let selectedList {
                    NoteListDetailView(viewModel: viewModel, list: selectedList)
                        .transition(.opacity)
                } else {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
            .animation(.default, value: selectedList?.id)
        }
        .navigationBarHidden(true)
        .alert("New Tab", isPresented: $showingNewListAlert) {
            TextField("e.g. Groceries", text: $newListTitle)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                HapticFeedback.tap()
                Task { await viewModel.createList(title: newListTitle) }
            }
        }
        .alert("Rename Tab", isPresented: Binding(get: { renamingList != nil }, set: { if !$0 { renamingList = nil } })) {
            TextField("Tab name", text: $renameText)
            Button("Cancel", role: .cancel) { renamingList = nil }
            Button("Save") {
                if let renamingList {
                    Task { await viewModel.renameList(renamingList, newTitle: renameText) }
                }
                renamingList = nil
            }
        }
        .confirmationDialog(
            "Are you sure you want to delete this tab?",
            isPresented: Binding(get: { deletingList != nil }, set: { if !$0 { deletingList = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Tab", role: .destructive) {
                if let deletingList {
                    HapticFeedback.tap()
                    Task { await viewModel.deleteList(deletingList) }
                }
                deletingList = nil
            }
            Button("Cancel", role: .cancel) { deletingList = nil }
        } message: {
            Text("All items inside it will be deleted too.")
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.lists) { list in
                    let isSelected = selectedList?.id == list.id
                    HStack(spacing: 6) {
                        Button {
                            HapticFeedback.selection()
                            selectedListId = list.id
                        } label: {
                            Text(list.title)
                                .font(.footnote.weight(.medium))
                        }
                        .buttonStyle(.plain)

                        Menu {
                            Button {
                                renamingList = list
                                renameText = list.title
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                deletingList = list
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption2.weight(.bold))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isSelected ? Theme.navy : Theme.navy.opacity(0.08))
                    .foregroundStyle(isSelected ? .white : Theme.navy)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    NotesView(coupleId: "preview")
}
