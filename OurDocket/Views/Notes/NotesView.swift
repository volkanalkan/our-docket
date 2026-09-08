import SwiftUI

struct NotesView: View {
    let coupleId: String

    @StateObject private var viewModel: NotesViewModel
    @State private var selectedListId: String?
    @State private var showingNewListAlert = false
    @State private var newListTitle = ""

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
                } else {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
            .padding(.top, 12)
        }
        .navigationTitle("Notlar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newListTitle = ""
                    showingNewListAlert = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .alert("Yeni Sekme", isPresented: $showingNewListAlert) {
            TextField("örn. Market Alışverişi", text: $newListTitle)
            Button("İptal", role: .cancel) {}
            Button("Oluştur") {
                Task { await viewModel.createList(title: newListTitle) }
            }
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.lists) { list in
                    let isSelected = selectedList?.id == list.id
                    Button {
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
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    NavigationStack {
        NotesView(coupleId: "preview")
    }
}
