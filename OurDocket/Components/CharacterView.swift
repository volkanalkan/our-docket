import SwiftUI
import UIKit

enum CharacterCrop {
    case fullBody
    /// Collar-up square: head + hair, used as the profile picture.
    case head

    /// Design-space region, in the 240×400 template coordinates every
    /// layer is authored against.
    var designRect: CGRect {
        switch self {
        case .fullBody: CGRect(x: 0, y: 0, width: 240, height: 400)
        case .head: CGRect(x: 20, y: 0, width: 200, height: 200)
        }
    }
}

/// Composites the character from independent layers (tinted body → outfit
/// → hair) so N hair × M outfits × 5 tones needs N + M + 2 images, not
/// their product. Each layer draws the illustrated sprite if it exists in
/// the asset catalog and the procedural chibi drawing otherwise.
struct CharacterView: View {
    let appearance: CharacterAppearance
    var crop: CharacterCrop = .fullBody

    var body: some View {
        Canvas { context, size in
            let design = crop.designRect
            let scale = min(size.width / design.width, size.height / design.height)
            context.translateBy(x: (size.width - design.width * scale) / 2, y: (size.height - design.height * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -design.minX, y: -design.minY)
            CharacterPainter(appearance: appearance, scale: scale).draw(in: &context)
        }
        .aspectRatio(crop.designRect.size, contentMode: .fit)
    }
}

private enum CharacterAssets {
    private static var cache: [String: Bool] = [:]

    static func image(named name: String) -> Image? {
        if cache[name] == nil {
            cache[name] = UIImage(named: name) != nil
        }
        return cache[name] == true ? Image(name) : nil
    }
}

/// Chibi proportions (head ≈ 40% of height), flat colors, one shade step,
/// a highlight and an ink outline — the classic 2D game-sprite look.
/// Everything is authored in the 240×400 template; the ground line is
/// y = 372.
private struct CharacterPainter {
    let appearance: CharacterAppearance
    let scale: CGFloat

    private static let template = CharacterCrop.fullBody.designRect
    private static let ink = Color(hex: "2B2118")
    private static let blush = Color(hex: "F08A8A")
    private static let iris = Color(hex: "3B2A20")

    // Template geometry
    private static let headRect = CGRect(x: 48, y: 40, width: 144, height: 152)
    private static let armLeft = (CGPoint(x: 86, y: 208), CGPoint(x: 60, y: 288))
    private static let armRight = (CGPoint(x: 154, y: 208), CGPoint(x: 180, y: 288))
    private static let legLeftX: CGFloat = 101
    private static let legRightX: CGFloat = 139
    private static let shoeLeft = CGRect(x: 80, y: 350, width: 42, height: 22)
    private static let shoeRight = CGRect(x: 118, y: 350, width: 42, height: 22)

    private var torsoRect: CGRect {
        appearance.gender == .female
            ? CGRect(x: 80, y: 196, width: 80, height: 100)
            : CGRect(x: 74, y: 196, width: 92, height: 100)
    }

    /// Outline stays legible at sprite sizes instead of vanishing.
    private var outlineWidth: CGFloat { max(3, 1.1 / scale) }

    private var tone: Color {
        (CharacterCatalog.skinTone(id: appearance.skinToneId) ?? CharacterCatalog.skinTones[0]).color
    }

    private var hair: HairStyle? { CharacterCatalog.hairStyle(id: appearance.hairId) }
    private var outfit: Outfit? { CharacterCatalog.outfit(id: appearance.outfitId) }

    private var hasBodyAsset: Bool {
        CharacterAssets.image(named: CharacterCatalog.bodyAssetName(for: appearance.gender)) != nil
    }

    func draw(in c: inout GraphicsContext) {
        if let image = CharacterAssets.image(named: CharacterCatalog.bodyAssetName(for: appearance.gender)) {
            drawHairBack(&c)
            var resolved = c.resolve(image.renderingMode(.template))
            resolved.shading = .color(tone)
            c.draw(resolved, in: Self.template)
            drawOutfitAsset(&c)
            drawHairFront(&c)
            return
        }

        let style = outfit?.style
        drawHairBack(&c)
        drawLegs(&c)
        if let style { drawOutfitLegs(&c, style) }
        drawTorso(&c)
        if let style { drawOutfitTorso(&c, style) }
        drawArms(&c)
        if let style { drawOutfitSleeves(&c, style) }
        drawHead(&c)
        drawFace(&c)
        drawHairFront(&c)
    }

    // MARK: - Drawing helpers

    private func shape(_ c: inout GraphicsContext, _ path: Path, _ color: Color) {
        c.fill(path, with: .color(color))
        outline(&c, path)
    }

    private func outline(_ c: inout GraphicsContext, _ path: Path) {
        c.stroke(path, with: .color(Self.ink.opacity(0.9)), style: StrokeStyle(lineWidth: outlineWidth, lineCap: .round, lineJoin: .round))
    }

