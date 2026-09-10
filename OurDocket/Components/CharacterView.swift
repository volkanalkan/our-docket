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
        case .head: CGRect(x: 35, y: 8, width: 170, height: 170)
        }
    }
}

/// Composites the character from independent layers (tinted body → outfit
/// → hair) so N hair × M outfits × 5 tones needs N + M + 2 images, not
/// their product. Each layer draws the illustrated sprite if it exists in
/// the asset catalog and a vector placeholder otherwise.
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
            CharacterPainter(appearance: appearance).draw(in: &context)
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

private struct CharacterPainter {
    let appearance: CharacterAppearance

    private static let template = CharacterCrop.fullBody.designRect
    private static let faceInk = Color(hex: "2B2118")
    private static let blush = Color(hex: "F08A8A")

    private var tone: Color {
        (CharacterCatalog.skinTone(id: appearance.skinToneId) ?? CharacterCatalog.skinTones[0]).color
    }

    func draw(in context: inout GraphicsContext) {
        drawBody(&context)
        drawFace(&context)
        drawOutfit(&context)
        drawHair(&context)
    }

    // MARK: Body

    private func drawBody(_ c: inout GraphicsContext) {
        if let image = CharacterAssets.image(named: CharacterCatalog.bodyAssetName(for: appearance.gender)) {
            var resolved = c.resolve(image.renderingMode(.template))
            resolved.shading = .color(tone)
            c.draw(resolved, in: Self.template)
            return
        }

        let skin = GraphicsContext.Shading.color(tone)
        c.fill(capsule(from: CGPoint(x: 78, y: 176), to: CGPoint(x: 50, y: 290), width: 22), with: skin)
        c.fill(capsule(from: CGPoint(x: 162, y: 176), to: CGPoint(x: 190, y: 290), width: 22), with: skin)
        c.fill(capsule(from: CGPoint(x: 100, y: 270), to: CGPoint(x: 100, y: 376), width: 30), with: skin)
        c.fill(capsule(from: CGPoint(x: 140, y: 270), to: CGPoint(x: 140, y: 376), width: 30), with: skin)
        c.fill(Path(roundedRect: CGRect(x: 72, y: 156, width: 96, height: 130), cornerRadius: 28), with: skin)
        c.fill(Path(CGRect(x: 108, y: 132, width: 24, height: 30)), with: skin)
        c.fill(Path(ellipseIn: CGRect(x: 62, y: 82, width: 18, height: 20)), with: skin)
        c.fill(Path(ellipseIn: CGRect(x: 160, y: 82, width: 18, height: 20)), with: skin)
        c.fill(Path(ellipseIn: CGRect(x: 70, y: 34, width: 100, height: 108)), with: skin)
        c.fill(Path(ellipseIn: CGRect(x: 80, y: 372, width: 42, height: 18)), with: skin)
        c.fill(Path(ellipseIn: CGRect(x: 118, y: 372, width: 42, height: 18)), with: skin)
    }

