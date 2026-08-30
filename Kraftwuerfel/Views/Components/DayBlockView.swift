import SwiftUI

/*
  Portierung von src/components/DayBlock.jsx (.tp-day-block).

  Ein Wochentag als aufklappbare Karte: Kopfzeile mit Kürzel, Rufname und
  Anzahl der Pläne, rechts daneben Start und Herz. Aufgeklappt kommen die
  Zyklen und darunter noch einmal Favorit und Start als breite Knöpfe.
*/
public struct DayBlockView: View {
    @ObservedObject private var i18n = I18n.shared

    /// Welcher Zyklus gerade gezeigt wird. Startet beim laufenden.
    @State private var selectedCycle: Int = 0

    private let day: String
    private let cyclePlans: [[ExerciseSlot]]
    private let currentCycleIdx: Int?
    private let isOpen: Bool
    private let isFavorited: Bool
    private let canFavorite: Bool
    private let planSalt: String
    private let onToggle: () -> Void
    private let onFavorite: () -> Void
    private let onStart: (([ExerciseSlot], String) -> Void)?
    private let onMoveUp: (() -> Void)?
    private let onMoveDown: (() -> Void)?
    /*
      Nur der LAUFENDE Plan lässt sich ändern. Gespeicherte und favorisierte
      Tagespläne zeigen dieselbe Karte, sind aber Momentaufnahmen — dort
      bleiben beide Rückrufe `nil` und die Knöpfe verschwinden, statt eine
      Änderung anzubieten, die nirgends ankäme.
    */
    private let onEdit: (() -> Void)?
    private let onShuffle: (() -> Void)?

    public init(
        day: String,
        cyclePlans: [[ExerciseSlot]],
        currentCycleIdx: Int? = nil,
        isOpen: Bool,
        isFavorited: Bool,
        canFavorite: Bool,
        planSalt: String = "",
        onToggle: @escaping () -> Void,
        onFavorite: @escaping () -> Void,
        onStart: (([ExerciseSlot], String) -> Void)? = nil,
        onMoveUp: (() -> Void)? = nil,
        onMoveDown: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onShuffle: (() -> Void)? = nil
    ) {
        self.day = day
        self.cyclePlans = cyclePlans
        self.currentCycleIdx = currentCycleIdx
        self.isOpen = isOpen
        self.isFavorited = isFavorited
        self.canFavorite = canFavorite
        self.planSalt = planSalt
        self.onToggle = onToggle
        self.onFavorite = onFavorite
        self.onStart = onStart
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onEdit = onEdit
        self.onShuffle = onShuffle
    }

    /// Gewürfelte Pläne haben kein Modell, das sie benennt — der Name kommt lokal.
    private var planName: String { PlanNames.planName(for: "\(planSalt):\(day)") }

    /// Beim Start zählt der Zyklus, den man gerade ansieht; zugeklappt der laufende.
    private var targetCycle: [ExerciseSlot] {
        if isOpen, cyclePlans.indices.contains(selectedCycle) { return cyclePlans[selectedCycle] }
        if let idx = currentCycleIdx, cyclePlans.indices.contains(idx) { return cyclePlans[idx] }
        return cyclePlans.first ?? []
    }

    private var startTitle: String { "\(planName) · \(i18n.weekday(day))" }

