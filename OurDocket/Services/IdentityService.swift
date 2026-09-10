import Foundation
import FirebaseFirestore

enum IdentityError: LocalizedError {
    case usernameTaken

    var errorDescription: String? {
        switch self {
        case .usernameTaken:
            return AppLanguage.localized("This username is already taken.")
        }
    }
}

@MainActor
final class IdentityService {
    private let db = Firestore.firestore()

    static let usernameLengthRange = 3...20
    private static let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._")

    /// Applied on every keystroke so what the user sees is exactly what
    /// gets stored: lowercase, no "@", only [a-z0-9._], capped at 20.
    static func sanitize(_ raw: String) -> String {
        let lowered = raw.lowercased().replacingOccurrences(of: "@", with: "")
        let filtered = lowered.unicodeScalars.filter { allowedCharacters.contains($0) }
        return String(String.UnicodeScalarView(filtered).prefix(usernameLengthRange.upperBound))
    }

    static func isValidUsername(_ username: String) -> Bool {
        usernameLengthRange.contains(username.count) && sanitize(username) == username
    }

    /// Claims `username` for `uid` atomically, the same way invite codes are
    /// reserved: read `usernames/{username}` inside a transaction and only
    /// write if it's free (or already ours). A previous username is
    /// released in the same transaction so an edit can't leave both taken.
    func claim(username: String, name: String, uid: String, previousUsername: String?) async throws {
        let usernameRef = db.collection("usernames").document(username)
        let userRef = db.collection("users").document(uid)

        _ = try await db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(usernameRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            if snapshot.exists, snapshot.get("uid") as? String != uid {
                errorPointer?.pointee = IdentityError.usernameTaken as NSError
                return nil
            }

            transaction.setData(["uid": uid], forDocument: usernameRef)
            if let previousUsername, previousUsername != username {
                transaction.deleteDocument(self.db.collection("usernames").document(previousUsername))
            }
            transaction.setData(["displayName": name, "username": username], forDocument: userRef, merge: true)
            return nil
        }
    }
}
