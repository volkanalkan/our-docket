import Foundation

/// The only channel the widget is allowed to read from — it never talks to
/// Firestore directly (battery/perf, and widgets can't hold a live
/// listener). The main app writes here whenever the couple's
/// relationshipStartDate changes; the widget just reads and computes the
/// elapsed time itself.
enum SharedRelationshipStore {
    static let appGroupId = "group.com.volkan.ourdocket"
    private static let startDateKey = "relationshipStartDate"

    static func save(startDate: Date?) {
        let defaults = UserDefaults(suiteName: appGroupId)
        if let startDate {
            defaults?.set(startDate, forKey: startDateKey)
        } else {
            defaults?.removeObject(forKey: startDateKey)
        }
    }

    static func loadStartDate() -> Date? {
        UserDefaults(suiteName: appGroupId)?.object(forKey: startDateKey) as? Date
    }
}
