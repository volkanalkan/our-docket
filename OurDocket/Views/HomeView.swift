import SwiftUI

struct HomeView: View {
    let coupleId: String

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showingPortraitEditor = false
    @State private var showingSettings = false
    @State private var portraitImage: UIImage?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                Theme.cream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        portraitHeader

                        if let startDate = authViewModel.couple?.relationshipStartDate?.dateValue() {
                            RelationshipCounterView(startDate: startDate)
                        }

                        ShortcutCardsView(coupleId: coupleId)
                            .padding(.horizontal)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 40)
                }

                Button {
                    HapticFeedback.tap()
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.navy)
                        .padding(10)
                        .background(.white.opacity(0.6), in: Circle())
                }
                .buttonStyle(.plain)
                .padding()
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingPortraitEditor) {
            PortraitCropView(coupleId: coupleId) {
                showingPortraitEditor = false
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .task(id: authViewModel.couple?.homePortraitPath) {
            await loadPortrait()
        }
    }

    private var portraitHeader: some View {
        Button {
            HapticFeedback.tap()
            showingPortraitEditor = true
        } label: {
            Group {
                if let portraitImage {
                    Image(uiImage: portraitImage)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    ZStack {
                        Theme.navy.opacity(0.06)
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 32))
                            Text("Fotoğraf Ekle")
                                .font(.footnote)
                        }
                        .foregroundStyle(Theme.navy)
                    }
                }
            }
            .frame(width: 220, height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Theme.gold, lineWidth: 2))
            .animation(.default, value: portraitImage)
        }
        .buttonStyle(.plain)
    }

    private func loadPortrait() async {
        guard let path = authViewModel.couple?.homePortraitPath else {
            portraitImage = nil
            return
        }
        do {
            let url = try await PortraitService().downloadURL(for: path)
            let (data, _) = try await URLSession.shared.data(from: url)
            portraitImage = UIImage(data: data)
        } catch {
            portraitImage = nil
        }
    }
}

#Preview {
    HomeView(coupleId: "preview-couple-id")
        .environmentObject(AuthViewModel())
}
