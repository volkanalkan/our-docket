import Foundation
import SwiftUI
import PhotosUI
import FirebaseFirestore

@MainActor
final class CaseFilesViewModel: ObservableObject {
    @Published private(set) var caseFiles: [CaseFile] = []
    @Published var errorMessage: String?

    private let coupleId: String
    private let service = CaseFileService()
    private var listener: ListenerRegistration?

    init(coupleId: String) {
        self.coupleId = coupleId
        listener = Firestore.firestore().collection("couples").document(coupleId)
            .collection("caseFiles")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                self.caseFiles = snapshot?.documents.compactMap { try? $0.data(as: CaseFile.self) } ?? []
            }
    }

    deinit {
        listener?.remove()
    }

    func fileNumber(for file: CaseFile) -> Int {
        (caseFiles.firstIndex(where: { $0.id == file.id }) ?? 0) + 1
    }

    func createCaseFile(title: String, category: CaseFileCategory, createdBy: String) async -> Bool {
        errorMessage = nil
        do {
            _ = try await service.createCaseFile(coupleId: coupleId, title: title, category: category.rawValue, createdBy: createdBy)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func uploadMedia(_ items: [PhotosPickerItem], fileId: String, uploadedBy: String) async {
        errorMessage = nil
        for item in items {
            do {
                try await service.uploadMedia(item, coupleId: coupleId, fileId: fileId, uploadedBy: uploadedBy)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func downloadURL(for path: String) async throws -> URL {
        try await service.downloadURL(for: path)
    }
}
