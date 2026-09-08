import SwiftUI

struct DecisionCardView: View {
    let decision: Decision
    let number: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("KARAR NO: \(number)")
                    .font(.system(.caption, design: .serif, weight: .bold))
                    .foregroundStyle(Theme.navy)
                Spacer()
                Image(systemName: "seal.fill")
                    .foregroundStyle(Theme.gold)
            }

            Divider().overlay(Theme.navy.opacity(0.2))

            Text(decision.title)
                .font(.system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(Theme.navy)

            Text(decision.date.dateValue().formatted(date: .long, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)

            if !decision.description.isEmpty {
                Text(decision.description)
                    .font(.subheadline)
                    .foregroundStyle(Theme.navy.opacity(0.85))
            }

            if decision.addToCalendar || decision.reminderEnabled {
                HStack(spacing: 12) {
                    if decision.addToCalendar {
                        Label("Takvimde", systemImage: "calendar")
                    }
                    if decision.reminderEnabled {
                        Label("\(decision.reminderLeadTime) gün önce", systemImage: "bell.fill")
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
}
