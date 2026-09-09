import Foundation
import FirebaseFirestore

enum PairingError: LocalizedError {
    case invalidCode
    case codeExpired
    case cannotPairWithSelf
    case partnerAlreadyPaired

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return AppLanguage.localized("This invite code is invalid.")
        case .codeExpired:
            return AppLanguage.localized("This invite code has expired.")
        case .cannotPairWithSelf:
            return AppLanguage.localized("You can't use your own invite code.")
        case .partnerAlreadyPaired:
            return AppLanguage.localized("This person is already paired with someone else.")
        }
    }
}

@MainActor
final class PairingService {
    private let db = Firestore.firestore()

    func generateInviteCode(for uid: String) async throws -> String {
        let code = String(format: "%06d", Int.random(in: 0...999_999))
        let expiresAt = Timestamp(date: Date().addingTimeInterval(24 * 60 * 60))

        try await db.collection("inviteCodes").document(code).setData([
            "uid": uid,
            "expiresAt": expiresAt,
            "createdAt": FieldValue.serverTimestamp()
        ])
        return code
    }

    /// Creates the shared couple document and links both users to it.
    ///
    /// `users/{uid}` can normally only be written by its owner, so the
    /// security rules carve out a narrow exception: a signed-in user may
    /// update *only* another user's `coupleId` field, and only when they
    /// themselves are already a member of that target couple. That lets the
    /// redeeming side finish the handshake for the invite-code owner without
    /// opening up user documents more broadly.
    func redeemInviteCode(_ code: String, currentUid: String) async throws -> String {
        let codeRef = db.collection("inviteCodes").document(code)
        let codeSnapshot = try await codeRef.getDocument()

        guard codeSnapshot.exists,
              let ownerUid = codeSnapshot.get("uid") as? String,
              let expiresAt = codeSnapshot.get("expiresAt") as? Timestamp else {
            throw PairingError.invalidCode
        }
        guard expiresAt.dateValue() > Date() else {
            throw PairingError.codeExpired
        }
        guard ownerUid != currentUid else {
            throw PairingError.cannotPairWithSelf
        }

        let ownerSnapshot = try await db.collection("users").document(ownerUid).getDocument()
        if let existingCoupleId = ownerSnapshot.get("coupleId") as? String, !existingCoupleId.isEmpty {
            throw PairingError.partnerAlreadyPaired
        }

        let coupleRef = db.collection("couples").document()
        let newCouple = Couple(memberUids: [ownerUid, currentUid])
        try await coupleRef.setData(from: newCouple)

        try await db.collection("users").document(currentUid).updateData(["coupleId": coupleRef.documentID])
        try await db.collection("users").document(ownerUid).updateData(["coupleId": coupleRef.documentID])
        try await codeRef.delete()

        return coupleRef.documentID
    }
}
