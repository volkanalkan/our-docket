import Foundation
import SwiftUI
import PhotosUI
import FirebaseFirestore

@MainActor
final class CaseFilesViewModel: ObservableObject {
    @Published private(set) var caseFiles: [CaseFile] = []
    @Published private(set) var categories: [CaseFileCategoryOption] = []
    @Published var errorMessage: String?

    private let coupleId: String
    private let service = CaseFileService()
    private var filesListener: ListenerRegistration?
    private var categoriesListener: ListenerRegistration?
    private var didEnsureDefaultCategories = false

    init(coupleId: String) {
        self.coupleId = coupleId

        filesListener = Firestore.firestore().collection("couples").document(coupleId)
            .collection("caseFiles")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                self.caseFiles = snapshot?.documents.compactMap { try? $0.data(as: CaseFile.self) } ?? []
            }

        categoriesListener = Firestore.firestore().collection("couples").document(coupleId)
            .collection("caseFileCategories")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                self.categories = snapshot?.documents.compactMap { try? $0.data(as: CaseFileCategoryOption.self) } ?? []
                if self.categories.isEmpty, !self.didEnsureDefaultCategories {
                    self.didEnsureDefaultCategories = true
                    Task { try? await self.service.ensureDefaultCategories(coupleId: self.coupleId) }
                }
            }
    }

    deinit {
        filesListener?.remove()
        categoriesListener?.remove()
    }

    func fileNumber(for file: CaseFile) -> Int {
        (caseFiles.firstIndex(where: { $0.id == file.id }) ?? 0) + 1
    }

    func createCaseFile(
        title: String,
        category: String,
        createdBy: String,
        iconName: String,
        colorHex: String,
        eventStartDate: Date?,
        eventEndDate: Date?
    ) async -> Bool {
        errorMessage = nil
        do {
            _ = try await service.createCaseFile(
                coupleId: coupleId, title: title, category: category, createdBy: createdBy,
                iconName: iconName, colorHex: colorHex,
                eventStartDate: eventStartDate, eventEndDate: eventEndDate
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateCaseFile(
        _ file: CaseFile,
        title: String,
        category: String,
        iconName: String,
        colorHex: String,
        eventStartDate: Date?,
        eventEndDate: Date?
    ) async -> Bool {
        guard let fileId = file.id else { return false }
        errorMessage = nil
        do {
            try await service.updateCaseFile(
                coupleId: coupleId, fileId: fileId, title: title, category: category,
                iconName: iconName, colorHex: colorHex,
                eventStartDate: eventStartDate, eventEndDate: eventEndDate
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteCaseFile(_ file: CaseFile) async {
        guard let fileId = file.id else { return }
        do {
            try await service.deleteCaseFile(coupleId: coupleId, fileId: fileId)
        } catch {
            errorMessage = error.localizedDescription
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

    func deleteMedia(_ item: MediaItem, from file: CaseFile) async {
        guard let fileId = file.id else { return }
        do {
            try await service.deleteMedia(item, coupleId: coupleId, fileId: fileId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func downloadURL(for path: String) async throws -> URL {
        try await service.downloadURL(for: path)
    }

    // MARK: - Categories

    func createCategory(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await service.createCategory(coupleId: coupleId, name: trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameCategory(_ category: CaseFileCategoryOption, newName: String) async {
        guard let categoryId = category.id else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await service.renameCategory(coupleId: coupleId, categoryId: categoryId, newName: trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCategory(_ category: CaseFileCategoryOption) async {
        guard let categoryId = category.id else { return }
        do {
            try await service.deleteCategory(coupleId: coupleId, categoryId: categoryId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