    private func shade(_ c: inout GraphicsContext, _ path: Path, _ region: CGRect, opacity: Double = 0.12) {
        c.drawLayer { layer in
            layer.clip(to: path)
            layer.fill(Path(ellipseIn: region), with: .color(.black.opacity(opacity)))
        }
    }

    private func highlight(_ c: inout GraphicsContext, _ path: Path, _ region: CGRect, opacity: Double = 0.22) {
        c.drawLayer { layer in
            layer.clip(to: path)
            layer.fill(Path(ellipseIn: region), with: .color(.white.opacity(opacity)))
        }
    }

    private func capsule(_ a: CGPoint, _ b: CGPoint, width: CGFloat) -> Path {
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        return path.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    private func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }

    // MARK: - Body

    private func drawLegs(_ c: inout GraphicsContext) {
        let legs = capsule(CGPoint(x: Self.legLeftX, y: 286), CGPoint(x: Self.legLeftX, y: 354), width: 28)
            .union(capsule(CGPoint(x: Self.legRightX, y: 286), CGPoint(x: Self.legRightX, y: 354), width: 28))
        shape(&c, legs, tone)
    }

    private func drawTorso(_ c: inout GraphicsContext) {
        let torso = Path(roundedRect: torsoRect, cornerRadius: 26)
        shape(&c, torso, tone)
    }

    private func drawArms(_ c: inout GraphicsContext) {
        let arms = capsule(Self.armLeft.0, Self.armLeft.1, width: 22)
            .union(capsule(Self.armRight.0, Self.armRight.1, width: 22))
        shape(&c, arms, tone)
    }

    private func drawHead(_ c: inout GraphicsContext) {
        shape(&c, Path(CGRect(x: 106, y: 178, width: 28, height: 24)), tone)
        let ears = Path(ellipseIn: CGRect(x: 40, y: 108, width: 22, height: 26))
            .union(Path(ellipseIn: CGRect(x: 178, y: 108, width: 22, height: 26)))
        shape(&c, ears, tone)
        let head = Path(ellipseIn: Self.headRect)
        shape(&c, head, tone)
        shade(&c, head, CGRect(x: 40, y: 146, width: 160, height: 70), opacity: 0.1)
        highlight(&c, head, CGRect(x: 62, y: 52, width: 60, height: 40), opacity: 0.18)
    }

    private func drawFace(_ c: inout GraphicsContext) {
        let ink = GraphicsContext.Shading.color(Self.ink)
        for x in [CGFloat(84), CGFloat(126)] {
            let white = Path(ellipseIn: CGRect(x: x, y: 104, width: 30, height: 36))
            c.fill(white, with: .color(.white))
            c.stroke(white, with: .color(Self.ink.opacity(0.8)), lineWidth: outlineWidth * 0.7)
            c.fill(Path(ellipseIn: CGRect(x: x + 6, y: 110, width: 20, height: 26)), with: .color(Self.iris))
            c.fill(Path(ellipseIn: CGRect(x: x + 10, y: 118, width: 11, height: 14)), with: ink)
            c.fill(Path(ellipseIn: CGRect(x: x + 9, y: 112, width: 8, height: 8)), with: .color(.white))
            c.fill(Path(ellipseIn: CGRect(x: x + 18, y: 126, width: 4, height: 4)), with: .color(.white))
        }

        var browLeft = Path()
        browLeft.move(to: CGPoint(x: 86, y: 98))
        browLeft.addQuadCurve(to: CGPoint(x: 112, y: 96), control: CGPoint(x: 99, y: 88))
        var browRight = Path()
        browRight.move(to: CGPoint(x: 128, y: 96))
        browRight.addQuadCurve(to: CGPoint(x: 154, y: 98), control: CGPoint(x: 141, y: 88))
        let browStyle = StrokeStyle(lineWidth: outlineWidth * 1.1, lineCap: .round)
        c.stroke(browLeft, with: .color(Self.ink.opacity(0.75)), style: browStyle)
        c.stroke(browRight, with: .color(Self.ink.opacity(0.75)), style: browStyle)

        c.fill(Path(ellipseIn: CGRect(x: 66, y: 138, width: 24, height: 13)), with: .color(Self.blush.opacity(0.45)))
        c.fill(Path(ellipseIn: CGRect(x: 150, y: 138, width: 24, height: 13)), with: .color(Self.blush.opacity(0.45)))

        var smile = Path()
        smile.move(to: CGPoint(x: 110, y: 154))
        smile.addQuadCurve(to: CGPoint(x: 130, y: 154), control: CGPoint(x: 120, y: 166))
        c.stroke(smile, with: ink, style: StrokeStyle(lineWidth: outlineWidth, lineCap: .round))
    }

    // MARK: - Outfit

    private func drawOutfitAsset(_ c: inout GraphicsContext) {
        guard let outfit, let image = CharacterAssets.image(named: outfit.assetName) else { return }
        c.draw(c.resolve(image), in: Self.template)
    }

