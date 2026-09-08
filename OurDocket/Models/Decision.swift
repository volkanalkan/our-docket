import Foundation
import FirebaseFirestore

struct Decision: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    /// nil means the date is deliberately unknown/unset. Calendar and
    /// reminder options only make sense when this is set.
    var date: Timestamp?
    /// Set only when the milestone spans a range rather than a single day.
    var endDate: Timestamp?
    var description: String
    var addToCalendar: Bool
    var reminderEnabled: Bool
    var showElapsedCounter: Bool
    /// EKEvent identifier for the calendar entry this decision created, so
    /// turning "Calendar'a ekle" off can find and remove the exact event.
    var calendarEventIdentifier: String?
    /// Manual order used only when the list's sort mode is "random/manual
    /// drag" — every other sort mode is computed from `date`/`createdAt`.
    var sortIndex: Int
    @ServerTimestamp var createdAt: Timestamp?
}
