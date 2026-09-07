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
            return "Apple kimlik bilgisi alınamadı, lütfen tekrar deneyin."
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

    private func ensureUserDocument(uid: String, appleUserId: String, fullName: PersonNameComponents?) async throws {
        let ref = Firestore.firestore().collection("users").document(uid)
        let snapshot = try await ref.getDocument()
        guard !snapshot.exists else { return }

        let formattedName = fullName.map { PersonNameComponentsFormatter().string(from: $0) } ?? ""
        let newUser = AppUser(
            displayName: formattedName.isEmpty ? "Kullanıcı" : formattedName,
            appleUserId: appleUserId,
            coupleId: nil
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
