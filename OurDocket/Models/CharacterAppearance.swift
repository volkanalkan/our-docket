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
    let shape: HairShape
    let color: Color

    /// Asset catalog name of the illustrated sprite, once it exists.
    var assetName: String { "hair_\(id)" }
}

struct Outfit: Identifiable {
    let id: String
    let gender: CharacterGender
    let style: OutfitStyle

    var assetName: String { "outfit_\(id)" }
}

/// Procedurally drawn hair silhouettes (see CharacterPainter). Each is
/// split into a back layer (behind the body) and a front layer (over the
/// face) so long hair reads correctly.
enum HairShape {
    case longStraight, longWavy, bob, lob, pixie, bun, highPonytail, lowPonytail
    case twinTails, braids, bangsLong, curlyAfro, spaceBuns, halfUp
    case buzz, crew, messy, sidePart, quiff, undercut, curlyShort, afro
    case manBun, shoulderLength, spiky, slickBack, bowl, wavyMedium
}

enum OutfitKind {
    case teeJeans, sweater, dressA, sundress, skirtTop, hoodie, overalls, suit
    case jacket, shorts, tracksuit, cardiganSkirt, coat, pajamas, jumpsuit
    case robe, sweaterDress, poloChinos, vestShirt
}

struct OutfitStyle {
    let kind: OutfitKind
    let primary: Color
    let secondary: Color
    let accent: Color
    let shoes: Color
}

/// Every option the creator offers. Sprites are looked up by asset name
/// (`body_female`, `body_male`, `hair_f01`…, `outfit_m14`…) and fall back
/// to the procedural drawing when the asset isn't in the catalog yet, so
/// art can be dropped in one file at a time. Expected canvas: 480×800 px,
/// transparent, all layers aligned to the same body template; the body
/// itself is a single-color tintable silhouette.
enum CharacterCatalog {
    static let skinTones: [SkinTone] = [
        SkinTone(id: "tone1", color: Color(hex: "F8DCC8")),
        SkinTone(id: "tone2", color: Color(hex: "EDBE9C")),
        SkinTone(id: "tone3", color: Color(hex: "D19A6B")),
        SkinTone(id: "tone4", color: Color(hex: "A5683F")),
        SkinTone(id: "tone5", color: Color(hex: "6E4328"))
    ]

    static let hairStyles: [HairStyle] = [
        HairStyle(id: "f01", gender: .female, shape: .longStraight, color: HairColor.brown),
        HairStyle(id: "f02", gender: .female, shape: .longWavy, color: HairColor.blonde),
        HairStyle(id: "f03", gender: .female, shape: .bob, color: HairColor.black),
        HairStyle(id: "f04", gender: .female, shape: .lob, color: HairColor.auburn),
        HairStyle(id: "f05", gender: .female, shape: .pixie, color: HairColor.platinum),
        HairStyle(id: "f06", gender: .female, shape: .bun, color: HairColor.chestnut),
        HairStyle(id: "f07", gender: .female, shape: .highPonytail, color: HairColor.honey),
        HairStyle(id: "f08", gender: .female, shape: .lowPonytail, color: HairColor.darkBrown),
        HairStyle(id: "f09", gender: .female, shape: .twinTails, color: HairColor.red),
        HairStyle(id: "f10", gender: .female, shape: .braids, color: HairColor.black),
        HairStyle(id: "f11", gender: .female, shape: .bangsLong, color: HairColor.darkBrown),
        HairStyle(id: "f12", gender: .female, shape: .curlyAfro, color: HairColor.black),
        HairStyle(id: "f13", gender: .female, shape: .spaceBuns, color: HairColor.pink),
        HairStyle(id: "f14", gender: .female, shape: .halfUp, color: HairColor.lavender),
        HairStyle(id: "f15", gender: .female, shape: .bob, color: HairColor.mint),
        HairStyle(id: "f16", gender: .female, shape: .longWavy, color: HairColor.ash),
        HairStyle(id: "m01", gender: .male, shape: .crew, color: HairColor.brown),
        HairStyle(id: "m02", gender: .male, shape: .buzz, color: HairColor.black),
        HairStyle(id: "m03", gender: .male, shape: .messy, color: HairColor.darkBrown),
        HairStyle(id: "m04", gender: .male, shape: .sidePart, color: HairColor.blonde),
        HairStyle(id: "m05", gender: .male, shape: .quiff, color: HairColor.chestnut),
        HairStyle(id: "m06", gender: .male, shape: .undercut, color: HairColor.black),
        HairStyle(id: "m07", gender: .male, shape: .curlyShort, color: HairColor.darkBrown),
        HairStyle(id: "m08", gender: .male, shape: .afro, color: HairColor.black),
        HairStyle(id: "m09", gender: .male, shape: .manBun, color: HairColor.brown),
        HairStyle(id: "m10", gender: .male, shape: .shoulderLength, color: HairColor.auburn),
        HairStyle(id: "m11", gender: .male, shape: .spiky, color: HairColor.black),
        HairStyle(id: "m12", gender: .male, shape: .slickBack, color: HairColor.darkBrown),
        HairStyle(id: "m13", gender: .male, shape: .bowl, color: HairColor.honey),
        HairStyle(id: "m14", gender: .male, shape: .wavyMedium, color: HairColor.chestnut),
        HairStyle(id: "m15", gender: .male, shape: .messy, color: HairColor.platinum),
        HairStyle(id: "m16", gender: .male, shape: .quiff, color: HairColor.mint)
    ]