    private func drawFace(_ c: inout GraphicsContext) {
        // The illustrated body carries its own face.
        guard CharacterAssets.image(named: CharacterCatalog.bodyAssetName(for: appearance.gender)) == nil else { return }

        let ink = GraphicsContext.Shading.color(Self.faceInk)
        c.fill(Path(ellipseIn: CGRect(x: 98, y: 85, width: 10, height: 11)), with: ink)
        c.fill(Path(ellipseIn: CGRect(x: 132, y: 85, width: 10, height: 11)), with: ink)
        c.fill(Path(ellipseIn: CGRect(x: 103, y: 87, width: 3, height: 3)), with: .color(.white))
        c.fill(Path(ellipseIn: CGRect(x: 137, y: 87, width: 3, height: 3)), with: .color(.white))
        c.fill(Path(ellipseIn: CGRect(x: 85, y: 100, width: 14, height: 10)), with: .color(Self.blush.opacity(0.4)))
        c.fill(Path(ellipseIn: CGRect(x: 141, y: 100, width: 14, height: 10)), with: .color(Self.blush.opacity(0.4)))

        var smile = Path()
        smile.move(to: CGPoint(x: 110, y: 112))
        smile.addQuadCurve(to: CGPoint(x: 130, y: 112), control: CGPoint(x: 120, y: 122))
        c.stroke(smile, with: ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    // MARK: Outfit

    private func drawOutfit(_ c: inout GraphicsContext) {
        guard let outfit = CharacterCatalog.outfit(id: appearance.outfitId) else { return }
        if let image = CharacterAssets.image(named: outfit.assetName) {
            c.draw(c.resolve(image), in: Self.template)
            return
        }

        let style = outfit.placeholder
        let top = GraphicsContext.Shading.color(style.top)
        let bottom = GraphicsContext.Shading.color(style.bottom)

        switch style.kind {
        case .separates:
            c.fill(capsule(from: CGPoint(x: 100, y: 262), to: CGPoint(x: 100, y: 352), width: 32), with: bottom)
            c.fill(capsule(from: CGPoint(x: 140, y: 262), to: CGPoint(x: 140, y: 352), width: 32), with: bottom)
            c.fill(Path(roundedRect: CGRect(x: 74, y: 256, width: 92, height: 34), cornerRadius: 10), with: bottom)
            c.fill(Path(roundedRect: CGRect(x: 72, y: 156, width: 96, height: 120), cornerRadius: 28), with: top)
            c.fill(capsule(from: CGPoint(x: 78, y: 176), to: CGPoint(x: 64, y: 234), width: 26), with: top)
            c.fill(capsule(from: CGPoint(x: 162, y: 176), to: CGPoint(x: 176, y: 234), width: 26), with: top)
        case .dress:
            var dress = Path()
            dress.move(to: CGPoint(x: 72, y: 170))
            dress.addQuadCurve(to: CGPoint(x: 168, y: 170), control: CGPoint(x: 120, y: 150))
            dress.addLine(to: CGPoint(x: 198, y: 326))
            dress.addQuadCurve(to: CGPoint(x: 42, y: 326), control: CGPoint(x: 120, y: 342))
            dress.closeSubpath()
            c.fill(dress, with: top)
            c.fill(capsule(from: CGPoint(x: 78, y: 176), to: CGPoint(x: 70, y: 210), width: 26), with: top)
            c.fill(capsule(from: CGPoint(x: 162, y: 176), to: CGPoint(x: 170, y: 210), width: 26), with: top)
            c.fill(Path(roundedRect: CGRect(x: 78, y: 226, width: 84, height: 7), cornerRadius: 3), with: .color(style.shoes.opacity(0.7)))
        }

        let shoes = GraphicsContext.Shading.color(style.shoes)
        c.fill(Path(ellipseIn: CGRect(x: 80, y: 372, width: 42, height: 18)), with: shoes)
        c.fill(Path(ellipseIn: CGRect(x: 118, y: 372, width: 42, height: 18)), with: shoes)
    }

    // MARK: Hair

    private func drawHair(_ c: inout GraphicsContext) {
        guard let hair = CharacterCatalog.hairStyle(id: appearance.hairId) else { return }
        if let image = CharacterAssets.image(named: hair.assetName) {
            c.draw(c.resolve(image), in: Self.template)
            return
        }

        let color = hair.color
        let fill = GraphicsContext.Shading.color(color)

        switch hair.placeholder {
        case .short:
            cap(&c, color: color, bottom: 70)
        case .buzz:
            cap(&c, color: color.opacity(0.75), bottom: 66)
        case .fade:
            cap(&c, color: color, bottom: 62)
        case .sideSwept:
            cap(&c, color: color, bottom: 66)
            var fringe = Path()
            fringe.move(to: CGPoint(x: 68, y: 62))
            fringe.addQuadCurve(to: CGPoint(x: 158, y: 50), control: CGPoint(x: 110, y: 40))
            fringe.addLine(to: CGPoint(x: 166, y: 78))
            fringe.addQuadCurve(to: CGPoint(x: 68, y: 78), control: CGPoint(x: 116, y: 88))
            fringe.closeSubpath()
            c.fill(fringe, with: fill)
        case .curlyShort:
            cap(&c, color: color, bottom: 70)
            for angle in stride(from: 200.0, through: 340.0, by: 20.0) {
                let radians = angle * .pi / 180
                let center = CGPoint(x: 120 + 54 * cos(radians), y: 82 + 50 * sin(radians))
                c.fill(Path(ellipseIn: CGRect(x: center.x - 13, y: center.y - 13, width: 26, height: 26)), with: fill)
            }
        case .spiky:
            cap(&c, color: color, bottom: 68)
            for x in stride(from: 74.0, through: 152.0, by: 22.0) {
                var spike = Path()
                spike.move(to: CGPoint(x: x, y: 46))
                spike.addLine(to: CGPoint(x: x + 11, y: 12))
                spike.addLine(to: CGPoint(x: x + 22, y: 46))
                spike.closeSubpath()
                c.fill(spike, with: fill)
            }
        case .shoulder:
            cap(&c, color: color, bottom: 72)
            c.fill(Path(roundedRect: CGRect(x: 58, y: 60, width: 28, height: 118), cornerRadius: 12), with: fill)
            c.fill(Path(roundedRect: CGRect(x: 154, y: 60, width: 28, height: 118), cornerRadius: 12), with: fill)
        case .manBun:
            cap(&c, color: color, bottom: 68)
            c.fill(Path(ellipseIn: CGRect(x: 104, y: 14, width: 32, height: 30)), with: fill)
        case .long:
            cap(&c, color: color, bottom: 72)
            c.fill(Path(roundedRect: CGRect(x: 58, y: 58, width: 30, height: 156), cornerRadius: 14), with: fill)
            c.fill(Path(roundedRect: CGRect(x: 152, y: 58, width: 30, height: 156), cornerRadius: 14), with: fill)
        case .bob:
            cap(&c, color: color, bottom: 72)
            c.fill(Path(roundedRect: CGRect(x: 58, y: 58, width: 30, height: 96), cornerRadius: 14), with: fill)
            c.fill(Path(roundedRect: CGRect(x: 152, y: 58, width: 30, height: 96), cornerRadius: 14), with: fill)
        case .bun:
            cap(&c, color: color, bottom: 72)
            c.fill(Path(ellipseIn: CGRect(x: 100, y: 8, width: 40, height: 38)), with: fill)
        case .ponytail:
            cap(&c, color: color, bottom: 72)
            c.fill(capsule(from: CGPoint(x: 172, y: 62), to: CGPoint(x: 190, y: 184), width: 24), with: fill)
            c.fill(Path(ellipseIn: CGRect(x: 163, y: 56, width: 18, height: 14)), with: .color(Theme.gold))
        case .curly:
            cap(&c, color: color, bottom: 72)
            for y in stride(from: 52.0, through: 170.0, by: 22.0) {
                c.fill(Path(ellipseIn: CGRect(x: 52, y: y, width: 32, height: 32)), with: fill)
                c.fill(Path(ellipseIn: CGRect(x: 156, y: y, width: 32, height: 32)), with: fill)
            }
        case .bangs:
            cap(&c, color: color, bottom: 72)
            c.fill(Path(roundedRect: CGRect(x: 72, y: 54, width: 96, height: 26), cornerRadius: 11), with: fill)
            c.fill(Path(roundedRect: CGRect(x: 58, y: 58, width: 30, height: 156), cornerRadius: 14), with: fill)
            c.fill(Path(roundedRect: CGRect(x: 152, y: 58, width: 30, height: 156), cornerRadius: 14), with: fill)
        case .twinTails:
            cap(&c, color: color, bottom: 72)
            c.fill(capsule(from: CGPoint(x: 62, y: 84), to: CGPoint(x: 46, y: 204), width: 24), with: fill)
            c.fill(capsule(from: CGPoint(x: 178, y: 84), to: CGPoint(x: 194, y: 204), width: 24), with: fill)
            c.fill(Path(ellipseIn: CGRect(x: 52, y: 76, width: 18, height: 14)), with: .color(Theme.gold))
            c.fill(Path(ellipseIn: CGRect(x: 170, y: 76, width: 18, height: 14)), with: .color(Theme.gold))
        case .wavy:
            cap(&c, color: color, bottom: 72)
            for (index, y) in stride(from: 56.0, through: 200.0, by: 24.0).enumerated() {
                let wobble: CGFloat = index.isMultiple(of: 2) ? 0 : 6
                c.fill(Path(ellipseIn: CGRect(x: 54 + wobble, y: y, width: 34, height: 34)), with: fill)
                c.fill(Path(ellipseIn: CGRect(x: 152 - wobble, y: y, width: 34, height: 34)), with: fill)
            }
        }
    }

    /// The part of the hair that hugs the skull: a slightly oversized head
    /// ellipse clipped above the brow line.
    private func cap(_ c: inout GraphicsContext, color: Color, bottom: CGFloat) {
        c.drawLayer { layer in
            layer.clip(to: Path(CGRect(x: 0, y: 0, width: 240, height: bottom)))
            layer.fill(Path(ellipseIn: CGRect(x: 64, y: 26, width: 112, height: 118)), with: .color(color))
        }
    }

    private func capsule(from start: CGPoint, to end: CGPoint, width: CGFloat) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round))
    }
}

#Preview {
    HStack(spacing: 24) {
        CharacterView(appearance: .defaults(for: .female)).frame(height: 300)
        CharacterView(appearance: .defaults(for: .male)).frame(height: 300)
        CharacterView(appearance: .defaults(for: .female), crop: .head).frame(width: 96, height: 96)
    }
    .padding()
    .background(Theme.cream)
}
