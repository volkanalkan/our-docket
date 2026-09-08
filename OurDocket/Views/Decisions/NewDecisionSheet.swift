import SwiftUI

struct NewDecisionSheet: View {
    @ObservedObject var viewModel: DecisionsViewModel
    var editingDecision: Decision?

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var hasDate = true
    @State private var date = Date()
    @State private var isRange = false
    @State private var endDate = Date()
    @State private var addToCalendar = false
    @State private var reminderEnabled = false
    @State private var showElapsedCounter = false
    @State private var showingReminderInfo = false
    @State private var showingCalendarRemovalConfirmation = false
    @State private var wasAddedToCalendarInitially = false

    private var isEditing: Bool { editingDecision != nil }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderBar(title: isEditing ? "Düzenle" : "Yeni Dönüm Noktası") {
                    HeaderIconButton(systemImage: "xmark") { dismiss() }
                }

                ScrollView {
                    VStack(spacing: 20) {
                        fieldBlock(label: "Başlık") {
                            TextField("örn. İlk \"Seni Seviyorum\"", text: $title)
                                .padding(12)
                                .background(.white.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        fieldBlock(label: "Açıklama") {
                            TextField("Açıklama (opsiyonel)", text: $description, axis: .vertical)
                                .lineLimit(3...6)
                                .padding(12)
                                .background(.white.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(spacing: 12) {
                            Toggle("Bir tarih belirt", isOn: $hasDate.animation())

                            if hasDate {
                                DatePicker(isRange ? "Başlangıç" : "Tarih", selection: $date, displayedComponents: .date)

                                Toggle("Bir tarih aralığı", isOn: $isRange.animation())
                                if isRange {
                                    DatePicker("Bitiş", selection: $endDate, in: date..., displayedComponents: .date)
                                }

                                Toggle("Apple Calendar'a ekle", isOn: $addToCalendar)
                                    .onChange(of: addToCalendar) { _, newValue in
                                        handleCalendarToggle(newValue)
                                    }

                                HStack {
                                    Button {
                                        showingReminderInfo = true
                                    } label: {
                                        Image(systemName: "info.circle")
                                            .foregroundStyle(.secondary)
                                    }
                                    .popover(isPresented: $showingReminderInfo) {
                                        Text("1 hafta önce (1 hafta kaldı) ve tarihin kendisinde (bugün) olmak üzere, her yıl saat 00:00'da bildirim gönderilir.")
                                            .font(.footnote)
                                            .padding()
                                            .frame(maxWidth: 280)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .presentationCompactAdaptation(.popover)
                                    }
                                    Toggle("Bildirim gönder", isOn: $reminderEnabled)
                                }

                                Toggle("Geçen süre sayacını göster", isOn: $showElapsedCounter)
                            }
                        }
                        .padding(12)
                        .background(.white.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        if let error = viewModel.errorMessage {
                            Text(error).foregroundStyle(.red).font(.footnote)
                        }

                        Button(isEditing ? "Kaydet" : "Oluştur") {
                            HapticFeedback.tap()
                            Task { await save() }
                        }
                        .buttonStyle(.ourDocketPrimary)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSaving)
                    }
                    .padding()
                }
            }
        }
        .confirmationDialog(
            "Calendar'dan silinecek, emin misin?",
            isPresented: $showingCalendarRemovalConfirmation,
            titleVisibility: .visible
        ) {
            Button("Evet, Kaldır", role: .destructive) {
                addToCalendar = false
            }
            Button("Vazgeç", role: .cancel) {
                addToCalendar = true
            }
        }
        .onAppear(perform: setUpInitialState)
    }

    private func fieldBlock<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func handleCalendarToggle(_ newValue: Bool) {
        guard isEditing, wasAddedToCalendarInitially, !newValue else { return }
        showingCalendarRemovalConfirmation = true
    }

    private func setUpInitialState() {
        guard let editingDecision, title.isEmpty else { return }
        title = editingDecision.title
        description = editingDecision.description
        if let existingDate = editingDecision.date?.dateValue() {
            hasDate = true
            date = existingDate
            if let existingEnd = editingDecision.endDate?.dateValue(), existingEnd > existingDate {
                isRange = true
                endDate = existingEnd
            }
        } else {
            hasDate = false
        }
        addToCalendar = editingDecision.addToCalendar
        wasAddedToCalendarInitially = editingDecision.addToCalendar
        reminderEnabled = editingDecision.reminderEnabled
        showElapsedCounter = editingDecision.showElapsedCounter
    }

    private func save() async {
        let resolvedDate = hasDate ? date : nil
        let resolvedEndDate = hasDate && isRange ? endDate : nil
        let success: Bool
        if let editingDecision {
            success = await viewModel.updateDecision(
                editingDecision, title: title, date: resolvedDate, endDate: resolvedEndDate, description: description,
                addToCalendar: addToCalendar, reminderEnabled: reminderEnabled, showElapsedCounter: showElapsedCounter
            )
        } else {
            success = await viewModel.createDecision(
                title: title, date: resolvedDate, endDate: resolvedEndDate, description: description,
                addToCalendar: addToCalendar, reminderEnabled: reminderEnabled, showElapsedCounter: showElapsedCounter
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