    public var body: some View {
        VStack(spacing: 0) {
            headerRow
            if isOpen { expandedBody }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onLongPressGesture(minimumDuration: 0.4) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            if let onMoveDown {
                onMoveDown()
            } else if let onMoveUp {
                onMoveUp()
            }
        }
        .onAppear { selectedCycle = currentCycleIdx ?? 0 }
        .onChange(of: currentCycleIdx) { newValue in selectedCycle = newValue ?? 0 }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Text(i18n.weekday(day)).kwStyle(.dayToggle)

                    Text(planName)
                        .font(KraftFont.bebas(13)).tracking(1)
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Theme.accentDim))

                    Text(i18n.t(cyclePlans.count == 1 ? "tp.planCount" : "tp.plansCount",
                                ["n": "\(cyclePlans.count)"]))
                        .font(KraftFont.inter(11.5))
                        .foregroundColor(Theme.muted)

                    Spacer(minLength: 0)

                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.muted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if onMoveUp != nil || onMoveDown != nil {
                HStack(spacing: 0) {
                    if let onMoveUp {
                        sideButton("chevron.up", tint: Theme.muted, action: onMoveUp)
                    }
                    if let onMoveDown {
                        sideButton("chevron.down", tint: Theme.muted, action: onMoveDown)
                    }
                }
            }

            if onStart != nil && !cyclePlans.isEmpty {
                sideButton("play.fill", tint: Theme.accent) {
                    onStart?(targetCycle, startTitle)
                }
            }
            if canFavorite {
                sideButton(isFavorited ? "heart.fill" : "heart",
                           tint: isFavorited ? Theme.pink : Theme.muted,
                           action: onFavorite)
            }
        }
    }

    private func editChip(
        _ symbol: String,
        _ label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                Text(label).font(KraftFont.inter(12, .semibold))
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface2))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func sideButton(_ symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(tint)
                .frame(width: 44)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Theme.border).frame(width: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /*
      Bei mehreren Zyklen liegen die Pläne auf Reitern statt untereinander.
      Bei einem Zyklus wäre ein Reiter sinnlos — dann bleibt es beim Block.
    */
    private var cycleTabs: some View {
        HStack(spacing: 0) {
            ForEach(cyclePlans.indices, id: \.self) { idx in
                let isActive = selectedCycle == idx
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeOut(duration: 0.15)) { selectedCycle = idx }
                }) {
                    HStack(spacing: 5) {
                        Text(i18n.t("tp.cycleLabel", ["n": "\(idx + 1)"]))
                            .font(KraftFont.bebas(13)).tracking(0.5)
                        // Der laufende Zyklus bleibt auch dann erkennbar,
                        // wenn man sich gerade einen anderen ansieht.
                        if currentCycleIdx == idx {
                            Circle()
                                .fill(isActive ? Theme.bg : Theme.accent)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .foregroundColor(isActive ? Theme.bg : Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 8).fill(isActive ? Theme.accent : Color.clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 11).fill(Theme.surface2))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.border, lineWidth: 1))
    }

    private var expandedBody: some View {
        VStack(spacing: 10) {
            if cyclePlans.count > 1 { cycleTabs }

            if cyclePlans.indices.contains(selectedCycle) {
                let slots = cyclePlans[selectedCycle]
                CycleBlockView(
                    label: cyclePlans.count > 1
                        ? nil
                        : i18n.t("tp.cycleLabel", ["n": "\(selectedCycle + 1)"]),
                    slots: slots,
                    isCurrent: currentCycleIdx == selectedCycle,
                    onStart: onStart == nil ? nil : {
                        onStart?(slots, "\(startTitle) · \(i18n.t("tp.cycleLabel", ["n": "\(selectedCycle + 1)"]))")
                    }
                )
            }

            if onEdit != nil || onShuffle != nil {
                HStack(spacing: 8) {
                    if let onShuffle {
                        editChip("shuffle", i18n.t("dayEdit.shuffleDay"), tint: Theme.accent) {
                            withAnimation(.easeOut(duration: 0.2)) { onShuffle() }
                        }
                    }
                    if let onEdit {
                        editChip("slider.horizontal.3", i18n.t("dayEdit.edit"), tint: Theme.muted, action: onEdit)
                    }
                }
            }

            // .tp-day-actions-row
            HStack(spacing: 8) {
                if canFavorite {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onFavorite()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isFavorited ? "heart.fill" : "heart")
                                .font(.system(size: 12, weight: .bold))
                            Text(isFavorited ? "Favorisiert" : i18n.t("tp.favorite"))
                                .font(KraftFont.inter(12.5, .semibold))
                        }
                        .foregroundColor(isFavorited ? Theme.pink : Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isFavorited ? Theme.pink.opacity(0.1) : Theme.surface2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isFavorited ? Theme.pink.opacity(0.4) : Theme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if onStart != nil && !cyclePlans.isEmpty {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onStart?(targetCycle, startTitle)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill").font(.system(size: 12))
                            Text(i18n.t("live.startTraining"))
                                .font(KraftFont.bebas(13)).tracking(1)
                        }
                        .foregroundColor(Theme.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 10)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }
}
