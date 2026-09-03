import SwiftUI

/*
  Die gemeinsame Karte für „Gespeichert“ und „Favoriten“.

  Im Web ist beides dieselbe CSS-Klasse (.saved-card) — nativ waren es zwei
  handgeschriebene Karten mit unterschiedlichem Radius, unterschiedlichen
  Abständen und unterschiedlichen Knöpfen. Wer eine anfasste, vergaß die
  andere. Ab jetzt gibt es nur diese eine.
*/

/// Kleines Etikett neben dem Titel — Rufname, „heute“, Zyklenzahl.
public struct PlanCardBadge: Identifiable {
    public let id = UUID()
    let text: String
    let filled: Bool

    public init(_ text: String, filled: Bool = false) {
        self.text = text
        self.filled = filled
    }
}

/// Ein Knopf in der Aktionszeile (.saved-actions).
public struct PlanCardAction: Identifiable {
    public enum Style { case primary, destructive, plain }

    public let id = UUID()
    let label: String
    let systemImage: String
    let style: Style
    let action: () -> Void

    public init(_ label: String, systemImage: String, style: Style = .plain, action: @escaping () -> Void) {
        self.label = label
        self.systemImage = systemImage
        self.style = style
        self.action = action
    }
}

public struct PlanListCard<Content: View>: View {
    private let title: String
    private let badges: [PlanCardBadge]
    private let meta: String
    private let isOpen: Bool
    private let isHighlighted: Bool
    private let onToggle: () -> Void
    private let actions: [PlanCardAction]
    private let content: Content

    public init(
        title: String,
        badges: [PlanCardBadge] = [],
        meta: String,
        isOpen: Bool,
        isHighlighted: Bool = false,
        onToggle: @escaping () -> Void,
        actions: [PlanCardAction] = [],
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.badges = badges
        self.meta = meta
        self.isOpen = isOpen
        self.isHighlighted = isHighlighted
        self.onToggle = onToggle
        self.actions = actions
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onToggle()
            }) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        // .saved-name mit den Etiketten daneben
                        FlowLayout(spacing: 6, lineSpacing: 4) {
                            Text(title).kwStyle(.savedName)
                            ForEach(badges) { badge in
                                Text(badge.text)
                                    .font(badge.filled ? KraftFont.mono(9.5, .bold) : KraftFont.bebas(13))
                                    .tracking(badge.filled ? 0.8 : 1)
                                    .foregroundColor(badge.filled ? Theme.bg : Theme.accent)
                                    .padding(.horizontal, badge.filled ? 5 : 7)
                                    .padding(.vertical, 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(badge.filled ? Theme.accent : Theme.accentDim)
                                    )
                            }
                        }
                        Text(meta).kwStyle(.savedMeta)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.muted)
                        .padding(.top, 2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                content.padding(.top, 10)
            }

            if !actions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(actions) { action in
                        actionButton(action)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighlighted ? Theme.accent : Theme.border, lineWidth: 1)
        )
    }

    private func actionButton(_ action: PlanCardAction) -> some View {
        let tint: Color = switch action.style {
        case .primary:     Theme.accent
        case .destructive: Theme.red
        case .plain:       Theme.text
        }

        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action.action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: action.systemImage).font(.system(size: 11, weight: .bold))
                Text(action.label).font(KraftFont.inter(12.5, .semibold))
            }
            .foregroundColor(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface2))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(action.style == .plain ? Theme.border : tint, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/*
  Die Übungszeilen innerhalb einer aufgeklappten Karte. Gleiche Darstellung
  wie .tp-row im Trainingsplan, damit eine Übung überall gleich aussieht.
*/
public struct PlanSlotRows: View {
    @ObservedObject private var i18n = I18n.shared
    private let slots: [ExerciseSlot]

    public init(slots: [ExerciseSlot]) { self.slots = slots }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(slots.enumerated()), id: \.element.id) { idx, slot in
                HStack(spacing: 10) {
                    ExerciseVisual(exercise: slot.exercise, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(i18n.exerciseName(slot.exercise)).kwStyle(.rowName).lineLimit(1)
                        Text(i18n.category(slot.exercise.category)).kwStyle(.rowCat)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        Text("\(slot.sets)×\(slot.reps)").kwStyle(.rowSets)
                        EquipmentTag(i18n.equipment(slot.exercise.equipment))
                    }
                }
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) {
                    if idx < slots.count - 1 {
                        Rectangle().fill(Theme.border).frame(height: 1)
                    }
                }
            }
        }
    }
}
