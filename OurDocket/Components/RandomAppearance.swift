import SwiftUI

/// A deliberately large, hand-picked pool so that two case files rarely look
/// alike — every file gets a random icon + color at creation, previewed and
/// reshuffled (not hand-picked by the user) before saving.
enum RandomAppearance {
    static let icons: [String] = [
        "heart.fill", "heart.circle.fill", "star.fill", "star.circle.fill", "sparkles",
        "sun.max.fill", "moon.stars.fill", "moon.fill", "cloud.sun.fill", "cloud.rain.fill",
        "snowflake", "rainbow", "drop.fill", "flame.fill",
        "airplane", "car.fill", "bicycle", "sailboat.fill", "tram.fill", "bus.fill",
        "tent.fill", "mountain.2.fill", "beach.umbrella.fill", "map.fill", "globe.americas.fill",
        "camera.fill", "photo.fill", "film.fill", "tv.fill", "gamecontroller.fill",
        "gift.fill", "balloon.fill", "balloon.2.fill", "party.popper.fill", "birthday.cake.fill",
        "fork.knife", "cup.and.saucer.fill", "wineglass.fill", "takeoutbag.and.cup.and.straw.fill",
        "pawprint.fill", "leaf.fill", "house.fill", "building.2.fill",
        "music.note", "book.fill", "theatermasks.fill", "paintpalette.fill",
        "figure.walk", "figure.run", "figure.2.arms.open", "hands.sparkles.fill",
        "bag.fill", "cart.fill"
    ]

    static let colorHexes: [String] = [
        "E63946", "F4A261", "E9C46A", "2A9D8F", "264653", "9C89B8", "F0A6CA", "B5838D",
        "6D6875", "FFB4A2", "B8B8FF", "70A9A1", "5C80BC", "FF8FA3", "C9ADA7", "4A5859",
        "8D99AE", "D8A47F", "81B29A", "F2CC8F", "EF9C66", "6A0572", "118AB2", "06D6A0",
        "FFD166", "EF476F", "073B4C", "3A86FF", "8338EC", "FB5607"
    ]

    static func random() -> (icon: String, colorHex: String) {
        (icons.randomElement() ?? "folder.fill", colorHexes.randomElement() ?? "1B2A4A")
    }
}

extension Color {
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
