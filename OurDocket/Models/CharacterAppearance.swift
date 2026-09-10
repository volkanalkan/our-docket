import SwiftUI

enum CharacterGender: String, Codable, CaseIterable, Identifiable {
    case female
    case male

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .female: "Girl"
        case .male: "Boy"
        }
    }
}

/// What's persisted at users/{uid}.character. Only ids are stored; the
/// catalog below maps them to art so the option pools can grow without a
/// data migration.
struct CharacterAppearance: Codable, Equatable {
    var gender: CharacterGender
    var hairId: String
    var skinToneId: String
    var outfitId: String

    static func defaults(for gender: CharacterGender) -> CharacterAppearance {
        CharacterAppearance(
            gender: gender,
            hairId: CharacterCatalog.hairStyles(for: gender)[0].id,
            skinToneId: CharacterCatalog.skinTones[0].id,
            outfitId: CharacterCatalog.outfits(for: gender)[0].id
        )
    }

    /// Re-rolls everything except gender, from that gender's own pools.
    static func random(for gender: CharacterGender) -> CharacterAppearance {
        CharacterAppearance(
            gender: gender,
            hairId: CharacterCatalog.hairStyles(for: gender).randomElement()!.id,
            skinToneId: CharacterCatalog.skinTones.randomElement()!.id,
            outfitId: CharacterCatalog.outfits(for: gender).randomElement()!.id
        )
    }
}

struct SkinTone: Identifiable {
    let id: String
    let color: Color
}

struct HairStyle: Identifiable {
    let id: String
    let gender: CharacterGender
    let placeholder: PlaceholderHair
    let color: Color

    /// Asset catalog name of the real sprite, once illustrated.
    var assetName: String { "hair_\(id)" }
}

struct Outfit: Identifiable {
    let id: String
    let gender: CharacterGender
    let placeholder: PlaceholderOutfit

    var assetName: String { "outfit_\(id)" }
}

/// Vector stand-ins drawn until real sprites land in the asset catalog.
enum PlaceholderHair {
    case short, buzz, sideSwept, curlyShort, fade, spiky, shoulder, manBun
    case long, bob, bun, ponytail, curly, bangs, twinTails, wavy
}

struct PlaceholderOutfit {
    enum Kind {
        case separates
        case dress
    }

    let kind: Kind
    let top: Color
    let bottom: Color
    let shoes: Color
}

/// Every option the creator offers. Sprites are looked up by asset name
/// (`body_female`, `body_male`, `hair_f01`…, `outfit_m08`…) and fall back to
/// the vector placeholder when the asset isn't in the catalog yet — so the
/// art can be dropped in one file at a time. Expected canvas: 480×800 px,
/// transparent, all layers aligned to the same body template; the body
/// itself is a single-color tintable silhouette.
enum CharacterCatalog {
    static let skinTones: [SkinTone] = [
        SkinTone(id: "tone1", color: Color(hex: "F6D7C3")),
        SkinTone(id: "tone2", color: Color(hex: "E8B896")),
        SkinTone(id: "tone3", color: Color(hex: "C68F63")),
        SkinTone(id: "tone4", color: Color(hex: "8D5A3B")),
        SkinTone(id: "tone5", color: Color(hex: "5C3A25"))
    ]

    static let hairStyles: [HairStyle] = [
        HairStyle(id: "f01", gender: .female, placeholder: .long, color: HairColor.brown),
        HairStyle(id: "f02", gender: .female, placeholder: .bob, color: HairColor.black),
        HairStyle(id: "f03", gender: .female, placeholder: .bun, color: HairColor.blonde),
        HairStyle(id: "f04", gender: .female, placeholder: .ponytail, color: HairColor.auburn),
        HairStyle(id: "f05", gender: .female, placeholder: .curly, color: HairColor.darkBrown),
        HairStyle(id: "f06", gender: .female, placeholder: .bangs, color: HairColor.black),
        HairStyle(id: "f07", gender: .female, placeholder: .twinTails, color: HairColor.chestnut),
        HairStyle(id: "f08", gender: .female, placeholder: .wavy, color: HairColor.blonde),
        HairStyle(id: "m01", gender: .male, placeholder: .short, color: HairColor.brown),
        HairStyle(id: "m02", gender: .male, placeholder: .buzz, color: HairColor.black),
        HairStyle(id: "m03", gender: .male, placeholder: .sideSwept, color: HairColor.blonde),
        HairStyle(id: "m04", gender: .male, placeholder: .curlyShort, color: HairColor.darkBrown),
        HairStyle(id: "m05", gender: .male, placeholder: .fade, color: HairColor.black),
        HairStyle(id: "m06", gender: .male, placeholder: .spiky, color: HairColor.chestnut),
        HairStyle(id: "m07", gender: .male, placeholder: .shoulder, color: HairColor.brown),
        HairStyle(id: "m08", gender: .male, placeholder: .manBun, color: HairColor.darkBrown)
    ]

