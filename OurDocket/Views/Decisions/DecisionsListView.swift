import SwiftUI

struct DecisionsListView: View {
    let coupleId: String

    @StateObject private var viewModel: DecisionsViewModel
    @State private var showingNewSheet = false

    init(coupleId: String) {
        self.coupleId = coupleId
        _viewModel = StateObject(wrappedValue: DecisionsViewModel(coupleId: coupleId))
    }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            if viewModel.decisions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(viewModel.decisions) { decision in
                            DecisionCardView(decision: decision, number: viewModel.decisionNumber(for: decision))
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Kararlar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingNewSheet) {
            NewDecisionSheet(viewModel: viewModel)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "seal")
                .font(.system(size: 40))
                .foregroundStyle(Theme.gold)
            Text("Henüz karar yok")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Theme.navy)
            Text("Sağ üstten yeni bir karar ekle.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        DecisionsListView(coupleId: "preview")
    }
}
