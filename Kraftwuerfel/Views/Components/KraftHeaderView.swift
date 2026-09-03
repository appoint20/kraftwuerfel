import SwiftUI

/*
  Kopfbereich: Markenzeile und darunter die KI-Coach Begrüßung für den Nutzer.
  Die Navigationsleiste ist nun in die untere Leiste (KraftBottomTabBar) gewandert.
*/

public enum KraftTab: String, CaseIterable, Identifiable {
    /*
      Vier Reiter, nicht sechs.

      Trainingsplan, Gespeichert und Favoriten waren drei eigene Reiter und
      damit drei Fünftel der Leiste — obwohl alle drei dasselbe zeigen: Pläne.
      Wer von seinem laufenden Plan zu einem gespeicherten wollte, wechselte
      den Reiter, und die untere Leiste war so voll, dass die Beschriftungen
      nicht mehr lesbar waren. Sie liegen jetzt unter `plans` zusammen, mit
      einer Segmentleiste darin.
    */
    case generator, aiCoach, plans, progress

    public var id: String { rawValue }

    /// Schlüssel wie in der TABS-Tabelle.
    public var titleKey: String {
        switch self {
        case .generator:     return "tabs.generator"
        case .aiCoach:       return "tabs.ai"
        case .plans:         return "tabs.plans"
        case .progress:      return "tabs.progress"
        }
    }

    /// Symbol für die Leiste.
    public var icon: String {
        switch self {
        case .generator:     return "flame.fill"
        case .aiCoach:       return "sparkles"
        case .plans:         return "calendar"
        case .progress:      return "chart.line.uptrend.xyaxis"
        }
    }
}

public struct LogoIcon: View {
    public let size: CGFloat
    public init(size: CGFloat = 30) { self.size = size }

    public var body: some View {
        Canvas { ctx, canvasSize in
            let s = min(canvasSize.width, canvasSize.height) / 48
            func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ radius: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s),
                     cornerRadius: radius * s)
            }
            func circle(_ cx: CGFloat, _ cy: CGFloat, _ rad: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: (cx - rad) * s, y: (cy - rad) * s,
                                       width: rad * 2 * s, height: rad * 2 * s))
            }
            /// Körper: im SVG ein Pfad, hier als abgerundetes Rechteck nachgebildet.
            func body(_ cx: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: (cx - 5.7) * s, y: 18.4 * s,
                                         width: 11.4 * s, height: 12.6 * s),
                     cornerRadius: 4.2 * s)
            }

            let fg = GraphicsContext.Shading.color(Theme.bg)

            // Würfel-Silhouette im Hintergrund (um 45° gedreht)
            ctx.drawLayer { layer in
                layer.translateBy(x: 24 * s, y: 24 * s)
                layer.rotate(by: .degrees(45))
                layer.translateBy(x: -24 * s, y: -24 * s)
                layer.fill(r(15, 15, 18, 18, 3), with: .color(Theme.bg.opacity(0.22)))
            }

            for cx in [CGFloat(16), CGFloat(32)] {
                ctx.fill(circle(cx, 14, 3.6), with: fg)
                ctx.fill(body(cx), with: fg)
            }
            // Hanteln links und rechts
            ctx.fill(r(3.5, 19, 7.5, 2.4, 1.2), with: fg)
            ctx.fill(r(2, 17.4, 2.8, 5.6, 1), with: fg)
            ctx.fill(r(9.2, 17.4, 2.8, 5.6, 1), with: fg)
            ctx.fill(r(37, 19, 7.5, 2.4, 1.2), with: fg)
            ctx.fill(r(35.8, 17.4, 2.8, 5.6, 1), with: fg)
            ctx.fill(r(43, 17.4, 2.8, 5.6, 1), with: fg)
        }
        .frame(width: size, height: size)
    }
}

public struct KraftHeaderView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var auth = AuthService.shared
    @ObservedObject private var storeKit = StoreKitManager.shared

    public var onOpenSettings: (() -> Void)?
    public var onOpenPro: (() -> Void)?

    /*
      Welcher der Begrüßungssätze gerade läuft. Einmal pro App-Start
      neu gewürfelt — @State wird nur beim ersten Erscheinen ausgewertet,
      ein Tabwechsel oder Re-Render würfelt nicht erneut.
    */
    @State private var sentenceVariant = Int.random(in: 1...25)

    public init(
        onOpenSettings: (() -> Void)? = nil,
        onOpenPro: (() -> Void)? = nil
    ) {
        self.onOpenSettings = onOpenSettings
        self.onOpenPro = onOpenPro
    }

    private var currentUserName: String {
        let name = auth.displayName
        return name.isEmpty ? i18n.t("greeting.guestName") : name
    }

    private var greetingSentence: String {
        i18n.t("greeting.sentence.\(sentenceVariant)", ["name": currentUserName])
    }

    public var body: some View {
        VStack(spacing: 12) {
            brandRow
                .padding(.horizontal, 20)

            aiGreetingCard
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
        }
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Theme.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    // MARK: - Marke

    private var brandRow: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Theme.accent)
                LogoIcon(size: 26)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("KRAFTWÜRFEL").kwStyle(.brandTitle)
                Text(i18n.t("app.subtitle")).kwStyle(.brandSub)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if !storeKit.isProUnlocked { proButton }
                settingsButton
            }
        }
    }

    private var proButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onOpenPro?()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 12, weight: .bold))
                Text(i18n.t("nav.getPro")).font(KraftFont.bebas(13)).tracking(1)
            }
            .foregroundColor(Theme.bg)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 9).fill(Theme.accent))
        }
        .buttonStyle(.plain)
    }

    private var settingsButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onOpenSettings?()
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.text)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(i18n.t("settings.title"))
    }

    // MARK: - KI-Coach Begrüßung für den Nutzer

    private var aiGreetingCard: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.accentDim)
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.accent)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(i18n.t("greeting.title", ["name": currentUserName]))
                    .font(KraftFont.inter(13.5, .bold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)

                Text(greetingSentence)
                    .font(KraftFont.inter(12, .medium))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [Theme.accent.opacity(0.4), Theme.border],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}
