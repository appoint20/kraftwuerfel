import SwiftUI

/*
  Portierung des Kopfbereichs aus src/App.jsx (.header, .brand, .tabs).

  Gegenüber der bisherigen Fassung sind drei Dinge neu, die das Web schon hatte:
  der fünfte Tab (Favoriten), der DE/EN-Schalter und das Würfel-Logo statt eines
  SF-Symbols. Außerdem läuft die Schrift jetzt über Bebas Neue — vorher hat die
  breitere Systemschrift die Tab-Beschriftungen umbrechen lassen
  ("TRAININGSP / LAN").
*/

public enum KraftTab: String, CaseIterable, Identifiable {
    case generator, aiCoach, trainingsplan, saved, favorites

    public var id: String { rawValue }

    /// Schlüssel wie in der TABS-Tabelle in App.jsx.
    public var titleKey: String {
        switch self {
        case .generator:     return "tabs.generator"
        case .aiCoach:       return "tabs.ai"
        case .trainingsplan: return "tabs.trainingsplan"
        case .saved:         return "tabs.saved"
        case .favorites:     return "tabs.favorites"
        }
    }

    /// Symbol für die Leiste. Ohne Bild bräuchte die Beschriftung mehr Platz,
    /// als eine einzige Zeile für fünf Bereiche hergibt.
    public var icon: String {
        switch self {
        case .generator:     return "dice.fill"
        case .aiCoach:       return "sparkles"
        case .trainingsplan: return "calendar"
        case .saved:         return "bookmark.fill"
        case .favorites:     return "heart.fill"
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

/*
  Kopfbereich: Markenzeile und darunter die Navigationsleiste.

  Vorher lagen die fünf Bereiche in einem umbrechenden Layout und standen
  dadurch in zwei Zeilen ("GENERATOR / KI-COACH / TRAININGSPLAN" und darunter
  "GESPEICHERT / FAVORITEN"). Jetzt ist es eine Zeile mit Symbol und
  Beschriftung je Bereich; der aktive bekommt Fläche, Farbe und einen Strich.

  Der DE/EN-Schalter saß hier oben rechts. Er ist in die Einstellungen gewandert
  — an seiner Stelle steht das Zahnrad.
*/
public struct KraftHeaderView: View {
    @Binding public var selectedTab: KraftTab
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var storeKit = StoreKitManager.shared

    public var onOpenSettings: (() -> Void)?

    public init(selectedTab: Binding<KraftTab>, onOpenSettings: (() -> Void)? = nil) {
        self._selectedTab = selectedTab
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        VStack(spacing: 0) {
            brandRow
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            taskBar
        }
        .padding(.top, 14)
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
        Button(action: {}) {
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

    // MARK: - Navigationsleiste

    /*
      Eine Zeile, fünf gleich breite Felder. `minimumScaleFactor` fängt die
      längeren deutschen Wörter ab, statt sie umbrechen zu lassen — ein Umbruch
      wäre wieder die zweite Zeile, die hier weg soll.
    */
    private var taskBar: some View {
        HStack(spacing: 0) {
            ForEach(KraftTab.allCases) { tab in
                taskBarItem(tab)
            }
        }
        .padding(.horizontal, 8)
    }

    private func taskBarItem(_ tab: KraftTab) -> some View {
        let isActive = selectedTab == tab
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tab }
        }) {
            VStack(spacing: 0) {
                VStack(spacing: 3) {
                    ZStack {
                        if isActive {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(Theme.accentDim)
                                .frame(height: 26)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12.5, weight: .semibold))
                            // Das Web markiert den KI-Tab für Nicht-Pro.
                            if tab == .aiCoach && !storeKit.isProUnlocked {
                                Circle().fill(Theme.accent).frame(width: 4, height: 4)
                            }
                        }
                        .foregroundColor(isActive ? Theme.accent : Theme.muted)
                    }
                    .frame(height: 26)

                    Text(i18n.t(tab.titleKey))
                        .font(KraftFont.bebas(11.5))
                        .tracking(0.3)
                        .foregroundColor(isActive ? Theme.accent : Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.bottom, 7)

                Rectangle()
                    .fill(isActive ? Theme.accent : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}

