import SwiftUI

struct CategoryManagementSheet: View {
    @ObservedObject var viewModel: CaseFilesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var newCategoryName = ""
    @State private var renamingCategory: CaseFileCategoryOption?
    @State private var renameText = ""

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderBar(title: "Kategoriler") {
                    HeaderIconButton(systemImage: "xmark") { dismiss() }
                }

                List {
                    ForEach(viewModel.categories) { category in
                        Text(category.name)
                            .foregroundStyle(Theme.navy)
                            .swipeActions(edge: .leading) {
                                Button {
                                    renamingCategory = category
                                    renameText = category.name
                                } label: {
                                    Label("Düzenle", systemImage: "pencil")
                                }
                                .tint(Theme.navy)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    HapticFeedback.tap()
                                    Task { await viewModel.deleteCategory(category) }
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.6))
                    }

                    HStack {
                        TextField("Yeni kategori", text: $newCategoryName)
                        Button("Ekle") {
                            HapticFeedback.tap()
                            Task {
                                await viewModel.createCategory(name: newCategoryName)
                                newCategoryName = ""
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .listRowBackground(Color.white.opacity(0.6))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .alert("Kategoriyi Düzenle", isPresented: Binding(get: { renamingCategory != nil }, set: { if !$0 { renamingCategory = nil } })) {
            TextField("Kategori adı", text: $renameText)
            Button("İptal", role: .cancel) { renamingCategory = nil }
            Button("Kaydet") {
                if let renamingCategory {
                    Task { await viewModel.renameCategory(renamingCategory, newName: renameText) }
                }
                renamingCategory = nil
            }
        }
    }
}
