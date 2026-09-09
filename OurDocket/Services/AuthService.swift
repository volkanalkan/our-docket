import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseFirestore

enum AuthServiceError: LocalizedError {
    case missingIdentityToken

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken:
            return AppLanguage.localized("Apple credentials couldn't be retrieved, please try again.")
        }
    }
}

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var currentUser: FirebaseAuth.User?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
        }
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
    }

    func signIn(with appleIDCredential: ASAuthorizationAppleIDCredential, rawNonce: String) async throws {
        guard let tokenData = appleIDCredential.identityToken,
              let idTokenString = String(data: tokenData, encoding: .utf8) else {
            throw AuthServiceError.missingIdentityToken
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: rawNonce,
            fullName: appleIDCredential.fullName
        )

        let result = try await Auth.auth().signIn(with: credential)
        try await ensureUserDocument(
            uid: result.user.uid,
            appleUserId: appleIDCredential.user,
            fullName: appleIDCredential.fullName
        )
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    /// Required for App Store review (Guideline 5.1.1(v)): apps offering
    /// account creation must let the user delete their account. Shared
    /// couple data (case files, notes, decisions) intentionally isn't
    /// touched here — it belongs to the partner too, not just this user.
    /// If Firebase reports the sign-in is too old for this sensitive an
    /// operation, surface that as a clear error rather than silently
    /// re-authenticating on the user's behalf.
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await Firestore.firestore().collection("users").document(user.uid).delete()
        try await user.delete()
    }

    #if DEBUG
    /// Lets development continue on everything downstream of auth without
    /// needing a real Apple ID on hand. Compiled out of Release builds.
    func signInAnonymouslyForDebug() async throws {
        let result = try await Auth.auth().signInAnonymously()
        try await ensureUserDocument(uid: result.user.uid, appleUserId: "debug", fullName: nil)
    }
    #endif

    private func ensureUserDocument(uid: String, appleUserId: String, fullName: PersonNameComponents?) async throws {
        let ref = Firestore.firestore().collection("users").document(uid)
        let snapshot = try await ref.getDocument()
        guard !snapshot.exists else { return }

        let formattedName = fullName.map { PersonNameComponentsFormatter().string(from: $0) } ?? ""
        let newUser = AppUser(
            displayName: formattedName.isEmpty ? AppLanguage.localized("User") : formattedName,
            appleUserId: appleUserId,
            coupleId: nil,
            preferredLanguage: LanguageStore.shared.selection?.rawValue
        )
        try await ref.setData(from: newUser)
    }

    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce: \(errorCode)")
                }
                return random
            }

            for random in randoms {
                if remainingLength == 0 { break }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
