import SwiftUI

/*
  Portierung von src/components/ExerciseVisual.jsx.

  Das Web zeichnet eine anatomische Figur in einer viewBox 0 0 100 120 und färbt
  die beanspruchte Muskelgruppe mint ein. Die bisherige native Lösung war ein
  SF-Symbol mit orangem Schein — andere Form, andere Farbe, anderer Eindruck.

  Die Koordinaten unten sind unverändert aus dem SVG übernommen.
*/
public struct ExerciseVisual: View {
    @ObservedObject private var i18n = I18n.shared

    public let category: MuscleCategory
    public let size: CGFloat
    /// `.compact` im Web: kleinerer Rahmen für die Plan-Karten.
    public let compact: Bool

    public init(category: MuscleCategory, size: CGFloat = 44, compact: Bool = true) {
        self.category = category
        self.size = size
        self.compact = compact
    }

    private static let active = Theme.accent
    private static let inactive = Color(hex: "2A2B30")
    private static let outline = Color(hex: "3E4048")
    private static let neutral = Color(hex: "32343A")

    // Die Gruppen-Flags aus dem Web, hier über das enum statt über Teilstrings.
    private var isChest: Bool     { category == .chest }
    private var isBack: Bool      { category == .back || category == .neck }
    private var isShoulders: Bool { category == .shoulders }
    private var isBiceps: Bool    { category == .biceps }
    private var isTriceps: Bool   { category == .triceps }
    private var isLegs: Bool      { category == .legs }
    private var isGlutes: Bool    { category == .glutes }
    private var isCalves: Bool    { category == .calves }
    private var isCore: Bool      { category == .core }
    private var isFullBody: Bool  { category == .fullBody }

    public var body: some View {
        VStack(spacing: 2) {
            figure
            Text(i18n.category(category))
                .font(KraftFont.bebas(compact ? 9 : 11)).tracking(1)
                .foregroundColor(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(compact ? 2 : 6)
        .background(
            RoundedRectangle(cornerRadius: compact ? 8 : 14)
                .fill(compact ? Theme.surface2 : Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 8 : 14)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private var figure: some View {
        Canvas { ctx, canvasSize in
            /*
              Das SVG ist size×size groß bei viewBox 100×120. Bei
              preserveAspectRatio "meet" bestimmt also die Höhe den Maßstab,
              und die Figur wird waagerecht zentriert.
            */
            let scale = min(canvasSize.width / 100, canvasSize.height / 120)
            let dx = (canvasSize.width - 100 * scale) / 2
            let dy = (canvasSize.height - 120 * scale) / 2
            let lineWidth = max(0.5, 1 * scale)

            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: dx + x * scale, y: dy + y * scale)
            }

            func fillStroke(_ path: Path, _ color: Color) {
                ctx.fill(path, with: .color(color))
                ctx.stroke(path, with: .color(Self.outline), lineWidth: lineWidth)
            }

            /// Polygon aus den L-Befehlen des Originals.
            func poly(_ points: [(CGFloat, CGFloat)], _ color: Color) {
                var p = Path()
                guard let first = points.first else { return }
                p.move(to: pt(first.0, first.1))
                for q in points.dropFirst() { p.addLine(to: pt(q.0, q.1)) }
                p.closeSubpath()
                fillStroke(p, color)
            }

            func on(_ active: Bool) -> Color { active ? Self.active : Self.inactive }

            // Kopf
            var head = Path()
            head.addEllipse(in: CGRect(
                x: dx + 42 * scale, y: dy + 6 * scale,
                width: 16 * scale, height: 16 * scale
            ))
            fillStroke(head, Self.neutral)

            // Nacken / Trapez
            poly([(44, 22), (56, 22), (60, 28), (40, 28)], on(isBack || isShoulders || isFullBody))

            // Schultern (Deltoide) — im Original Bezierkurven
            let shoulderColor = on(isShoulders || isChest || isFullBody)
            var lShoulder = Path()
            lShoulder.move(to: pt(38, 27))
            lShoulder.addCurve(to: pt(28, 38), control1: pt(34, 28), control2: pt(30, 32))
            lShoulder.addCurve(to: pt(40, 31), control1: pt(32, 40), control2: pt(36, 36))
            lShoulder.closeSubpath()
            fillStroke(lShoulder, shoulderColor)

            var rShoulder = Path()
            rShoulder.move(to: pt(62, 27))
            rShoulder.addCurve(to: pt(72, 38), control1: pt(66, 28), control2: pt(70, 32))
            rShoulder.addCurve(to: pt(60, 31), control1: pt(68, 40), control2: pt(64, 36))
            rShoulder.closeSubpath()
            fillStroke(rShoulder, shoulderColor)

            // Brust
            poly([(40, 30), (50, 31), (60, 30), (58, 42), (50, 44), (42, 42)], on(isChest || isFullBody))

            // Latissimus
            let backColor = on(isBack || isFullBody)
            poly([(38, 32), (42, 42), (38, 52), (34, 40)], backColor)
            poly([(62, 32), (58, 42), (62, 52), (66, 40)], backColor)

            // Oberarme
            let armColor = on(isBiceps || isTriceps || isFullBody)
            poly([(28, 38), (24, 50), (29, 50), (34, 40)], armColor)
            poly([(72, 38), (76, 50), (71, 50), (66, 40)], armColor)

            // Unterarme — im Web immer neutral
            poly([(24, 50), (20, 64), (25, 64), (29, 50)], Self.neutral)
            poly([(76, 50), (80, 64), (75, 64), (71, 50)], Self.neutral)

            // Bauch
            poly([(42, 44), (58, 44), (56, 60), (44, 60)], on(isCore || isFullBody))

            // Becken / Gesäß
            poly([(44, 60), (56, 60), (60, 68), (40, 68)], on(isGlutes || isLegs || isFullBody))

            // Oberschenkel
            let thighColor = on(isLegs || isGlutes || isFullBody)
            poly([(40, 68), (48, 68), (46, 90), (38, 90)], thighColor)
            poly([(52, 68), (60, 68), (62, 90), (54, 90)], thighColor)

            // Waden
            let calfColor = on(isCalves || isLegs || isFullBody)
            poly([(38, 92), (46, 92), (44, 114), (39, 114)], calfColor)
            poly([(54, 92), (62, 92), (61, 114), (56, 114)], calfColor)
        }
        .frame(width: size, height: size)
    }
}
