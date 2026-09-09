import SwiftUI

struct RelationshipCounterView: View {
    let startDate: Date

    var body: some View {
        TimelineView(.periodic(from: startDate, by: 1)) { context in
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: startDate,
                to: context.date
            )

            VStack(spacing: 6) {
                (Text("\(components.year ?? 0) years")
                    + Text(verbatim: ", ")
                    + Text("\(components.month ?? 0) months")
                    + Text(verbatim: ", ")
                    + Text("\(components.day ?? 0) days"))
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .foregroundStyle(Theme.navy)

                Text(String(format: "%02d:%02d:%02d", components.hour ?? 0, components.minute ?? 0, components.second ?? 0))
                    .font(.system(.title2, design: .monospaced, weight: .medium))
                    .foregroundStyle(Theme.gold)
                    .monospacedDigit()
            }
        }
    }
}

#Preview {
    RelationshipCounterView(startDate: .now.addingTimeInterval(-86_400 * 400))
}
