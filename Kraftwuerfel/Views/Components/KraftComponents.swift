import SwiftUI

/*
  Die Bausteine aus styles/app.css als wiederverwendbare Views. Maße und Farben
  stehen bewusst als Zahlen da, wo die CSS-Regel auch eine Zahl hat — so lässt
  sich beides nebeneinanderlegen und vergleichen.
*/

// MARK: - Umbrechende Chip-Reihe (.chip-row / flex-wrap)

/// SwiftUI hat kein `flex-wrap`. Diese Layout-Implementierung bricht wie das
/// Web um, statt die Chips wie bisher horizontal wegzuscrollen — im Web sieht
/// man alle Splits auf einmal, und genau das war der Unterschied.
public struct FlowLayout: Layout {
    public var spacing: CGFloat
    public var lineSpacing: CGFloat

    public init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                widest = max(widest, x - spacing)
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        widest = max(widest, x - spacing)
        return CGSize(width: min(widest, maxWidth), height: y + lineHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Abschnittsüberschrift (.section-label)

public struct SectionLabel: View {
    private let text: String
    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .kwStyle(.sectionLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Chip (.chip / .chip.active)

public struct KraftChip: View {
    private let label: String
    private let isActive: Bool
    private let action: () -> Void

    public init(_ label: String, isActive: Bool, action: @escaping () -> Void) {
        self.label = label
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Text(label)
                .font(KraftFont.inter(13, .semibold))
                .foregroundColor(isActive ? Theme.bg : Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isActive ? Theme.accent : Theme.surface)
                )
                .overlay(
                    Capsule().stroke(isActive ? Theme.accent : Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Großer Stepper (.stepper)

public struct KraftStepper: View {
    @Binding public var value: Int
    public let range: ClosedRange<Int>

    public init(value: Binding<Int>, range: ClosedRange<Int>) {
        self._value = value
        self.range = range
    }

    public var body: some View {
        HStack(spacing: 16) {
            stepButton("minus", enabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - 1)
            }
            Text("\(value)")
                .kwStyle(.stepperCount)
                .frame(minWidth: 24)
            stepButton("plus", enabled: value < range.upperBound) {
                value = min(range.upperBound, value + 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    private func stepButton(_ symbol: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: {
            guard enabled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(enabled ? Theme.text : Theme.muted.opacity(0.4))
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface2))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Kleiner Stepper in der Plan-Karte (.mini-stepper)

public struct MiniStepper: View {
    @Binding public var value: Int
    public let range: ClosedRange<Int>

    public init(value: Binding<Int>, range: ClosedRange<Int>) {
        self._value = value
        self.range = range
    }

    public var body: some View {
        HStack(spacing: 6) {
            btn("minus") { value = max(range.lowerBound, value - 1) }
            Text("\(value)")
                .kwStyle(.miniStepper)
                .frame(minWidth: 16)
            btn("plus") { value = min(range.upperBound, value + 1) }
        }
    }

    private func btn(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.text)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surface2))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pausen-Chip in der Plan-Karte (.rest-chip)

public struct RestChip: View {
    private let seconds: Int
    private let isActive: Bool
    private let action: () -> Void

    public init(seconds: Int, isActive: Bool, action: @escaping () -> Void) {
        self.seconds = seconds
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text("\(seconds)s")
                .font(KraftFont.mono(11, .bold))
                .foregroundColor(isActive ? Theme.bg : Theme.muted)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 7).fill(isActive ? Theme.accent : Theme.surface2))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(isActive ? Theme.accent : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Equipment-Tag (.db-equ)

public struct EquipmentTag: View {
    private let text: String
    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .kwStyle(.dbEqu)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
    }
}

// MARK: - Hauptbutton (.roll-btn / .kw-btn)

public struct KraftPrimaryButton: View {
    private let title: String
    private let systemImage: String?
    private let isEnabled: Bool
    private let compact: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        systemImage: String? = nil,
        isEnabled: Bool = true,
        compact: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.compact = compact
        self.action = action
    }

    public var body: some View {
        Button(action: {
            guard isEnabled else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: compact ? 15 : 18, weight: .bold))
                }
                Text(title)
                    .font(KraftFont.bebas(compact ? 15 : 20))
                    .tracking(compact ? 1.5 : 2)
            }
            .foregroundColor(Theme.bg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 11 : 16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent))
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/*
  Der Knopf in den Farben der Würfel-Arena: Mint nach Orange.

  Die Home-Challenge benutzt ihn durchgehend — Weiter, Zurück-Rahmen und
  „Challenge erstellen" tragen dieselbe Farbe wie „3D Würfel werfen" darunter.
  Vorher war der Wurf-Knopf der einzige mit Verlauf, und der Fragebogen davor
  sah aus, als gehörte er zu einem anderen Bildschirm.
*/
public struct KraftGradientButton: View {
    private let title: String
    private let systemImage: String?
    private let isEnabled: Bool
    private let compact: Bool
    private let action: () -> Void

    public static let gradient = LinearGradient(
        colors: [Theme.accent, Theme.orange],
        startPoint: .leading,
        endPoint: .trailing
    )

    public init(
        _ title: String,
        systemImage: String? = nil,
        isEnabled: Bool = true,
        compact: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.compact = compact
        self.action = action
    }

    public var body: some View {
        Button(action: {
            guard isEnabled else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: compact ? 14 : 16, weight: .bold))
                }
                Text(title)
                    .font(KraftFont.bebas(compact ? 15 : 18))
                    .tracking(compact ? 1.2 : 1.5)
            }
            .foregroundColor(Theme.bg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 11 : 14)
            .background(Self.gradient)
            .cornerRadius(14)
            .shadow(color: Theme.accent.opacity(isEnabled ? 0.35 : 0), radius: 10, y: 4)
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// Die zurückhaltende Fassung desselben Knopfes: Verlauf nur als Rahmen.
public struct KraftGradientOutlineButton: View {
    private let title: String
    private let systemImage: String?
    private let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 12, weight: .bold))
                }
                Text(title).font(KraftFont.bebas(15)).tracking(1.2)
            }
            .foregroundColor(Theme.accent)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accentDim))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(KraftGradientButton.gradient, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Gestrichelter Sekundärbutton (.remix-btn)

public struct KraftDashedButton: View {
    private let title: String
    private let systemImage: String
    private let action: () -> Void

    public init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage).font(.system(size: 12, weight: .semibold))
                Text(title).font(KraftFont.inter(13, .semibold))
            }
            .foregroundColor(Theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundColor(Theme.border)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Leerzustand (.empty)

public struct EmptyStateBox: View {
    private let title: String
    private let hint: String?

    public init(_ title: String, hint: String? = nil) {
        self.title = title
        self.hint = hint
    }

    public var body: some View {
        VStack(spacing: 4) {
            Text(title)
            if let hint { Text(hint) }
        }
        .font(KraftFont.inter(14))
        .foregroundColor(Theme.muted)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 10)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundColor(Theme.border)
        )
    }
}

// MARK: - Bausteine des KI-Assistenten (AiCoachTab.jsx)

/// `.ai-intro` — der erklärende Kasten über den Auswahlfeldern.
public struct AiIntroBox: View {
    private let text: String
    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .font(KraftFont.inter(13))
            .foregroundColor(Theme.muted)
            .lineSpacing(4)                       // line-height:1.6
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
    }
}

/*
  `.chip-grid` mit 9px Abstand. Die Spaltenzahl richtet sich nach der Anzahl der
  Optionen: gerade Anzahl -> zwei Spalten (2x2, 2x3 …), ungerade -> drei. So
  steht nie eine einzelne Karte allein in der letzten Zeile.
*/
public struct ChipGrid<Content: View>: View {
    private let columns: Int
    private let content: Content

