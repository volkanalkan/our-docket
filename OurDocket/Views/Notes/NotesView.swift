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
                HeaderBar(title: "Notlar") {
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
        .alert("Yeni Sekme", isPresented: $showingNewListAlert) {
            TextField("örn. Market Alışverişi", text: $newListTitle)
            Button("İptal", role: .cancel) {}
            Button("Oluştur") {
                HapticFeedback.tap()
                Task { await viewModel.createList(title: newListTitle) }
            }
        }
        .alert("Sekmeyi Yeniden Adlandır", isPresented: Binding(get: { renamingList != nil }, set: { if !$0 { renamingList = nil } })) {
            TextField("Sekme adı", text: $renameText)
            Button("İptal", role: .cancel) { renamingList = nil }
            Button("Kaydet") {
                if let renamingList {
                    Task { await viewModel.renameList(renamingList, newTitle: renameText) }
                }
                renamingList = nil
            }
        }
        .confirmationDialog(
            "Bu sekmeyi silmek istediğine emin misin?",
            isPresented: Binding(get: { deletingList != nil }, set: { if !$0 { deletingList = nil } }),
            titleVisibility: .visible
        ) {
            Button("Sekmeyi Sil", role: .destructive) {
                if let deletingList {
                    HapticFeedback.tap()
                    Task { await viewModel.deleteList(deletingList) }
                }
                deletingList = nil
            }
            Button("İptal", role: .cancel) { deletingList = nil }
        } message: {
            Text("İçindeki tüm maddeler de silinir.")
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.lists) { list in
                    let isSelected = selectedList?.id == list.id
                    Button {
                        HapticFeedback.selection()
                        selectedListId = list.id
                    } label: {
                        Text(list.title)
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? Theme.navy : Theme.navy.opacity(0.08))
                            .foregroundStyle(isSelected ? .white : Theme.navy)
                            .clipShape(Capsule())
                    }
                    .contextMenu {
                        Button {
                            renamingList = list
                            renameText = list.title
                        } label: {
                            Label("Yeniden Adlandır", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deletingList = list
                        } label: {
                            Label("Sil", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    NotesView(coupleId: "preview")
}
