import SwiftUI

struct CaseFilesTimelineView: View {
    let coupleId: String
    @ObservedObject var viewModel: CaseFilesViewModel
    let files: [CaseFile]

    private var orderedFiles: [CaseFile] {
        files.reversed()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(orderedFiles.enumerated()), id: \.element.id) { index, file in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(Theme.gold)
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
                            Text(file.createdAt?.dateValue().formatted(date: .abbreviated, time: .omitted) ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            NavigationLink {
                                CaseFileDetailView(coupleId: coupleId, viewModel: viewModel, file: file, fileNumber: viewModel.fileNumber(for: file))
                            } label: {
                                CaseFileCardView(file: file, number: viewModel.fileNumber(for: file))
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded { HapticFeedback.tap() })
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .padding()
        }
    }
}
