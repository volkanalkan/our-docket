import Foundation
import FirebaseFirestore

@MainActor
final class DecisionsViewModel: ObservableObject {
    @Published private(set) var decisions: [Decision] = []
    @Published var errorMessage: String?
    @Published private(set) var isSaving = false

    private let coupleId: String
    private let service = DecisionsService()
    private var listener: ListenerRegistration?

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

    func decisionNumber(for decision: Decision) -> Int {
        (decisions.firstIndex(where: { $0.id == decision.id }) ?? 0) + 1
    }

    func createDecision(
        title: String,
        date: Date,
        description: String,
        addToCalendar: Bool,
        reminderEnabled: Bool,
        reminderLeadTime: Int
    ) async -> Bool {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await service.createDecision(
                coupleId: coupleId,
                title: title,
                date: date,
                description: description,
                addToCalendar: addToCalendar,
                reminderEnabled: reminderEnabled,
                reminderLeadTime: reminderLeadTime
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