    static let outfits: [Outfit] = [
        Outfit(id: "f01", gender: .female, style: .init(kind: .dressA, primary: Palette.red, secondary: Palette.red, accent: Palette.cream, shoes: Palette.ink)),
        Outfit(id: "f02", gender: .female, style: .init(kind: .sundress, primary: Palette.yellow, secondary: Palette.yellow, accent: Palette.white, shoes: Palette.tan)),
        Outfit(id: "f03", gender: .female, style: .init(kind: .skirtTop, primary: Palette.white, secondary: Palette.navy, accent: Palette.gold, shoes: Palette.navy)),
        Outfit(id: "f04", gender: .female, style: .init(kind: .hoodie, primary: Palette.pink, secondary: Palette.gray, accent: Palette.white, shoes: Palette.white)),
        Outfit(id: "f05", gender: .female, style: .init(kind: .overalls, primary: Palette.denim, secondary: Palette.cream, accent: Palette.gold, shoes: Palette.brown)),
        Outfit(id: "f06", gender: .female, style: .init(kind: .teeJeans, primary: Palette.mint, secondary: Palette.denim, accent: Palette.white, shoes: Palette.white)),
        Outfit(id: "f07", gender: .female, style: .init(kind: .jacket, primary: Palette.camel, secondary: Palette.indigo, accent: Palette.cream, shoes: Palette.ink)),
        Outfit(id: "f08", gender: .female, style: .init(kind: .cardiganSkirt, primary: Palette.mustard, secondary: Palette.ink, accent: Palette.cream, shoes: Palette.brown)),
        Outfit(id: "f09", gender: .female, style: .init(kind: .coat, primary: Palette.camel, secondary: Palette.ink, accent: Palette.red, shoes: Palette.ink)),
        Outfit(id: "f10", gender: .female, style: .init(kind: .pajamas, primary: Palette.lilac, secondary: Palette.white, accent: Palette.white, shoes: Palette.pink)),
        Outfit(id: "f11", gender: .female, style: .init(kind: .jumpsuit, primary: Palette.olive, secondary: Palette.olive, accent: Palette.tan, shoes: Palette.brown)),
        Outfit(id: "f12", gender: .female, style: .init(kind: .robe, primary: Palette.navy, secondary: Palette.navy, accent: Palette.white, shoes: Palette.ink)),
        Outfit(id: "f13", gender: .female, style: .init(kind: .sweaterDress, primary: Palette.burgundy, secondary: Palette.burgundy, accent: Palette.cream, shoes: Palette.brown)),
        Outfit(id: "f14", gender: .female, style: .init(kind: .tracksuit, primary: Palette.lilac, secondary: Palette.lilac, accent: Palette.white, shoes: Palette.white)),
        Outfit(id: "f15", gender: .female, style: .init(kind: .shorts, primary: Palette.coral, secondary: Palette.denim, accent: Palette.white, shoes: Palette.white)),
        Outfit(id: "f16", gender: .female, style: .init(kind: .sweater, primary: Palette.teal, secondary: Palette.ink, accent: Palette.cream, shoes: Palette.brown)),
        Outfit(id: "m01", gender: .male, style: .init(kind: .teeJeans, primary: Palette.white, secondary: Palette.denim, accent: Palette.navy, shoes: Palette.white)),
        Outfit(id: "m02", gender: .male, style: .init(kind: .poloChinos, primary: Palette.skyBlue, secondary: Palette.tan, accent: Palette.white, shoes: Palette.brown)),
        Outfit(id: "m03", gender: .male, style: .init(kind: .hoodie, primary: Palette.gray, secondary: Palette.ink, accent: Palette.white, shoes: Palette.ink)),
        Outfit(id: "m04", gender: .male, style: .init(kind: .suit, primary: Palette.charcoal, secondary: Palette.charcoal, accent: Palette.burgundy, shoes: Palette.ink)),
        Outfit(id: "m05", gender: .male, style: .init(kind: .jacket, primary: Palette.brown, secondary: Palette.denim, accent: Palette.cream, shoes: Palette.brown)),
        Outfit(id: "m06", gender: .male, style: .init(kind: .shorts, primary: Palette.green, secondary: Palette.tan, accent: Palette.white, shoes: Palette.white)),
        Outfit(id: "m07", gender: .male, style: .init(kind: .tracksuit, primary: Palette.navy, secondary: Palette.navy, accent: Palette.red, shoes: Palette.white)),
        Outfit(id: "m08", gender: .male, style: .init(kind: .overalls, primary: Palette.denim, secondary: Palette.red, accent: Palette.gold, shoes: Palette.brown)),
        Outfit(id: "m09", gender: .male, style: .init(kind: .coat, primary: Palette.charcoal, secondary: Palette.ink, accent: Palette.mustard, shoes: Palette.ink)),
        Outfit(id: "m10", gender: .male, style: .init(kind: .pajamas, primary: Palette.skyBlue, secondary: Palette.white, accent: Palette.white, shoes: Palette.navy)),
        Outfit(id: "m11", gender: .male, style: .init(kind: .vestShirt, primary: Palette.olive, secondary: Palette.white, accent: Palette.brown, shoes: Palette.brown)),
        Outfit(id: "m12", gender: .male, style: .init(kind: .robe, primary: Palette.ink, secondary: Palette.ink, accent: Palette.white, shoes: Palette.ink)),
        Outfit(id: "m13", gender: .male, style: .init(kind: .sweater, primary: Palette.burgundy, secondary: Palette.indigo, accent: Palette.cream, shoes: Palette.ink)),
        Outfit(id: "m14", gender: .male, style: .init(kind: .jumpsuit, primary: Palette.teal, secondary: Palette.teal, accent: Palette.ink, shoes: Palette.ink)),
        Outfit(id: "m15", gender: .male, style: .init(kind: .teeJeans, primary: Palette.ink, secondary: Palette.charcoal, accent: Palette.red, shoes: Palette.white)),
        Outfit(id: "m16", gender: .male, style: .init(kind: .hoodie, primary: Palette.coral, secondary: Palette.gray, accent: Palette.white, shoes: Palette.white))
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

    enum HairColor {
        static let brown = Color(hex: "6B4226")
        static let black = Color(hex: "2B2118")
        static let blonde = Color(hex: "E8C170")
        static let auburn = Color(hex: "A4502D")
        static let darkBrown = Color(hex: "3E2A1E")
        static let chestnut = Color(hex: "7B4B2A")
        static let red = Color(hex: "C2452D")
        static let platinum = Color(hex: "F1E4C9")
        static let ash = Color(hex: "9A8F86")
        static let honey = Color(hex: "C99A4B")
        static let pink = Color(hex: "E7A2B8")
        static let lavender = Color(hex: "A98BC9")
        static let mint = Color(hex: "7FC4B0")
    }

    enum Palette {
        static let ink = Color(hex: "2B2118")
        static let white = Color(hex: "FBF8F2")
        static let cream = Color(hex: "F1E6D0")
        static let red = Color(hex: "C8433A")
        static let coral = Color(hex: "E8846B")
        static let yellow = Color(hex: "EBC65C")
        static let mustard = Color(hex: "D9A441")
        static let gold = Color(hex: "C79D2E")
        static let navy = Color(hex: "1B2A4A")
        static let indigo = Color(hex: "2F3E6E")
        static let denim = Color(hex: "4A6FA5")
        static let skyBlue = Color(hex: "9CC3E4")
        static let teal = Color(hex: "3E8E86")
        static let mint = Color(hex: "9ED4C2")
        static let green = Color(hex: "4E8B5F")
        static let olive = Color(hex: "6B7A3A")
        static let pink = Color(hex: "E8A0B4")
        static let lilac = Color(hex: "B8A6D9")
        static let burgundy = Color(hex: "7B2D3B")
        static let brown = Color(hex: "8B5E3C")
        static let camel = Color(hex: "C19A6B")
        static let tan = Color(hex: "D2B48C")
        static let gray = Color(hex: "8C8C8C")
        static let charcoal = Color(hex: "3A3F47")
    }
}
