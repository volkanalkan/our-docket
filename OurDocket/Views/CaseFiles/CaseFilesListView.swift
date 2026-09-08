import SwiftUI

struct CaseFilesListView: View {
    let coupleId: String

    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel: CaseFilesViewModel
    @State private var displayMode: DisplayMode = .list
    @State private var selectedCategory: String?
    @State private var showingNewFileSheet = false
    @State private var editingFile: CaseFile?
    @State private var deletingFile: CaseFile?
    @State private var timelineSort: TimelineSort = .newestFirst

    enum DisplayMode: String, CaseIterable {
        case list = "Liste"
        case timeline = "Zaman Çizelgesi"
    }

    enum TimelineSort: String, CaseIterable, Identifiable {
        case newestFirst = "Yeniden Eskiye"
        case oldestFirst = "Eskiden Yeniye"
        var id: String { rawValue }
    }

    init(coupleId: String) {
        self.coupleId = coupleId
        _viewModel = StateObject(wrappedValue: CaseFilesViewModel(coupleId: coupleId))
    }

    private var filteredFiles: [CaseFile] {
        guard let selectedCategory else { return viewModel.caseFiles }
        return viewModel.caseFiles.filter { $0.category == selectedCategory }
    }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 16) {
                HeaderBar(title: "Arşiv") {
                    HStack(spacing: 8) {
                        if displayMode == .timeline {
                            timelineSortMenu
                        }
                        HeaderIconButton(systemImage: "plus") {
                            showingNewFileSheet = true
                        }
                    }
                }

                Picker("Görünüm", selection: $displayMode) {
                    ForEach(DisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: displayMode) { _, _ in HapticFeedback.selection() }

                categoryFilter

                Group {
                    if filteredFiles.isEmpty {
                        emptyState
                    } else {
                        switch displayMode {
                        case .list:
                            cardsList
                        case .timeline:
                            CaseFilesTimelineView(
                                coupleId: coupleId, viewModel: viewModel, files: filteredFiles, sort: timelineSort,
                                onEdit: { editingFile = $0 }, onDelete: { deletingFile = $0 }
                            )
                        }
                    }
                }
                .animation(.default, value: displayMode)
                .animation(.default, value: filteredFiles.count)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingNewFileSheet) {
            NewCaseFileSheet(viewModel: viewModel)
        }
        .sheet(item: $editingFile) { file in
            NewCaseFileSheet(viewModel: viewModel, editingFile: file)
        }
        .confirmationDialog(
            "Bu dosyayı silmek istediğine emin misin?",
            isPresented: Binding(get: { deletingFile != nil }, set: { if !$0 { deletingFile = nil } }),
            titleVisibility: .visible
        ) {
            Button("Dosyayı Sil", role: .destructive) {
                if let deletingFile {
                    HapticFeedback.tap()
                    Task { await viewModel.deleteCaseFile(deletingFile) }
                }
                self.deletingFile = nil
            }
            Button("İptal", role: .cancel) { deletingFile = nil }
        } message: {
            Text("İçindeki tüm fotoğraf ve videolar da silinir. Bu işlem geri alınamaz.")
        }
    }

    private var timelineSortMenu: some View {
        Menu {
            ForEach(TimelineSort.allCases) { option in
                Button {
                    HapticFeedback.selection()
                    timelineSort = option
                } label: {
                    Label(option.rawValue, systemImage: timelineSort == option ? "checkmark" : "")
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.navy)
                .frame(width: 36, height: 36)
                .background(Theme.navy.opacity(0.08), in: Circle())
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(title: "Tümü", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(viewModel.categories) { category in
                    categoryChip(title: category.name, isSelected: selectedCategory == category.name) {
                        selectedCategory = category.name
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.selection()
            withAnimation(.snappy) { action() }
        } label: {
            Text(title)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Theme.navy : Theme.navy.opacity(0.08))
                .foregroundStyle(isSelected ? .white : Theme.navy)
                .clipShape(Capsule())
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(Theme.gold)
            Text("Henüz dosya yok")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Theme.navy)
            Text("Sağ üstten yeni bir dosya oluştur.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var cardsList: some View {
        List {
            ForEach(filteredFiles) { file in
                NavigationLink {
                    CaseFileDetailView(coupleId: coupleId, viewModel: viewModel, file: file)
                } label: {
                    CaseFileCardView(file: file)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .swipeActions(edge: .leading) {
                    Button {
                        HapticFeedback.tap()
                        editingFile = file
                    } label: {
                        Label("Düzenle", systemImage: "pencil")
                    }
                    .tint(Theme.navy)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        HapticFeedback.tap()
                        deletingFile = file
                    } label: {
                        Label("Sil", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct CaseFileCardView: View {
    let file: CaseFile

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: file.iconName)
                .font(.system(size: 26))
                .foregroundStyle(Color(hex: file.colorHex))
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(file.title)
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .foregroundStyle(Theme.navy)
                Text(file.category)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.navy.opacity(0.08))
                    .clipShape(Capsule())
                    .foregroundStyle(Theme.navy)
            }

            Spacer()

            HStack(spacing: 4) {
                Text("\(file.mediaItems.count)")
                Image(systemName: "photo.on.rectangle")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.navy.opacity(0.08)))
    }
}

#Preview {
    CaseFilesListView(coupleId: "preview")
}
