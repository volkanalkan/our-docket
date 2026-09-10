import Foundation
import FirebaseFirestore

struct AppUser: Codable, Identifiable {
    @DocumentID var id: String?
    /// The name shown to the partner — seeded from Apple's full name at
    /// sign-up, then editable in onboarding/profile.
    var displayName: String
    var appleUserId: String
    var coupleId: String?
    /// Lowercase, unique across the app; uniqueness is enforced through the
    /// `usernames/{username}` collection, not this field.
    var username: String?
    /// "en" | "tr" — the in-app choice, mirrored here so a new device picks
    /// it up without asking again.
    var preferredLanguage: String?
    var character: CharacterAppearance?
    @ServerTimestamp var createdAt: Timestamp?
}
