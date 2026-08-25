import SwiftUI

/*
  Die Web-App baut auf drei Schriften: Bebas Neue für Überschriften, Tabs und
  Buttons, Inter für Fließtext, JetBrains Mono für alle Zahlen. Ohne sie sah die
  native App nach einer anderen App aus — SF Rounded ist breit und rund, Bebas
  Neue schmal und hoch.

  Die Größen stehen hier absichtlich als feste Punktwerte: In app.css sind es
  feste px, und die Vorgabe war, dass die App exakt gleich aussieht. Deshalb
  `fixedSize` statt der mitwachsenden Variante — sonst verschiebt Dynamic Type
  das Layout gegenüber dem Web. Wer Dynamic Type will, tauscht hier
  `fixedSize:` gegen `size:` und bekommt es für die ganze App.
*/
public enum KraftFont {

    // MARK: - Familien

    public enum Family {
        public static let bebas = "BebasNeue-Regular"
        public static let interRegular = "Inter-Regular"
        public static let interMedium = "Inter-Medium"
        public static let interSemiBold = "Inter-SemiBold"
        public static let interBold = "Inter-Bold"
        public static let monoMedium = "JetBrainsMono-Medium"
        public static let monoBold = "JetBrainsMono-Bold"
    }

    /// Bebas Neue gibt es nur in einem Schnitt — genau wie im Web.
    public static func bebas(_ size: CGFloat) -> Font {
        .custom(Family.bebas, fixedSize: size)
    }

    /// Inter in den vier Schnitten, die app.css tatsächlich anfordert (400/500/600/700).
    public static func inter(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .medium:              name = Family.interMedium
        case .semibold:            name = Family.interSemiBold
        case .bold, .heavy, .black: name = Family.interBold
        default:                   name = Family.interRegular
        }
        return .custom(name, fixedSize: size)
    }

    /// JetBrains Mono in 500 und 700 — mehr nutzt das Web nicht.
    public static func mono(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .custom(weight == .medium ? Family.monoMedium : Family.monoBold, fixedSize: size)
    }
}

/*
  Die benannten Stile spiegeln die CSS-Klassen aus app.css eins zu eins wider.
  Der Name ist jeweils die Klasse, damit sich Web und App nebeneinander lesen
  und ein späterer Abgleich nicht zum Suchspiel wird.
*/
public struct KraftTextStyle {
    public let font: Font
    public let tracking: CGFloat
    public let color: Color
    public let uppercase: Bool

    public init(font: Font, tracking: CGFloat = 0, color: Color = Theme.text, uppercase: Bool = false) {
        self.font = font
        self.tracking = tracking
        self.color = color
        self.uppercase = uppercase
    }
}

public extension KraftTextStyle {

    // Kopfbereich
    static let brandTitle  = KraftTextStyle(font: KraftFont.bebas(26), tracking: 1.5)
    static let brandSub    = KraftTextStyle(font: KraftFont.inter(11), tracking: 0.5, color: Theme.muted)
    static let tabBtn      = KraftTextStyle(font: KraftFont.bebas(12.5), tracking: 0.4, color: Theme.muted)

    // Abschnitte & Chips
    static let sectionLabel = KraftTextStyle(font: KraftFont.bebas(13), tracking: 1.5, color: Theme.muted)
    static let chip         = KraftTextStyle(font: KraftFont.inter(13, .semibold))
    static let catHeader    = KraftTextStyle(font: KraftFont.bebas(17), tracking: 1, color: Theme.accent)

    // Generator
    static let stepperCount = KraftTextStyle(font: KraftFont.mono(20, .bold))
    static let rollBtn      = KraftTextStyle(font: KraftFont.bebas(20), tracking: 2, color: Theme.bg)
    static let planBadge    = KraftTextStyle(font: KraftFont.inter(10, .bold), tracking: 1, color: Theme.accent, uppercase: true)
    static let planName     = KraftTextStyle(font: KraftFont.inter(16, .semibold))
    static let planMeta     = KraftTextStyle(font: KraftFont.mono(13, .medium), color: Theme.muted)
    static let dbEqu        = KraftTextStyle(font: KraftFont.mono(10.5, .medium), color: Theme.muted)
    static let dbName       = KraftTextStyle(font: KraftFont.inter(14, .medium))
    static let controlLabel = KraftTextStyle(font: KraftFont.inter(10), tracking: 0.5, color: Theme.muted, uppercase: true)
    static let miniStepper  = KraftTextStyle(font: KraftFont.mono(13, .bold))
    static let restChip     = KraftTextStyle(font: KraftFont.mono(11, .bold), color: Theme.muted)

    // Gespeichert & Favoriten
    static let savedName = KraftTextStyle(font: KraftFont.bebas(18), tracking: 0.5)
    static let savedMeta = KraftTextStyle(font: KraftFont.inter(12), color: Theme.muted)

    // Trainingsplan
    static let progressWeek  = KraftTextStyle(font: KraftFont.bebas(22), tracking: 1)
    static let progressBadge = KraftTextStyle(font: KraftFont.mono(12, .bold), color: Theme.accent)
    static let wdLabel       = KraftTextStyle(font: KraftFont.bebas(15), tracking: 1)
    static let wdInfo        = KraftTextStyle(font: KraftFont.mono(10.5, .medium), color: Theme.muted)
    static let tlWeek        = KraftTextStyle(font: KraftFont.mono(11, .bold))
    static let tlLabel       = KraftTextStyle(font: KraftFont.bebas(10), tracking: 0.5, color: Theme.muted)
    static let dayToggle     = KraftTextStyle(font: KraftFont.bebas(17), tracking: 1)
    static let cycleLabel    = KraftTextStyle(font: KraftFont.bebas(14), tracking: 0.5, color: Theme.muted)
    static let rowName       = KraftTextStyle(font: KraftFont.inter(13, .semibold))
    static let rowCat        = KraftTextStyle(font: KraftFont.inter(10), color: Theme.muted)
    static let rowSets       = KraftTextStyle(font: KraftFont.mono(11.5, .bold), color: Theme.accent)

    // Gemeinsame Bausteine (.kw-*)
    static let kwLabel = KraftTextStyle(font: KraftFont.bebas(13), tracking: 1.95, color: Theme.muted, uppercase: true)
    static let kwBtn   = KraftTextStyle(font: KraftFont.bebas(20), tracking: 1.6, color: Theme.bg)
    static let kwTag   = KraftTextStyle(font: KraftFont.mono(11, .medium), color: Theme.accent)

    // KI-Coach & Live
    static let wizardHeadline = KraftTextStyle(font: KraftFont.bebas(24), tracking: 1)
    static let aiPlanTitle    = KraftTextStyle(font: KraftFont.bebas(21), tracking: 1)
    static let liveTitle      = KraftTextStyle(font: KraftFont.bebas(22), tracking: 1.32)
}

private struct KraftTextModifier: ViewModifier {
    let style: KraftTextStyle

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .tracking(style.tracking)
            .foregroundColor(style.color)
            .textCase(style.uppercase ? .uppercase : nil)
    }
}

public extension View {
    /// Wendet einen der CSS-Stile an: `Text("SPLIT").kwStyle(.sectionLabel)`.
    func kwStyle(_ style: KraftTextStyle) -> some View {
        modifier(KraftTextModifier(style: style))
    }
}
