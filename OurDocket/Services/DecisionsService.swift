import Foundation
import EventKit
import UserNotifications
import FirebaseFirestore

@MainActor
final class DecisionsService {
    private let eventStore = EKEventStore()

    private func decisionsCollection(coupleId: String) -> CollectionReference {
        Firestore.firestore().collection("couples").document(coupleId).collection("decisions")
    }

    func createDecision(
        coupleId: String,
        title: String,
        date: Date?,
        description: String,
        addToCalendar: Bool,
        reminderEnabled: Bool,
        showElapsedCounter: Bool,
        sortIndex: Int
    ) async throws {
        var calendarEventIdentifier: String?
        if let date, addToCalendar {
            calendarEventIdentifier = try? await addCalendarEvent(title: title, date: date, notes: description)
        }

        let ref = decisionsCollection(coupleId: coupleId).document()

        if let date, reminderEnabled {
            try? await scheduleReminders(id: ref.documentID, title: title, date: date)
        }

        let decision = Decision(
            title: title,
            date: date.map(Timestamp.init(date:)),
            description: description,
            addToCalendar: date != nil && addToCalendar,
            reminderEnabled: date != nil && reminderEnabled,
            showElapsedCounter: date != nil && showElapsedCounter,
            calendarEventIdentifier: calendarEventIdentifier,
            sortIndex: sortIndex
        )
        try await ref.setData(from: decision)
    }

    func updateDecision(
        coupleId: String,
        decision: Decision,
        title: String,
        date: Date?,
        description: String,
        addToCalendar: Bool,
        reminderEnabled: Bool,
        showElapsedCounter: Bool
    ) async throws {
        guard let decisionId = decision.id else { return }

        var calendarEventIdentifier = decision.calendarEventIdentifier
        let wantsCalendar = date != nil && addToCalendar

        if !wantsCalendar, let existingId = calendarEventIdentifier {
            removeCalendarEvent(identifier: existingId)
            calendarEventIdentifier = nil
        } else if wantsCalendar, let date {
            if let existingId = calendarEventIdentifier {
                removeCalendarEvent(identifier: existingId)
            }
            calendarEventIdentifier = try? await addCalendarEvent(title: title, date: date, notes: description)
        }

        cancelReminders(id: decisionId)
        if let date, reminderEnabled {
            try? await scheduleReminders(id: decisionId, title: title, date: date)
        }

        try await decisionsCollection(coupleId: coupleId).document(decisionId).updateData([
            "title": title,
            "date": date.map(Timestamp.init(date:)) as Any,
            "description": description,
            "addToCalendar": wantsCalendar,
            "reminderEnabled": date != nil && reminderEnabled,
            "showElapsedCounter": date != nil && showElapsedCounter,
            "calendarEventIdentifier": calendarEventIdentifier as Any
        ])
    }

    func deleteDecision(coupleId: String, decision: Decision) async throws {
        guard let decisionId = decision.id else { return }
        if let eventId = decision.calendarEventIdentifier {
            removeCalendarEvent(identifier: eventId)
        }
        cancelReminders(id: decisionId)
        try await decisionsCollection(coupleId: coupleId).document(decisionId).delete()
    }

    func updateSortIndexes(coupleId: String, orderedIds: [String]) async {
        let batch = Firestore.firestore().batch()
        for (index, id) in orderedIds.enumerated() {
            batch.updateData(["sortIndex": index], forDocument: decisionsCollection(coupleId: coupleId).document(id))
        }
        try? await batch.commit()
    }

    // MARK: - Calendar

    private func addCalendarEvent(title: String, date: Date, notes: String) async throws -> String? {
        let granted = try await eventStore.requestWriteOnlyAccessToEvents()
        guard granted else { return nil }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.notes = notes
        event.startDate = date
        event.endDate = date.addingTimeInterval(3600)
        event.calendar = eventStore.defaultCalendarForNewEvents
        try eventStore.save(event, span: .thisEvent)
        return event.eventIdentifier
    }

    private func removeCalendarEvent(identifier: String) {
        guard let event = eventStore.event(withIdentifier: identifier) else { return }
        try? eventStore.remove(event, span: .thisEvent)
    }

    // MARK: - Reminders

    /// Two YEARLY recurring local notifications rather than one-off ones:
    /// the anniversary itself, and a week ahead of it — both at 00:00, every
    /// year, for as long as the reminder stays enabled.
    private func scheduleReminders(id: String, title: String, date: Date) async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else { return }

        guard let weekBefore = Calendar.current.date(byAdding: .day, value: -7, to: date) else { return }

        try await scheduleYearlyReminder(id: "\(id)-day", body: "Bugün: \(title)", date: date, center: center)
        try await scheduleYearlyReminder(id: "\(id)-week", body: "1 hafta sonra: \(title)", date: weekBefore, center: center)
    }

    private func scheduleYearlyReminder(id: String, body: String, date: Date, center: UNUserNotificationCenter) async throws {
        var components = Calendar.current.dateComponents([.month, .day], from: date)
        components.hour = 0
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Our Docket"
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func cancelReminders(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["\(id)-day", "\(id)-week"])
    }
}
