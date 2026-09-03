import SwiftUI

/*
  Portierung von src/components/CycleBlock.jsx (.tp-cycle-block, .tp-row).
  Wird im Trainingsplan und in den Favoriten gebraucht, deshalb liegt es hier
  und nicht in einer der beiden Ansichten.
*/
public struct CycleBlockView: View {
    @ObservedObject private var i18n = I18n.shared

    private let label: String?
    private let slots: [ExerciseSlot]
    private let isCurrent: Bool
    private let onStart: (() -> Void)?

    public init(
        label: String? = nil,
        slots: [ExerciseSlot],
        isCurrent: Bool = false,
        onStart: (() -> Void)? = nil
    ) {
        self.label = label
        self.slots = slots
        self.isCurrent = isCurrent
        self.onStart = onStart
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let label {
                HStack(spacing: 8) {
                    Text(label)
                        .font(KraftFont.bebas(14))
                        .tracking(0.5)
                        .foregroundColor(isCurrent ? Theme.accent : Theme.muted)

                    if isCurrent {
                        Text(i18n.t("tp.current"))
                            .font(KraftFont.inter(9.5, .bold))
                            .tracking(0.5)
                            .textCase(.uppercase)
                            .foregroundColor(Theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Theme.accentDim))
                    }

                    Spacer(minLength: 0)

                    if let onStart {
                        Button(action: onStart) {
                            HStack(spacing: 5) {
                                Image(systemName: "play.fill").font(.system(size: 9))
                                Text(i18n.t("live.startTraining"))
                                    .font(KraftFont.bebas(12)).tracking(0.6)
                            }
                            .foregroundColor(Theme.accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 7).fill(Theme.accentDim))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.accent, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 6)
            }

            ForEach(Array(slots.enumerated()), id: \.element.id) { idx, slot in
                HStack(spacing: 10) {
                    ExerciseVisual(exercise: slot.exercise, size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(i18n.exerciseName(slot.exercise))
                            .kwStyle(.rowName)
                            .lineLimit(1)
                        Text(i18n.category(slot.exercise.category))
                            .kwStyle(.rowCat)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        Text("\(slot.sets)×\(slot.reps)").kwStyle(.rowSets)
                        EquipmentTag(i18n.equipment(slot.exercise.equipment))
                    }
                }
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) {
                    // .tp-row:last-child bekommt im Web keine Linie.
                    if idx < slots.count - 1 {
                        Rectangle().fill(Theme.border).frame(height: 1)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface2))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrent ? Theme.accent : Theme.border, lineWidth: 1)
        )
    }
}
