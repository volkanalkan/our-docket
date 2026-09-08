import Foundation
import Combine
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class AuthViewModel: ObservableObject {
    enum AppState: Equatable {
        case loading
        case signedOut
        case needsPairing
        case needsStartDate(coupleId: String)
        case ready(coupleId: String)
    }

    @Published private(set) var state: AppState = .loading
    @Published private(set) var couple: Couple?
    @Published var errorMessage: String?

    private let authService: AuthService
    private let pairingService = PairingService()

    private var cancellables = Set<AnyCancellable>()
    private var userListener: ListenerRegistration?
    private var coupleListener: ListenerRegistration?
    private var observedCoupleId: String?

    init(authService: AuthService? = nil) {
        self.authService = authService ?? AuthService()

        self.authService.$currentUser
            .sink { [weak self] user in
                self?.handleAuthChange(user: user)
            }
            .store(in: &cancellables)
    }

    private func handleAuthChange(user: FirebaseAuth.User?) {
        userListener?.remove()
        coupleListener?.remove()
        observedCoupleId = nil

        guard let user else {
            couple = nil
            state = .signedOut
            return
        }

        userListener = Firestore.firestore().collection("users").document(user.uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let appUser = try? snapshot?.data(as: AppUser.self)
                self.handleUserDocument(coupleId: appUser?.coupleId)
            }
    }

    /// The users/{uid} listener can redeliver the same coupleId more than
    /// once (e.g. an initial cache snapshot followed by a server snapshot).
    /// Tearing down and re-attaching the couple listener on every one of
    /// those deliveries can race with our own writes to that document — a
    /// fresh listener's first fetch can momentarily miss a write that's
    /// still in flight, leaving the UI stuck until the next launch. Only
    /// touch the couple listener when the coupleId actually changes.
    private func handleUserDocument(coupleId: String?) {
        guard coupleId != observedCoupleId else { return }
        observedCoupleId = coupleId
        coupleListener?.remove()

        guard let coupleId, !coupleId.isEmpty else {
            state = .needsPairing
            return
        }

        coupleListener = Firestore.firestore().collection("couples").document(coupleId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let couple = try? snapshot?.data(as: Couple.self)
                self.couple = couple
                self.state = couple?.relationshipStartDate != nil ? .ready(coupleId: coupleId) : .needsStartDate(coupleId: coupleId)
            }
    }

    func handleSignInWithApple(result: Result<ASAuthorization, Error>, rawNonce: String) async {
        errorMessage = nil
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Beklenmeyen kimlik bilgisi türü."
                return
            }
            do {
                try await authService.signIn(with: credential, rawNonce: rawNonce)
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = error.localizedDescription
            }
        }
    }

    func signOut() {
        do {
            try authService.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    #if DEBUG
    func signInAnonymouslyForDebug() async {
        errorMessage = nil
        do {
            try await authService.signInAnonymouslyForDebug()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    #endif

    func generateInviteCode() async -> String? {
        guard let uid = authService.currentUser?.uid else { return nil }
        do {
            return try await pairingService.generateInviteCode(for: uid)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func redeemInviteCode(_ code: String) async {
        guard let uid = authService.currentUser?.uid else { return }
        errorMessage = nil
        do {
            _ = try await pairingService.redeemInviteCode(code, currentUid: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setRelationshipStartDate(_ date: Date, coupleId: String) async {
        errorMessage = nil
        do {
            try await Firestore.firestore().collection("couples").document(coupleId)
                .updateData(["relationshipStartDate": Timestamp(date: date)])
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
