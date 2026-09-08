import SwiftUI

struct NewCaseFileSheet: View {
    @ObservedObject var viewModel: CaseFilesViewModel
    /// nil when creating a new file, set when editing an existing one.
    var editingFile: CaseFile?

    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    private enum DateOption: String, CaseIterable, Identifiable {
        case today = "Bugün"
        case chosen = "Tarih Seç"
        case none = "Tarih Yok"
        var id: String { rawValue }
    }

    @State private var title = ""
    @State private var selectedCategory = ""
    @State private var dateOption: DateOption = .today
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isRange = false
    @State private var iconName = ""
    @State private var colorHex = ""
    @State private var isSaving = false
    @State private var showingCategoryManagement = false

    private var isEditing: Bool { editingFile != nil }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderBar(title: isEditing ? "Dosyayı Düzenle" : "Yeni Dosya") {
                    HeaderIconButton(systemImage: "xmark") { dismiss() }
                }

                ScrollView {
                    VStack(spacing: 24) {
                        appearancePreview

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Başlık")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            TextField("örn. Kapadokya Gezisi", text: $title)
                                .padding(12)
                                .background(.white.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Kategori")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Düzenle") { showingCategoryManagement = true }
                                    .font(.caption)
                            }
                            categoryPicker
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tarih")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)

                            Picker("Tarih", selection: $dateOption) {
                                ForEach(DateOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)

                            if dateOption == .chosen {
                                VStack(spacing: 12) {
                                    DatePicker("Başlangıç", selection: $startDate, displayedComponents: .date)
                                    Toggle("Bir tarih aralığı (örn. bir hafta)", isOn: $isRange.animation())
                                    if isRange {
                                        DatePicker("Bitiş", selection: $endDate, in: startDate..., displayedComponents: .date)
                                    }
                                }
                                .padding(12)
                                .background(.white.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        if let error = viewModel.errorMessage {
                            Text(error).foregroundStyle(.red).font(.footnote)
                        }

                        Button(isEditing ? "Kaydet" : "Oluştur") {
                            HapticFeedback.tap()
                            Task { await save() }
                        }
                        .buttonStyle(.ourDocketPrimary)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementSheet(viewModel: viewModel)
        }
        .onAppear(perform: setUpInitialState)
    }

    private var appearancePreview: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: colorHex.isEmpty ? "1B2A4A" : colorHex))
                    .frame(width: 88, height: 88)
                Image(systemName: iconName.isEmpty ? "folder.fill" : iconName)
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
            }

            Button {
                HapticFeedback.selection()
                withAnimation(.snappy) {
                    let random = RandomAppearance.random()
                    iconName = random.icon
                    colorHex = random.colorHex
                }
            } label: {
                Label("Rastgele", systemImage: "shuffle")
            }
            .buttonStyle(.ourDocketSecondary)
            .frame(maxWidth: 160)
        }
        .frame(maxWidth: .infinity)
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.categories) { category in
                    let isSelected = selectedCategory == category.name
                    Button {
                        HapticFeedback.selection()
                        selectedCategory = category.name
                    } label: {
                        Text(category.name)
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? Theme.navy : Theme.navy.opacity(0.08))
                            .foregroundStyle(isSelected ? .white : Theme.navy)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func setUpInitialState() {
        guard iconName.isEmpty else { return }
        if let editingFile {
            title = editingFile.title
            selectedCategory = editingFile.category
            iconName = editingFile.iconName
            colorHex = editingFile.colorHex
            if let start = editingFile.eventStartDate?.dateValue() {
                dateOption = .chosen
                startDate = start
                if let end = editingFile.eventEndDate?.dateValue(), end > start {
                    isRange = true
                    endDate = end
                }
            } else {
                dateOption = .none
            }
        } else {
            let random = RandomAppearance.random()
            iconName = random.icon
            colorHex = random.colorHex
            selectedCategory = viewModel.categories.first?.name ?? ""
        }
    }

    private func resolvedDates() -> (start: Date?, end: Date?) {
        switch dateOption {
        case .today:
            return (Date(), Date())
        case .none:
            return (nil, nil)
        case .chosen:
            return (startDate, isRange ? endDate : startDate)
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let (start, end) = resolvedDates()
        let success: Bool
        if let editingFile {
            success = await viewModel.updateCaseFile(
                editingFile, title: title, category: selectedCategory,
                iconName: iconName, colorHex: colorHex,
                eventStartDate: start, eventEndDate: end
            )
        } else {
            guard let uid = authViewModel.currentUserId else { return }
            success = await viewModel.createCaseFile(
                title: title, category: selectedCategory, createdBy: uid,
                iconName: iconName, colorHex: colorHex,
                eventStartDate: start, eventEndDate: end
            )
        }

        if success {
            HapticFeedback.success()
            dismiss()
        } else {
            HapticFeedback.error()
        }
    }
}