    public init(count: Int, @ViewBuilder content: () -> Content) {
        self.columns = count % 2 == 0 ? 2 : 3
        self.content = content()
    }

    /// Feste Spaltenzahl, wenn die Regel nicht passt.
    public init(columns: Int, @ViewBuilder content: () -> Content) {
        self.columns = max(1, columns)
        self.content = content()
    }

    public var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: columns),
            alignment: .leading,
            spacing: 9
        ) {
            content
        }
    }
}

/*
  Stepper mit direkt beschreibbarem Feld. Bisher ging nur Plus/Minus — bei
  Gewicht oder Größe tippt man den Wert lieber ein, als vierzig Mal zu drücken.
  Die Beschriftung sitzt darüber, damit drei davon nebeneinander passen.
*/
public struct EditableStepper: View {
    private let label: String
    private let unit: String
    @Binding private var value: Int
    private let range: ClosedRange<Int>

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    public init(_ label: String, unit: String = "", value: Binding<Int>, range: ClosedRange<Int>) {
        self.label = label
        self.unit = unit
        self._value = value
        self.range = range
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).kwStyle(.controlLabel)

            HStack(spacing: 4) {
                btn("minus") { commit(value - 1) }

                TextField("", text: $text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(KraftFont.mono(15, .bold))
                    .foregroundColor(Theme.text)
                    .focused($isFocused)
                    .frame(maxWidth: .infinity)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button(I18n.shared.lang == "en" ? "Done" : "Fertig") {
                                isFocused = false
                            }
                            .font(KraftFont.inter(14, .semibold))
                            .foregroundColor(Theme.accent)
                        }
                    }
                    .onChange(of: isFocused) { focused in
                        // Erst beim Verlassen übernehmen, sonst springt die Zahl
                        // schon beim Tippen der ersten Ziffer in den Bereich.
                        if !focused { commit(Int(text) ?? value) }
                    }

