import SwiftUI

struct CaseFilesListView: View {
    let coupleId: String

    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel: CaseFilesViewModel
    @State private var displayMode: DisplayMode = .cards
    @State private var selectedCategory: CaseFileCategory?
    @State private var showingNewFileSheet = false

    enum DisplayMode: String, CaseIterable {
        case cards = "Kartlar"
        case timeline = "Zaman Çizelgesi"
    }

    init(coupleId: String) {
        self.coupleId = coupleId
        _viewModel = StateObject(wrappedValue: CaseFilesViewModel(coupleId: coupleId))
    }

    private var filteredFiles: [CaseFile] {
        guard let selectedCategory else { return viewModel.caseFiles }
        return viewModel.caseFiles.filter { $0.category == selectedCategory.rawValue }
    }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 16) {
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
                        case .cards:
                            cardsList
                        case .timeline:
                            CaseFilesTimelineView(coupleId: coupleId, viewModel: viewModel, files: filteredFiles)
                        }
                    }
                }
                .animation(.default, value: displayMode)
                .animation(.default, value: filteredFiles.count)
            }
            .padding(.top, 12)
        }
        .navigationTitle("Anı Dosyaları")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    HapticFeedback.tap()
                    showingNewFileSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingNewFileSheet) {
            NewCaseFileSheet(viewModel: viewModel)
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(title: "Tümü", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(CaseFileCategory.allCases) { category in
                    categoryChip(title: category.rawValue, isSelected: selectedCategory == category) {
                        selectedCategory = category
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
            Text("Sağ üstten yeni bir anı dosyası oluştur.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var cardsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredFiles) { file in
                    NavigationLink {
                        CaseFileDetailView(coupleId: coupleId, viewModel: viewModel, file: file, fileNumber: viewModel.fileNumber(for: file))
                    } label: {
                        CaseFileCardView(file: file, number: viewModel.fileNumber(for: file))
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded { HapticFeedback.tap() })
                }
            }
            .padding()
        }
    }
}

struct CaseFileCardView: View {
    let file: CaseFile
    let number: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundStyle(Theme.gold)

            VStack(alignment: .leading, spacing: 4) {
                Text("Dosya No: \(String(format: "%03d", number))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    NavigationStack {
        CaseFilesListView(coupleId: "preview")
    }
}
