import SwiftUI

struct CaseFilesTimelineView: View {
    let coupleId: String
    @ObservedObject var viewModel: CaseFilesViewModel
    let files: [CaseFile]
    let sort: CaseFilesListView.TimelineSort
    let onEdit: (CaseFile) -> Void
    let onDelete: (CaseFile) -> Void

    /// Dated files/ranges flow chronologically (direction set by `sort`);
    /// files with no date at all don't fit a timeline, so they're pinned
    /// below it instead of interleaving arbitrarily among dated entries.
    private var orderedFiles: [CaseFile] {
        let dated = files.filter { $0.eventStartDate != nil }
            .sorted { lhs, rhs in
                let l = lhs.eventStartDate?.dateValue() ?? .distantPast
                let r = rhs.eventStartDate?.dateValue() ?? .distantPast
                return sort == .newestFirst ? l > r : l < r
            }
        let undated = files.filter { $0.eventStartDate == nil }
        return dated + undated
    }

    var body: some View {
        List {
            ForEach(Array(orderedFiles.enumerated()), id: \.element.id) { index, file in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color(hex: file.colorHex))
                            .frame(width: 10, height: 10)
                        if index < orderedFiles.count - 1 {
                            Rectangle()
                                .fill(Theme.navy.opacity(0.15))
                                .frame(width: 2)
                        }
                    }
                    .frame(width: 10)
                    .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(dateLabel(for: file))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        NavigationLink {
                            CaseFileDetailView(coupleId: coupleId, viewModel: viewModel, file: file)
                        } label: {
                            CaseFileCardView(file: file)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .swipeActions(edge: .leading) {
                    Button {
                        HapticFeedback.tap()
                        onEdit(file)
                    } label: {
                        Label("Düzenle", systemImage: "pencil")
                    }
                    .tint(Theme.navy)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        HapticFeedback.tap()
                        onDelete(file)
                    } label: {
                        Label("Sil", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func dateLabel(for file: CaseFile) -> String {
        guard let start = file.eventStartDate?.dateValue() else { return "Tarih yok" }
        guard let end = file.eventEndDate?.dateValue(), !Calendar.current.isDate(end, inSameDayAs: start) else {
            return start.formatted(date: .abbreviated, time: .omitted)
        }
        return "\(start.formatted(date: .abbreviated, time: .omitted)) – \(end.formatted(date: .abbreviated, time: .omitted))"
    }
}