                if !unit.isEmpty {
                    Text(unit)
                        .font(KraftFont.mono(11, .medium))
                        .foregroundColor(Theme.muted)
                }

                btn("plus") { commit(value + 1) }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isFocused ? Theme.accent : Theme.border, lineWidth: 1))
        }
        .onAppear { text = "\(value)" }
        .onChange(of: value) { newValue in
            if !isFocused { text = "\(newValue)" }
        }
    }

    private func commit(_ raw: Int) {
        let clamped = min(range.upperBound, max(range.lowerBound, raw))
        value = clamped
        text = "\(clamped)"
    }

    private func btn(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.text)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface2))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// `.wizard-card-chip` — Karte statt Pille, linksbündig, aktiv mit Schein.
public struct WizardCardChip: View {
    private let label: String
    private let subtitle: String?
    private let isActive: Bool
    private let action: () -> Void

    public init(_ label: String, subtitle: String? = nil, isActive: Bool, action: @escaping () -> Void) {
        self.label = label
        self.subtitle = subtitle
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(KraftFont.inter(13.5, .semibold))
                    .foregroundColor(isActive ? Theme.accent : Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)
                    .truncationMode(.tail)
                if let subtitle {
                    Text(subtitle)
                        .font(KraftFont.inter(11))
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .allowsTightening(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(isActive ? Theme.accentDim : Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isActive ? Theme.accent : Theme.border, lineWidth: 1))
            .shadow(color: isActive ? Theme.accent.opacity(0.15) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dialog im App-Stil

/*
  Ein Hinweisfenster in den Farben der App.

  `.alert(...)` von SwiftUI zeichnet das System-Fenster: helles Grau, Apples
  Schrift, blauer Knopf. Neben dieser Oberfläche — Schwarz, Mint, Bebas —
  sieht das aus wie ein Fremdkörper aus einer anderen App. Aussehen lässt es
  sich nicht ändern, also übernimmt diese Ansicht die Rolle.

  Sie liegt als Overlay über dem Inhalt, nicht als Sheet: ein Sheet würde von
  unten hereinfahren und sich wie ein Seitenwechsel anfühlen, während hier nur
  etwas bestätigt wird.
*/
public struct KraftDialog: View {
    private let title: String
    private let message: String
    private let isError: Bool
    private let icon: String?
    private let dismissLabel: String
    private let onDismiss: () -> Void
    /// Gesetzt macht aus dem Hinweis eine Rückfrage: links Abbrechen,
    /// rechts die eigentliche Handlung.
    private let confirmLabel: String?
    private let onConfirm: (() -> Void)?

    @State private var appeared = false

    public init(
        title: String,
        message: String,
        isError: Bool = false,
        icon: String? = nil,
        dismissLabel: String = "OK",
        confirmLabel: String? = nil,
        onConfirm: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.isError = isError
        self.icon = icon
        self.dismissLabel = dismissLabel
        self.confirmLabel = confirmLabel
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
    }

    private var tint: Color { isError ? Theme.red : Theme.accent }

    private var symbol: String {
        icon ?? (isError ? "exclamationmark.triangle.fill" : "checkmark")
    }

    private var isConfirm: Bool { onConfirm != nil }

    public var body: some View {
        ZStack {
            // Der Hintergrund schluckt Tippen, damit nichts darunter reagiert.
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(isError ? Theme.red.opacity(0.14) : Theme.accentDim)
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(tint)
                }
                .frame(width: 52, height: 52)

                VStack(spacing: 6) {
                    Text(title)
                        .font(KraftFont.bebas(20)).tracking(1)
                        .foregroundColor(Theme.text)
                        .multilineTextAlignment(.center)

                    if !message.isEmpty {
                        Text(message)
                            .font(KraftFont.inter(13))
                            .foregroundColor(Theme.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if isConfirm {
                    // Bei einer Rückfrage steht Abbrechen zuerst und trägt
                    // das ruhigere Gewicht — gefüllt ist nur die Handlung,
                    // die der Nutzer ausdrücklich gewählt hat.
                    HStack(spacing: 8) {
                        Button(action: close) {
                            Text(dismissLabel)
                                .font(KraftFont.inter(13.5, .semibold))
                                .foregroundColor(Theme.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Theme.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                        Button(action: confirm) {
                            Text(confirmLabel ?? "")
                                .font(KraftFont.bebas(16)).tracking(1.2)
                                .textCase(.uppercase)
                                .foregroundColor(Theme.bg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(RoundedRectangle(cornerRadius: 12).fill(tint))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                } else {
                    Button(action: close) {
                        Text(dismissLabel)
                            .font(KraftFont.bebas(16)).tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundColor(Theme.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 12).fill(tint))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            .padding(22)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [tint.opacity(0.55), Theme.border],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 24, y: 8)
            .padding(.horizontal, 32)
            .scaleEffect(appeared ? 1 : 0.92)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { appeared = true }
        }
    }

    private func close() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onDismiss()
    }

    private func confirm() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onConfirm?()
    }
}

extension View {
    /// Ersatz für `.alert(item:)` — gleiche Aufrufform, aber im App-Stil.
    public func kraftDialog<Item: Identifiable>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> KraftDialog
    ) -> some View {
        overlay {
            if let value = item.wrappedValue {
                content(value)
                    .transition(.opacity)
            }
        }
    }

    /// Dieselbe Optik für eine einfache Ja/Nein-Rückfrage.
    public func kraftDialog(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> KraftDialog
    ) -> some View {
        overlay {
            if isPresented.wrappedValue {
                content().transition(.opacity)
            }
        }
    }
}

/// `.review-row` — Beschriftung links, Wert rechts, Trennlinie darunter.
public struct ReviewRow: View {
    private let label: String
    private let value: String
    private let highlight: Bool
    private let isLast: Bool

    public init(_ label: String, _ value: String, highlight: Bool = false, isLast: Bool = false) {
        self.label = label
        self.value = value
        self.highlight = highlight
        self.isLast = isLast
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(label)
                .font(KraftFont.mono(11, .bold))
                .tracking(0.66)
                .textCase(.uppercase)
                .foregroundColor(Theme.muted)
            Spacer(minLength: 0)
            Text(value)
                .font(KraftFont.inter(13.5, highlight ? .bold : .semibold))
                .foregroundColor(highlight ? Theme.accent : Theme.text)
                .multilineTextAlignment(.trailing)
        }
        .padding(.bottom, isLast ? 0 : 10)
        .overlay(alignment: .bottom) {
            if !isLast { Rectangle().fill(Theme.surface2).frame(height: 1) }
        }
    }
}

// MARK: - Tastatur Schließen

public struct DismissKeyboardOnTap: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
    }
}

public extension View {
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTap())
    }

    func addDoneButtonToKeyboard(onDone: (() -> Void)? = nil) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(I18n.shared.lang == "en" ? "Done" : "Fertig") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    onDone?()
                }
                .font(KraftFont.inter(13.5, .semibold))
                .foregroundColor(Theme.accent)
            }
        }
    }
}
