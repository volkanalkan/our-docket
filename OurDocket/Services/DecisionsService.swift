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
        date: Date,
        description: String,
        addToCalendar: Bool,
        reminderEnabled: Bool,
        reminderLeadTime: Int
    ) async throws {
        let decision = Decision(
            title: title,
            date: Timestamp(date: date),
            description: description,
            addToCalendar: addToCalendar,
            reminderEnabled: reminderEnabled,
            reminderLeadTime: reminderLeadTime
        )
        let ref = decisionsCollection(coupleId: coupleId).document()
        try await ref.setData(from: decision)

        if addToCalendar {
            try? await addCalendarEvent(title: title, date: date, notes: description)
        }
        if reminderEnabled {
            try? await scheduleReminder(id: ref.documentID, title: title, date: date, leadTimeDays: reminderLeadTime)
        }
    }

    private func addCalendarEvent(title: String, date: Date, notes: String) async throws {
        let granted = try await eventStore.requestWriteOnlyAccessToEvents()
        guard granted else { return }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.notes = notes
        event.startDate = date
        event.endDate = date.addingTimeInterval(3600)
        event.calendar = eventStore.defaultCalendarForNewEvents
        try eventStore.save(event, span: .thisEvent)
    }

    private func scheduleReminder(id: String, title: String, date: Date, leadTimeDays: Int) async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        guard granted else { return }

        guard let triggerDate = Calendar.current.date(byAdding: .day, value: -leadTimeDays, to: date),
              triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Karar Hatırlatması"
        content.body = title
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
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
}
