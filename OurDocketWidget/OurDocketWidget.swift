import WidgetKit
import SwiftUI

struct RelationshipEntry: TimelineEntry {
    let date: Date
    let startDate: Date?
}

struct RelationshipTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> RelationshipEntry {
        RelationshipEntry(date: .now, startDate: Calendar.current.date(byAdding: .month, value: -6, to: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (RelationshipEntry) -> Void) {
        completion(RelationshipEntry(date: .now, startDate: SharedRelationshipStore.loadStartDate()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RelationshipEntry>) -> Void) {
        let startDate = SharedRelationshipStore.loadStartDate()
        let calendar = Calendar.current
        let now = Date()

        // The widget only ever shows years/months/days, so one entry per
        // day (at local midnight) keeps that count correct without asking
        // the system for more refreshes than the day-granularity content
        // actually needs.
        let entries: [RelationshipEntry] = (0..<30).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now))
                .map { RelationshipEntry(date: $0, startDate: startDate) }
        }

        let refreshDate = calendar.date(byAdding: .day, value: 30, to: now) ?? now
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }
}

struct OurDocketWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RelationshipEntry

    private var durationText: String {
        guard let startDate = entry.startDate else { return "Henüz eşleşme yok" }
        let components = Calendar.current.dateComponents([.year, .month, .day], from: startDate, to: entry.date)
        return "\(components.year ?? 0) yıl \(components.month ?? 0) ay \(components.day ?? 0) gün"
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(durationText)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Our Docket")
                    .font(.caption2)
                Text(durationText)
                    .font(.headline)
                    .minimumScaleFactor(0.7)
            }
            .containerBackground(.clear, for: .widget)

        default:
            VStack(spacing: 6) {
                Image(systemName: "scale.3d")
                    .font(.title3)
                    .foregroundStyle(Theme.gold)
                Text(durationText)
                    .font(.system(.caption, design: .serif, weight: .bold))
                    .foregroundStyle(Theme.navy)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
            }
            .padding(8)
            .containerBackground(Theme.cream, for: .widget)
        }
    }
}

struct OurDocketWidget: Widget {
    private let kind = "OurDocketWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RelationshipTimelineProvider()) { entry in
            OurDocketWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Our Docket")
        .description("Birlikte geçen süreyi gösterir.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

#Preview(as: .systemSmall) {
    OurDocketWidget()
} timeline: {
    RelationshipEntry(date: .now, startDate: Calendar.current.date(byAdding: .month, value: -6, to: .now))
}
