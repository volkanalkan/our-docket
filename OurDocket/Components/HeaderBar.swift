import SwiftUI

/// A fully custom replacement for the system navigation bar. We don't use
/// `.navigationTitle`/`.toolbar` for in-app screens because system chrome
/// (the back chevron, toolbar icons) redraws itself for accessibility
/// display settings (e.g. Button Shapes / Show Borders) and for the OS's
/// own visual language — appropriate for system apps, not for the fixed
/// look this app wants everywhere, on every OS version and every setting.
struct HeaderBar<Trailing: View>: View {
    let title: String
    var showBack = true
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            if showBack {
                HeaderIconButton(systemImage: "chevron.left") {
                    dismiss()
                }
            } else {
                Color.clear.frame(width: 36, height: 36)
            }

            Text(title)
                .font(.system(.headline, design: .serif, weight: .bold))
                .foregroundStyle(Theme.navy)
                .lineLimit(1)

            Spacer()

            trailing()
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

extension HeaderBar where Trailing == EmptyView {
    init(title: String, showBack: Bool = true) {
        self.title = title
        self.showBack = showBack
        self.trailing = { EmptyView() }
    }
}

struct HeaderIconButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticFeedback.tap()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.navy)
                .frame(width: 36, height: 36)
                .background(Theme.navy.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
    }
}
