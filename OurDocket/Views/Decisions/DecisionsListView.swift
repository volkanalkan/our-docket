import SwiftUI

struct DecisionsListView: View {
    let coupleId: String

    @StateObject private var viewModel: DecisionsViewModel
    @State private var showingNewSheet = false
    @State private var editingDecision: Decision?
    @State private var deletingDecision: Decision?

    init(coupleId: String) {
        self.coupleId = coupleId
        _viewModel = StateObject(wrappedValue: DecisionsViewModel(coupleId: coupleId))
    }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderBar(title: "Milestones", showBack: false) {
                    HStack(spacing: 8) {
                        sortMenu
                        HeaderIconButton(systemImage: "plus") { showingNewSheet = true }
                    }
                }

                if viewModel.decisions.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
        .navigationBarHidden(true)
        .animation(.default, value: viewModel.decisions.count)
        .sheet(isPresented: $showingNewSheet) {
            NewDecisionSheet(viewModel: viewModel)
        }
        .sheet(item: $editingDecision) { decision in
            NewDecisionSheet(viewModel: viewModel, editingDecision: decision)
        }
        .confirmationDialog(
            "Are you sure you want to delete this milestone?",
            isPresented: Binding(get: { deletingDecision != nil }, set: { if !$0 { deletingDecision = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let deletingDecision {
                    HapticFeedback.tap()
                    Task { await viewModel.deleteDecision(deletingDecision) }
                }
                deletingDecision = nil
            }
            Button("Cancel", role: .cancel) { deletingDecision = nil }
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(DecisionSort.allCases) { option in
                Button {
                    HapticFeedback.selection()
                    viewModel.sort = option
                } label: {
                    Label(option.title, systemImage: viewModel.sort == option ? "checkmark" : "")
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

    private var list: some View {
        List {
            ForEach(viewModel.orderedDecisions) { decision in
                DecisionCardView(decision: decision)
                    .onTapGesture {
                        HapticFeedback.tap()
                        editingDecision = decision
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .deleteDisabled(true)
                    .swipeActions(edge: .leading) {
                        Button {
                            HapticFeedback.tap()
                            editingDecision = decision
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(Theme.navy)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            HapticFeedback.tap()
                            deletingDecision = decision
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .onMove { source, destination in
                guard viewModel.sort == .manual else { return }
                viewModel.move(from: source, to: destination)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(viewModel.sort == .manual ? .active : .inactive))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "seal")
                .font(.system(size: 40))
                .foregroundStyle(Theme.gold)
            Text("Nothing here yet")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Theme.navy)
            Text("Add a new milestone from the top right.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

#Preview {
    DecisionsListView(coupleId: "preview")
}
