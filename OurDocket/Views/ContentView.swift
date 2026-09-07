import SwiftUI
import FirebaseCore

struct ContentView: View {
    private var firebaseStatus: String {
        FirebaseApp.app() != nil ? "Firebase bağlı: \(FirebaseApp.app()?.options.projectID ?? "-")" : "Firebase yapılandırılamadı"
    }

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

                Text(firebaseStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