    private func drawShoes(_ c: inout GraphicsContext, _ color: Color) {
        for rect in [Self.shoeLeft, Self.shoeRight] {
            let shoe = Path(roundedRect: rect, cornerRadius: 10)
            shape(&c, shoe, color)
            var sole = Path()
            sole.move(to: CGPoint(x: rect.minX + 4, y: rect.maxY - 6))
            sole.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.maxY - 6))
            c.stroke(sole, with: .color(.white.opacity(0.35)), lineWidth: outlineWidth)
        }
    }

    private func pants(_ c: inout GraphicsContext, _ color: Color, to bottom: CGFloat = 352) {
        let path = capsule(CGPoint(x: Self.legLeftX, y: 284), CGPoint(x: Self.legLeftX, y: bottom), width: 32)
            .union(capsule(CGPoint(x: Self.legRightX, y: 284), CGPoint(x: Self.legRightX, y: bottom), width: 32))
            .union(Path(roundedRect: CGRect(x: torsoRect.minX + 4, y: 276, width: torsoRect.width - 8, height: 30), cornerRadius: 10))
        shape(&c, path, color)
    }

    private func skirt(_ c: inout GraphicsContext, _ color: Color, hem: CGFloat, bottom: CGFloat, pleats: Bool) {
        var path = Path()
        path.move(to: CGPoint(x: torsoRect.minX + 2, y: 280))
        path.addLine(to: CGPoint(x: torsoRect.maxX - 2, y: 280))
        path.addLine(to: CGPoint(x: 120 + hem / 2, y: bottom))
        path.addQuadCurve(to: CGPoint(x: 120 - hem / 2, y: bottom), control: CGPoint(x: 120, y: bottom + 10))
        path.closeSubpath()
        shape(&c, path, color)
        if pleats {
            for x in stride(from: CGFloat(100), through: 140, by: 20) {
                var line = Path()
                line.move(to: CGPoint(x: x, y: 286))
                line.addLine(to: CGPoint(x: 120 + (x - 120) * 1.5, y: bottom - 4))
                c.stroke(line, with: .color(.black.opacity(0.15)), lineWidth: outlineWidth * 0.8)
            }
        }
    }

    private func dress(_ c: inout GraphicsContext, _ color: Color, neckline: CGFloat, hem: CGFloat, bottom: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: torsoRect.minX, y: neckline))
        path.addLine(to: CGPoint(x: torsoRect.maxX, y: neckline))
        path.addLine(to: CGPoint(x: 120 + hem / 2, y: bottom))
        path.addQuadCurve(to: CGPoint(x: 120 - hem / 2, y: bottom), control: CGPoint(x: 120, y: bottom + 12))
        path.closeSubpath()
        shape(&c, path, color)
        return path
    }

    private func topBody(_ c: inout GraphicsContext, _ color: Color, from top: CGFloat = 196, to bottom: CGFloat = 296) -> Path {
        let path = Path(roundedRect: CGRect(x: torsoRect.minX, y: top, width: torsoRect.width, height: bottom - top), cornerRadius: 22)
        shape(&c, path, color)
        shade(&c, path, CGRect(x: torsoRect.midX + 10, y: top - 10, width: torsoRect.width, height: bottom - top + 20), opacity: 0.08)
        return path
    }

    private func sleeves(_ c: inout GraphicsContext, _ color: Color, length: CGFloat) {
        let left = capsule(Self.armLeft.0, lerp(Self.armLeft.0, Self.armLeft.1, length), width: 27)
        let right = capsule(Self.armRight.0, lerp(Self.armRight.0, Self.armRight.1, length), width: 27)
        shape(&c, left.union(right), color)
    }

    private func collar(_ c: inout GraphicsContext, _ color: Color) {
        let left = polygon([CGPoint(x: 104, y: 196), CGPoint(x: 120, y: 214), CGPoint(x: 98, y: 214)])
        let right = polygon([CGPoint(x: 136, y: 196), CGPoint(x: 142, y: 214), CGPoint(x: 120, y: 214)])
        shape(&c, left.union(right), color)
    }

    private func buttons(_ c: inout GraphicsContext, _ color: Color, x: CGFloat = 120, ys: [CGFloat]) {
        for y in ys {
            let button = Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8))
            c.fill(button, with: .color(color))
            c.stroke(button, with: .color(Self.ink.opacity(0.6)), lineWidth: outlineWidth * 0.6)
        }
    }

    private func stripes(_ c: inout GraphicsContext, in path: Path, color: Color, vertical: Bool) {
        c.drawLayer { layer in
            layer.clip(to: path)
            for offset in stride(from: CGFloat(0), through: 400, by: 18) {
                var line = Path()
                if vertical {
                    line.move(to: CGPoint(x: offset, y: 0))
                    line.addLine(to: CGPoint(x: offset, y: 400))
                } else {
                    line.move(to: CGPoint(x: 0, y: offset))
                    line.addLine(to: CGPoint(x: 240, y: offset))
                }
                layer.stroke(line, with: .color(color.opacity(0.6)), lineWidth: 6)
            }
        }
    }

    private func drawOutfitLegs(_ c: inout GraphicsContext, _ style: OutfitStyle) {
        switch style.kind {
        case .teeJeans, .sweater, .hoodie, .suit, .jacket, .tracksuit, .poloChinos, .coat:
            pants(&c, style.secondary)
        case .vestShirt:
            pants(&c, style.accent)
        case .overalls, .jumpsuit:
            pants(&c, style.primary)
        case .pajamas:
            pants(&c, style.primary)
            let legs = capsule(CGPoint(x: Self.legLeftX, y: 284), CGPoint(x: Self.legLeftX, y: 352), width: 32)
                .union(capsule(CGPoint(x: Self.legRightX, y: 284), CGPoint(x: Self.legRightX, y: 352), width: 32))
            stripes(&c, in: legs, color: style.secondary, vertical: true)
        case .shorts:
            pants(&c, style.secondary, to: 318)
        case .skirtTop:
            skirt(&c, style.secondary, hem: 132, bottom: 332, pleats: true)
        case .cardiganSkirt:
            skirt(&c, style.secondary, hem: 124, bottom: 326, pleats: false)
        case .dressA, .sundress, .sweaterDress, .robe:
            break
        }
        drawShoes(&c, style.shoes)
    }

    private func drawOutfitTorso(_ c: inout GraphicsContext, _ style: OutfitStyle) {
        switch style.kind {
        case .teeJeans:
            let body = topBody(&c, style.primary)
            c.fill(Path(ellipseIn: CGRect(x: 106, y: 190, width: 28, height: 14)), with: .color(style.accent.opacity(0.9)))
            highlight(&c, body, CGRect(x: torsoRect.minX - 10, y: 200, width: 50, height: 60), opacity: 0.1)
        case .sweater:
            let body = topBody(&c, style.primary)
            c.stroke(Path(ellipseIn: CGRect(x: 104, y: 188, width: 32, height: 16)), with: .color(style.accent), lineWidth: outlineWidth * 1.6)
            stripes(&c, in: Path(CGRect(x: torsoRect.minX, y: 282, width: torsoRect.width, height: 14)), color: style.accent, vertical: true)
            _ = body
        case .dressA:
            let body = dress(&c, style.primary, neckline: 196, hem: 158, bottom: 342)
            c.fill(Path(roundedRect: CGRect(x: torsoRect.minX + 4, y: 250, width: torsoRect.width - 8, height: 9), cornerRadius: 4), with: .color(style.accent))
            highlight(&c, body, CGRect(x: 60, y: 260, width: 50, height: 80), opacity: 0.1)
        case .sundress:
            _ = dress(&c, style.primary, neckline: 216, hem: 150, bottom: 340)
            shape(&c, capsule(CGPoint(x: torsoRect.minX + 12, y: 196), CGPoint(x: torsoRect.minX + 14, y: 218), width: 8), style.primary)
            shape(&c, capsule(CGPoint(x: torsoRect.maxX - 12, y: 196), CGPoint(x: torsoRect.maxX - 14, y: 218), width: 8), style.primary)
            var hem = Path()
            hem.move(to: CGPoint(x: 52, y: 326))
            hem.addQuadCurve(to: CGPoint(x: 188, y: 326), control: CGPoint(x: 120, y: 336))
            c.stroke(hem, with: .color(style.accent.opacity(0.8)), lineWidth: outlineWidth * 1.4)
        case .skirtTop:
            _ = topBody(&c, style.primary, to: 284)
            collar(&c, style.accent)
        case .hoodie:
            shape(&c, Path(roundedRect: CGRect(x: torsoRect.minX - 6, y: 176, width: torsoRect.width + 12, height: 44), cornerRadius: 20), style.primary)
            _ = topBody(&c, style.primary)
            shape(&c, Path(roundedRect: CGRect(x: 94, y: 256, width: 52, height: 28), cornerRadius: 10), style.primary)
            shade(&c, Path(roundedRect: CGRect(x: 94, y: 256, width: 52, height: 28), cornerRadius: 10), CGRect(x: 80, y: 240, width: 80, height: 60), opacity: 0.12)
            for x in [CGFloat(112), CGFloat(128)] {
                shape(&c, capsule(CGPoint(x: x, y: 206), CGPoint(x: x, y: 236), width: 5), style.accent)
            }
        case .overalls:
            _ = topBody(&c, style.secondary)
            shape(&c, Path(roundedRect: CGRect(x: 96, y: 216, width: 48, height: 80), cornerRadius: 6), style.primary)
            shape(&c, capsule(CGPoint(x: 100, y: 218), CGPoint(x: 94, y: 198), width: 8), style.primary)
            shape(&c, capsule(CGPoint(x: 140, y: 218), CGPoint(x: 146, y: 198), width: 8), style.primary)
            buttons(&c, style.accent, x: 102, ys: [222])
            buttons(&c, style.accent, x: 138, ys: [222])
        case .suit:
            let body = topBody(&c, style.primary)
            let shirt = polygon([CGPoint(x: 104, y: 196), CGPoint(x: 136, y: 196), CGPoint(x: 120, y: 244)])
            c.fill(shirt, with: .color(.white))
            shape(&c, polygon([CGPoint(x: 104, y: 196), CGPoint(x: 120, y: 240), CGPoint(x: 96, y: 232)]), style.primary)
            shape(&c, polygon([CGPoint(x: 136, y: 196), CGPoint(x: 144, y: 232), CGPoint(x: 120, y: 240)]), style.primary)
            shape(&c, polygon([CGPoint(x: 116, y: 202), CGPoint(x: 124, y: 202), CGPoint(x: 126, y: 246), CGPoint(x: 120, y: 254), CGPoint(x: 114, y: 246)]), style.accent)
            buttons(&c, style.secondary, ys: [262, 276])
            _ = body
        case .jacket:
            shape(&c, Path(CGRect(x: 104, y: 196, width: 32, height: 100)), style.accent)
            let left = Path(roundedRect: CGRect(x: torsoRect.minX, y: 196, width: 36, height: 100), cornerRadius: 18)
            let right = Path(roundedRect: CGRect(x: torsoRect.maxX - 36, y: 196, width: 36, height: 100), cornerRadius: 18)
            shape(&c, left.union(right), style.primary)
        case .shorts:
            _ = topBody(&c, style.primary)
            c.fill(Path(ellipseIn: CGRect(x: 106, y: 190, width: 28, height: 14)), with: .color(style.accent.opacity(0.9)))
        case .tracksuit:
            let body = topBody(&c, style.primary)
            var zipper = Path()
            zipper.move(to: CGPoint(x: 120, y: 200))
            zipper.addLine(to: CGPoint(x: 120, y: 292))
            c.stroke(zipper, with: .color(style.accent), style: StrokeStyle(lineWidth: outlineWidth, dash: [6, 4]))
            collar(&c, style.primary)
            _ = body
        case .cardiganSkirt:
            shape(&c, Path(CGRect(x: 100, y: 196, width: 40, height: 88)), style.accent)
            let left = Path(roundedRect: CGRect(x: torsoRect.minX, y: 196, width: 34, height: 92), cornerRadius: 16)
            let right = Path(roundedRect: CGRect(x: torsoRect.maxX - 34, y: 196, width: 34, height: 92), cornerRadius: 16)
            shape(&c, left.union(right), style.primary)
            buttons(&c, style.secondary, x: torsoRect.minX + 26, ys: [230, 250, 270])
        case .coat:
            let body = Path(roundedRect: CGRect(x: torsoRect.minX - 4, y: 196, width: torsoRect.width + 8, height: 136), cornerRadius: 24)
            shape(&c, body, style.primary)
            shade(&c, body, CGRect(x: torsoRect.midX + 6, y: 190, width: 80, height: 150), opacity: 0.08)
            buttons(&c, style.secondary, ys: [232, 258, 284])
            shape(&c, capsule(CGPoint(x: 96, y: 192), CGPoint(x: 144, y: 192), width: 16), style.accent)
            shape(&c, capsule(CGPoint(x: 138, y: 196), CGPoint(x: 146, y: 236), width: 14), style.accent)
        case .pajamas:
            let body = topBody(&c, style.primary)
            stripes(&c, in: body, color: style.secondary, vertical: true)
            buttons(&c, style.accent, ys: [220, 244, 268])
        case .jumpsuit:
            _ = topBody(&c, style.primary)
            collar(&c, style.primary)
            c.fill(Path(roundedRect: CGRect(x: torsoRect.minX + 2, y: 254, width: torsoRect.width - 4, height: 10), cornerRadius: 4), with: .color(style.accent))
        case .robe:
            var robe = Path()
            robe.move(to: CGPoint(x: torsoRect.minX - 6, y: 196))
            robe.addLine(to: CGPoint(x: torsoRect.maxX + 6, y: 196))
            robe.addLine(to: CGPoint(x: 200, y: 344))
            robe.addQuadCurve(to: CGPoint(x: 40, y: 344), control: CGPoint(x: 120, y: 356))
            robe.closeSubpath()
            shape(&c, robe, style.primary)
            shade(&c, robe, CGRect(x: 120, y: 190, width: 120, height: 170), opacity: 0.1)
            shape(&c, Path(roundedRect: CGRect(x: 108, y: 194, width: 11, height: 30), cornerRadius: 3), style.accent)
            shape(&c, Path(roundedRect: CGRect(x: 121, y: 194, width: 11, height: 30), cornerRadius: 3), style.accent)
        case .sweaterDress:
            let body = dress(&c, style.primary, neckline: 196, hem: 132, bottom: 330)
            stripes(&c, in: body, color: style.accent.opacity(0.35), vertical: false)
            shape(&c, Path(roundedRect: CGRect(x: 102, y: 180, width: 36, height: 22), cornerRadius: 10), style.primary)
        case .poloChinos:
            _ = topBody(&c, style.primary)
            collar(&c, style.accent)
            buttons(&c, style.accent, ys: [220, 232])
        case .vestShirt:
            _ = topBody(&c, style.secondary)
            let vest = Path(roundedRect: CGRect(x: 92, y: 200, width: 56, height: 92), cornerRadius: 12)
            shape(&c, vest, style.primary)
            c.fill(polygon([CGPoint(x: 108, y: 200), CGPoint(x: 132, y: 200), CGPoint(x: 120, y: 236)]), with: .color(style.secondary))
            buttons(&c, style.accent, ys: [250, 268])
        }
    }

    private func drawOutfitSleeves(_ c: inout GraphicsContext, _ style: OutfitStyle) {
        switch style.kind {
        case .teeJeans, .shorts, .poloChinos, .skirtTop:
            sleeves(&c, style.primary, length: 0.35)
        case .overalls:
            sleeves(&c, style.secondary, length: 0.35)
        case .dressA:
            sleeves(&c, style.primary, length: 0.22)
        case .sundress:
            break
        case .vestShirt:
            sleeves(&c, style.secondary, length: 0.6)
        case .sweater, .hoodie, .suit, .jacket, .coat, .pajamas, .cardiganSkirt, .sweaterDress:
            sleeves(&c, style.primary, length: 1)
        case .tracksuit:
            sleeves(&c, style.primary, length: 1)
            for arm in [Self.armLeft, Self.armRight] {
                shape(&c, capsule(lerp(arm.0, arm.1, 0.05), lerp(arm.0, arm.1, 0.95), width: 5), style.accent)
            }
        case .jumpsuit:
            sleeves(&c, style.primary, length: 0.7)
        case .robe:
            let left = capsule(Self.armLeft.0, Self.armLeft.1, width: 40)
            let right = capsule(Self.armRight.0, Self.armRight.1, width: 40)
            shape(&c, left.union(right), style.primary)
        }
    }

    // MARK: - Hair

    private enum Fringe {
        case round, bangs, sideSwept, centerPart, high
    }

    private func cap(fringe: Fringe, inset: CGFloat = 0) -> Path {
        var path = Path()
        let left = CGPoint(x: 44 + inset, y: 104)
        let right = CGPoint(x: 196 - inset, y: 104)
        path.move(to: left)
        path.addQuadCurve(to: CGPoint(x: 120, y: 26 + inset), control: CGPoint(x: 36 + inset, y: 22 + inset))
        path.addQuadCurve(to: right, control: CGPoint(x: 204 - inset, y: 22 + inset))
        switch fringe {
        case .round:
            path.addQuadCurve(to: left, control: CGPoint(x: 120, y: 60))
        case .bangs:
            path.addQuadCurve(to: left, control: CGPoint(x: 120, y: 118))
        case .sideSwept:
            path.addQuadCurve(to: CGPoint(x: 62, y: 92), control: CGPoint(x: 150, y: 122))
            path.addLine(to: left)
        case .centerPart:
            path.addQuadCurve(to: CGPoint(x: 120, y: 72), control: CGPoint(x: 172, y: 68))
            path.addQuadCurve(to: left, control: CGPoint(x: 68, y: 68))
        case .high:
            path.addQuadCurve(to: left, control: CGPoint(x: 120, y: 44))
        }
        path.closeSubpath()
        return path
    }

    private func hairShape(_ c: inout GraphicsContext, _ path: Path, _ color: Color) {
        shape(&c, path, color)
        highlight(&c, path, CGRect(x: 58, y: 34, width: 70, height: 40), opacity: 0.25)
    }

    private func curls(_ c: inout GraphicsContext, along points: [CGPoint], radius: CGFloat, _ color: Color) {
        var path = Path()
        for point in points {
            path.addEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        }
        shape(&c, path, color)
    }

    private func drawHairBack(_ c: inout GraphicsContext) {
        guard let hair, CharacterAssets.image(named: hair.assetName) == nil else { return }
        let color = hair.color
        switch hair.shape {
        case .longStraight, .bangsLong, .halfUp:
            shape(&c, Path(roundedRect: CGRect(x: 50, y: 84, width: 140, height: 210), cornerRadius: 44), color)
        case .longWavy:
            shape(&c, Path(roundedRect: CGRect(x: 54, y: 84, width: 132, height: 190), cornerRadius: 44), color)
            let left = stride(from: CGFloat(110), through: 270, by: 30).map { CGPoint(x: 56 + ($0.truncatingRemainder(dividingBy: 60) == 0 ? 0 : 8), y: $0) }
            let right = stride(from: CGFloat(110), through: 270, by: 30).map { CGPoint(x: 184 - ($0.truncatingRemainder(dividingBy: 60) == 0 ? 0 : 8), y: $0) }
            curls(&c, along: left + right, radius: 18, color)
        case .lob, .shoulderLength:
            shape(&c, Path(roundedRect: CGRect(x: 50, y: 84, width: 140, height: 150), cornerRadius: 44), color)
        case .bob:
            shape(&c, Path(roundedRect: CGRect(x: 50, y: 84, width: 140, height: 116), cornerRadius: 46), color)
        case .bowl:
            shape(&c, Path(roundedRect: CGRect(x: 46, y: 80, width: 148, height: 96), cornerRadius: 48), color)
        case .highPonytail:
            shape(&c, capsule(CGPoint(x: 150, y: 56), CGPoint(x: 202, y: 200), width: 36), color)
        case .lowPonytail:
            shape(&c, capsule(CGPoint(x: 166, y: 150), CGPoint(x: 200, y: 270), width: 32), color)
        case .twinTails:
            shape(&c, capsule(CGPoint(x: 54, y: 126), CGPoint(x: 30, y: 262), width: 32).union(capsule(CGPoint(x: 186, y: 126), CGPoint(x: 210, y: 262), width: 32)), color)
        case .braids:
            let left = stride(from: CGFloat(130), through: 270, by: 24).map { CGPoint(x: 42 - ($0 - 130) * 0.08, y: $0) }
            let right = stride(from: CGFloat(130), through: 270, by: 24).map { CGPoint(x: 198 + ($0 - 130) * 0.08, y: $0) }
            curls(&c, along: left + right, radius: 15, color)
        case .curlyAfro:
            let ring = stride(from: 0.0, to: 360.0, by: 30.0).map { angle -> CGPoint in
                let radians = angle * .pi / 180
                return CGPoint(x: 120 + 84 * cos(radians), y: 104 + 80 * sin(radians))
            }
            curls(&c, along: ring, radius: 30, color)
            shape(&c, Path(ellipseIn: CGRect(x: 40, y: 24, width: 160, height: 160)), color)
        case .afro:
            let ring = stride(from: 0.0, to: 360.0, by: 36.0).map { angle -> CGPoint in
                let radians = angle * .pi / 180
                return CGPoint(x: 120 + 76 * cos(radians), y: 100 + 72 * sin(radians))
            }
            curls(&c, along: ring, radius: 26, color)
            shape(&c, Path(ellipseIn: CGRect(x: 48, y: 28, width: 144, height: 144)), color)
        case .wavyMedium:
            shape(&c, Path(roundedRect: CGRect(x: 52, y: 84, width: 136, height: 100), cornerRadius: 44), color)
        case .pixie, .bun, .spaceBuns, .buzz, .crew, .messy, .sidePart, .quiff, .undercut, .curlyShort, .manBun, .spiky, .slickBack:
            break
        }
    }

    private func drawHairFront(_ c: inout GraphicsContext) {
        guard let hair else { return }
        if let image = CharacterAssets.image(named: hair.assetName) {
            c.draw(c.resolve(image), in: Self.template)
            return
        }
        let color = hair.color
        switch hair.shape {
        case .longStraight, .lob, .bob, .shoulderLength:
            hairShape(&c, cap(fringe: .centerPart), color)
        case .longWavy, .halfUp:
            hairShape(&c, cap(fringe: .sideSwept), color)
            if hair.shape == .halfUp {
                shape(&c, Path(ellipseIn: CGRect(x: 100, y: 16, width: 40, height: 34)), color)
            }
        case .pixie:
            hairShape(&c, cap(fringe: .sideSwept), color)
            curls(&c, along: [CGPoint(x: 52, y: 118), CGPoint(x: 188, y: 118), CGPoint(x: 60, y: 96), CGPoint(x: 182, y: 96)], radius: 14, color)
        case .bun:
            hairShape(&c, cap(fringe: .round), color)
            shape(&c, Path(ellipseIn: CGRect(x: 92, y: 6, width: 56, height: 50)), color)
        case .manBun:
            hairShape(&c, cap(fringe: .high), color)
            shape(&c, Path(ellipseIn: CGRect(x: 100, y: 12, width: 40, height: 36)), color)
        case .highPonytail:
            hairShape(&c, cap(fringe: .round), color)
            shape(&c, Path(ellipseIn: CGRect(x: 142, y: 44, width: 22, height: 18)), Theme.gold)
        case .lowPonytail:
            hairShape(&c, cap(fringe: .sideSwept), color)
        case .twinTails:
            hairShape(&c, cap(fringe: .bangs), color)
            shape(&c, Path(ellipseIn: CGRect(x: 40, y: 114, width: 22, height: 18)).union(Path(ellipseIn: CGRect(x: 178, y: 114, width: 22, height: 18))), Theme.gold)
        case .braids:
            hairShape(&c, cap(fringe: .centerPart), color)
        case .bangsLong, .bowl:
            hairShape(&c, cap(fringe: .bangs), color)
        case .curlyAfro, .afro:
            hairShape(&c, cap(fringe: .round, inset: -4), color)
        case .spaceBuns:
            hairShape(&c, cap(fringe: .centerPart), color)
            shape(&c, Path(ellipseIn: CGRect(x: 40, y: 20, width: 46, height: 42)).union(Path(ellipseIn: CGRect(x: 154, y: 20, width: 46, height: 42))), color)
        case .buzz:
            c.fill(cap(fringe: .high, inset: 8), with: .color(color.opacity(0.7)))
        case .crew:
            hairShape(&c, cap(fringe: .round, inset: 4), color)
        case .messy:
            hairShape(&c, cap(fringe: .sideSwept), color)
            for (index, x) in stride(from: CGFloat(62), through: 178, by: 29).enumerated() {
                let tuft = polygon([CGPoint(x: x, y: 44), CGPoint(x: x + 12 + CGFloat(index % 2) * 6, y: 10 + CGFloat(index % 3) * 6), CGPoint(x: x + 26, y: 40)])
                shape(&c, tuft, color)
            }
        case .sidePart:
            hairShape(&c, cap(fringe: .sideSwept), color)
            var part = Path()
            part.move(to: CGPoint(x: 150, y: 34))
            part.addQuadCurve(to: CGPoint(x: 176, y: 92), control: CGPoint(x: 172, y: 56))
            c.stroke(part, with: .color(Self.ink.opacity(0.35)), lineWidth: outlineWidth * 0.8)
        case .quiff:
            hairShape(&c, cap(fringe: .high), color)
            var quiff = Path()
            quiff.move(to: CGPoint(x: 66, y: 74))
            quiff.addQuadCurve(to: CGPoint(x: 150, y: 4), control: CGPoint(x: 60, y: 6))
            quiff.addQuadCurve(to: CGPoint(x: 176, y: 78), control: CGPoint(x: 206, y: 20))
            quiff.closeSubpath()
            hairShape(&c, quiff, color)
        case .undercut:
            c.fill(cap(fringe: .high, inset: 8), with: .color(color.opacity(0.35)))
            hairShape(&c, Path(roundedRect: CGRect(x: 66, y: 22, width: 108, height: 66), cornerRadius: 30), color)
        case .curlyShort:
            hairShape(&c, cap(fringe: .round), color)
            let ring = stride(from: 195.0, through: 345.0, by: 18.75).map { angle -> CGPoint in
                let radians = angle * .pi / 180
                return CGPoint(x: 120 + 72 * cos(radians), y: 100 + 66 * sin(radians))
            }
            curls(&c, along: ring, radius: 15, color)
        case .spiky:
            hairShape(&c, cap(fringe: .high), color)
            for x in stride(from: CGFloat(60), through: 160, by: 25) {
                shape(&c, polygon([CGPoint(x: x, y: 52), CGPoint(x: x + 12, y: -2), CGPoint(x: x + 26, y: 50)]), color)
            }
        case .slickBack:
            let path = cap(fringe: .high)
            hairShape(&c, path, color)
            c.drawLayer { layer in
                layer.clip(to: path)
                for x in stride(from: CGFloat(70), through: 170, by: 25) {
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: 48))
                    line.addQuadCurve(to: CGPoint(x: x + 6, y: 96), control: CGPoint(x: x - 6, y: 72))
                    layer.stroke(line, with: .color(.white.opacity(0.18)), lineWidth: 4)
                }
            }
        case .wavyMedium:
            hairShape(&c, cap(fringe: .centerPart), color)
            curls(&c, along: [CGPoint(x: 52, y: 128), CGPoint(x: 58, y: 156), CGPoint(x: 188, y: 128), CGPoint(x: 182, y: 156)], radius: 16, color)
        }
    }
}

#Preview {
    VStack {
        HStack(spacing: 16) {
            ForEach(CharacterCatalog.hairStyles(for: .female).prefix(4)) { hair in
                CharacterView(appearance: CharacterAppearance(gender: .female, hairId: hair.id, skinToneId: "tone2", outfitId: "f0\(Int(hair.id.suffix(1))!)"))
                    .frame(height: 200)
            }
        }
        HStack(spacing: 16) {
            ForEach(CharacterCatalog.hairStyles(for: .male).prefix(4)) { hair in
                CharacterView(appearance: CharacterAppearance(gender: .male, hairId: hair.id, skinToneId: "tone3", outfitId: "m0\(Int(hair.id.suffix(1))!)"))
                    .frame(height: 200)
            }
        }
    }
    .padding()
    .background(Theme.cream)
}