    static let outfits: [Outfit] = [
        Outfit(id: "f01", gender: .female, placeholder: .init(kind: .dress, top: Color(hex: "C0392B"), bottom: Color(hex: "C0392B"), shoes: Color(hex: "2B2118"))),
        Outfit(id: "f02", gender: .female, placeholder: .init(kind: .dress, top: Color(hex: "1B2A4A"), bottom: Color(hex: "1B2A4A"), shoes: Color(hex: "8B5E3C"))),
        Outfit(id: "f03", gender: .female, placeholder: .init(kind: .separates, top: Color(hex: "F5F1E8"), bottom: Color(hex: "3B5B8C"), shoes: Color(hex: "1B2A4A"))),
        Outfit(id: "f04", gender: .female, placeholder: .init(kind: .separates, top: Color(hex: "D9A441"), bottom: Color(hex: "2B2118"), shoes: Color(hex: "2B2118"))),
        Outfit(id: "f05", gender: .female, placeholder: .init(kind: .separates, top: Color(hex: "E8A0B4"), bottom: Color(hex: "8C8C8C"), shoes: Color(hex: "F5F1E8"))),
        Outfit(id: "f06", gender: .female, placeholder: .init(kind: .separates, top: Color(hex: "F1E6D0"), bottom: Color(hex: "6B7A3A"), shoes: Color(hex: "8B5E3C"))),
        Outfit(id: "f07", gender: .female, placeholder: .init(kind: .dress, top: Color(hex: "E9C46A"), bottom: Color(hex: "E9C46A"), shoes: Color(hex: "C29A6B"))),
        Outfit(id: "f08", gender: .female, placeholder: .init(kind: .separates, top: Color(hex: "C19A6B"), bottom: Color(hex: "2F3E6E"), shoes: Color(hex: "2B2118"))),
        Outfit(id: "m01", gender: .male, placeholder: .init(kind: .separates, top: Color(hex: "F5F1E8"), bottom: Color(hex: "3B5B8C"), shoes: Color(hex: "F5F1E8"))),
        Outfit(id: "m02", gender: .male, placeholder: .init(kind: .separates, top: Color(hex: "9CC3E4"), bottom: Color(hex: "1B2A4A"), shoes: Color(hex: "8B5E3C"))),
        Outfit(id: "m03", gender: .male, placeholder: .init(kind: .separates, top: Color(hex: "8C8C8C"), bottom: Color(hex: "2B2118"), shoes: Color(hex: "2B2118"))),
        Outfit(id: "m04", gender: .male, placeholder: .init(kind: .separates, top: Color(hex: "3A3F47"), bottom: Color(hex: "3A3F47"), shoes: Color(hex: "2B2118"))),
        Outfit(id: "m05", gender: .male, placeholder: .init(kind: .separates, top: Color(hex: "4E8B5F"), bottom: Color(hex: "B9A77A"), shoes: Color(hex: "8B5E3C"))),
        Outfit(id: "m06", gender: .male, placeholder: .init(kind: .separates, top: Color(hex: "7B2D3B"), bottom: Color(hex: "2F3E6E"), shoes: Color(hex: "2B2118"))),
        Outfit(id: "m07", gender: .male, placeholder: .init(kind: .separates, top: Color(hex: "8B5E3C"), bottom: Color(hex: "3B5B8C"), shoes: Color(hex: "8B5E3C"))),
        Outfit(id: "m08", gender: .male, placeholder: .init(kind: .separates, top: Color(hex: "2B2118"), bottom: Color(hex: "C0392B"), shoes: Color(hex: "F5F1E8")))
    ]

    static func hairStyles(for gender: CharacterGender) -> [HairStyle] {
        hairStyles.filter { $0.gender == gender }
    }

    static func outfits(for gender: CharacterGender) -> [Outfit] {
        outfits.filter { $0.gender == gender }
    }

    static func hairStyle(id: String) -> HairStyle? { hairStyles.first { $0.id == id } }
    static func outfit(id: String) -> Outfit? { outfits.first { $0.id == id } }
    static func skinTone(id: String) -> SkinTone? { skinTones.first { $0.id == id } }

    static func bodyAssetName(for gender: CharacterGender) -> String { "body_\(gender.rawValue)" }

    private enum HairColor {
        static let brown = Color(hex: "6B4226")
        static let black = Color(hex: "2B2118")
        static let blonde = Color(hex: "E3B778")
        static let auburn = Color(hex: "9C4A2B")
        static let darkBrown = Color(hex: "3E2A1E")
        static let chestnut = Color(hex: "7B4B2A")
    }
}
