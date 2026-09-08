import SwiftUI

struct NewDecisionSheet: View {
    @ObservedObject var viewModel: DecisionsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var date = Date()
    @State private var description = ""
    @State private var addToCalendar = false
    @State private var reminderEnabled = false
    @State private var reminderLeadTime = 1

    var body: some View {
        NavigationStack {
            Form {
                Section("Karar") {
                    TextField("Başlık, örn. İlk \"Seni Seviyorum\"", text: $title)
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                    TextField("Açıklama", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Toggle("Apple Calendar'a ekle", isOn: $addToCalendar)
                    Toggle("Bildirim gönder", isOn: $reminderEnabled)
                    if reminderEnabled {
                        Stepper("Kaç gün önce: \(reminderLeadTime)", value: $reminderLeadTime, in: 1...30)
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Yeni Karar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Oluştur") {
                        Task { await createDecision() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSaving)
                }
            }
        }
    }

    private func createDecision() async {
        let success = await viewModel.createDecision(
            title: title,
            date: date,
            description: description,
            addToCalendar: addToCalendar,
            reminderEnabled: reminderEnabled,
            reminderLeadTime: reminderLeadTime
        )
        if success { dismiss() }
    }
}
