import SwiftUI

struct DecisionCardView: View {
    let decision: Decision

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(decision.title)
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundStyle(Theme.navy)
                Spacer()
                Image(systemName: "seal.fill")
                    .foregroundStyle(Theme.gold)
            }

            Text(dateLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !decision.description.isEmpty {
                Text(decision.description)
                    .font(.subheadline)
                    .foregroundStyle(Theme.navy.opacity(0.85))
            }

            if decision.showElapsedCounter, let date = decision.date?.dateValue() {
                ElapsedCounterView(since: date)
            }

            if decision.addToCalendar || decision.reminderEnabled {
                HStack(spacing: 12) {
                    if decision.addToCalendar {
                        Label("In Calendar", systemImage: "calendar")
                    }
                    if decision.reminderEnabled {
                        Label("Reminder on", systemImage: "bell.fill")
                    }
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.gold)
            }
        }
        .padding()
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.navy.opacity(0.12)))
    }

    private var dateLabel: String {
        guard let date = decision.date?.dateValue() else { return AppLanguage.localized("Date: unknown") }
        guard let end = decision.endDate?.dateValue(), !Calendar.current.isDate(end, inSameDayAs: date) else {
            return date.formatted(appStyle: .long)
        }
        return "\(date.formatted(appStyle: .long)) – \(end.formatted(appStyle: .long))"
    }
}

private struct ElapsedCounterView: View {
    let since: Date

    var body: some View {
        TimelineView(.periodic(from: since, by: 86_400)) { context in
            let components = Calendar.current.dateComponents([.year, .month, .day], from: since, to: context.date)
            let elapsed = [
                AppLanguage.localized("\(components.year ?? 0) years"),
                AppLanguage.localized("\(components.month ?? 0) months"),
                AppLanguage.localized("\(components.day ?? 0) days")
            ].joined(separator: ", ")

            Text("\(elapsed) have passed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.navy)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.navy.opacity(0.08))
                .clipShape(Capsule())
        }
    }
}
