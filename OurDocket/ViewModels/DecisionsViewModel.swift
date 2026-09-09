import Foundation
import SwiftUI
import FirebaseFirestore

enum DecisionSort: CaseIterable, Identifiable {
    case newestFirst
    case oldestFirst
    case manual

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .newestFirst: "Newest First"
        case .oldestFirst: "Oldest First"
        case .manual: "Manual Order"
        }
    }
}

@MainActor
final class DecisionsViewModel: ObservableObject {
    @Published private(set) var decisions: [Decision] = []
    @Published var sort: DecisionSort = .newestFirst
    @Published var errorMessage: String?
    @Published private(set) var isSaving = false

    private let coupleId: String
    private let service = DecisionsService()
    private var listener: ListenerRegistration?

    /// Dateless decisions always sort to the bottom of date-based orderings
    /// — there's no "when" to compare them by.
    var orderedDecisions: [Decision] {
        switch sort {
        case .newestFirst:
            return decisions.sorted { lhs, rhs in
                guard let l = lhs.date?.dateValue() else { return false }
                guard let r = rhs.date?.dateValue() else { return true }
                return l > r
            }
        case .oldestFirst:
            return decisions.sorted { lhs, rhs in
                guard let l = lhs.date?.dateValue() else { return false }
                guard let r = rhs.date?.dateValue() else { return true }
                return l < r
            }
        case .manual:
            return decisions.sorted { $0.sortIndex < $1.sortIndex }
        }
    }

    init(coupleId: String) {
        self.coupleId = coupleId
        listener = Firestore.firestore().collection("couples").document(coupleId)
            .collection("decisions")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                self.decisions = snapshot?.documents.compactMap { try? $0.data(as: Decision.self) } ?? []
            }
    }

    deinit {
        listener?.remove()
    }

    func createDecision(
        title: String,
        date: Date?,
        endDate: Date?,
        description: String,
        addToCalendar: Bool,
        reminderEnabled: Bool,
        showElapsedCounter: Bool
    ) async -> Bool {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await service.createDecision(
                coupleId: coupleId, title: title, date: date, endDate: endDate, description: description,
                addToCalendar: addToCalendar, reminderEnabled: reminderEnabled,
                showElapsedCounter: showElapsedCounter, sortIndex: decisions.count
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateDecision(
        _ decision: Decision,
        title: String,
        date: Date?,
        endDate: Date?,
        description: String,
        addToCalendar: Bool,
        reminderEnabled: Bool,
        showElapsedCounter: Bool
    ) async -> Bool {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await service.updateDecision(
                coupleId: coupleId, decision: decision, title: title, date: date, endDate: endDate, description: description,
                addToCalendar: addToCalendar, reminderEnabled: reminderEnabled, showElapsedCounter: showElapsedCounter
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteDecision(_ decision: Decision) async {
        do {
            try await service.deleteDecision(coupleId: coupleId, decision: decision)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        var manualOrder = orderedDecisions
        manualOrder.move(fromOffsets: source, toOffset: destination)
        Task {
            await service.updateSortIndexes(coupleId: coupleId, orderedIds: manualOrder.compactMap(\.id))
        }
    }
}
