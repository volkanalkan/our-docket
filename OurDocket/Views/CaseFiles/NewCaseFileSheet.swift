import SwiftUI

struct NewCaseFileSheet: View {
    @ObservedObject var viewModel: CaseFilesViewModel

    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var category: CaseFileCategory = .gunluk
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Başlık") {
                    TextField("örn. Kapadokya Gezisi", text: $title)
                }

                Section("Kategori") {
                    Picker("Kategori", selection: $category) {
                        ForEach(CaseFileCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let error = viewModel.errorMessage {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Yeni Dosya")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Oluştur") {
                        Task { await createFile() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func createFile() async {
        guard let uid = authViewModel.currentUserId else { return }
        isSaving = true
        let success = await viewModel.createCaseFile(title: title, category: category, createdBy: uid)
        isSaving = false
        if success { dismiss() }
    }
}
