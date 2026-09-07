import SwiftUI

struct StartDateView: View {
    let coupleId: String

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var startDate = Date()
    @State private var isSaving = false

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("İlişkinizin Başlangıcı")
                    .font(.system(.title, design: .serif, weight: .bold))
                    .foregroundStyle(Theme.navy)
                    .multilineTextAlignment(.center)

                DatePicker(
                    "Başlangıç Tarihi",
                    selection: $startDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(Theme.gold)
                .padding(.horizontal)

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task {
                        isSaving = true
                        await authViewModel.setRelationshipStartDate(startDate, coupleId: coupleId)
                        isSaving = false
                    }
                } label: {
                    Text("Kaydet")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.navy)
                .padding(.horizontal, 32)
                .disabled(isSaving)
            }
            .padding()
        }
    }
}

#Preview {
    StartDateView(coupleId: "preview")
        .environmentObject(AuthViewModel())
}
