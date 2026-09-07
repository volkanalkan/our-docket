import SwiftUI

struct HomeView: View {
    let coupleId: String

    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "scale.3d")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.gold)

                Text("Our Docket")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(Theme.navy)

                Text("Dosya No: \(coupleId.prefix(6).uppercased())")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Çıkış Yap", role: .destructive) {
                    authViewModel.signOut()
                }
                .padding(.top, 24)
            }
            .padding()
        }
    }
}

#Preview {
    HomeView(coupleId: "preview-couple-id")
        .environmentObject(AuthViewModel())
}
