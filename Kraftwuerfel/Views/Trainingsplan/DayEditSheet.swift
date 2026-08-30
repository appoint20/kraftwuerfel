import SwiftUI

/*
  Einen einzelnen Trainingstag anpassen.

  Bisher stand der laufende Plan ab dem Start fest. Wer eine Übung nicht
  machen konnte — Bank besetzt, Knie zwickt, Gerät defekt —, hatte genau eine
  Möglichkeit: den ganzen Plan beenden und neu würfeln. Der Fortschritt war
  damit weg, und der Preis für eine getauschte Übung war die ganze Woche.

  Hier geht beides: eine Übung einzeln tauschen, neu würfeln oder entfernen —
  und der ganze Tag auf einmal neu gemischt, ohne den Plan anzufassen.

  Warum ein eigenes Blatt und keine Knöpfe in der Tageskarte: Vier Aktionen
  pro Zeile passen in einer zugeklappten Karte nicht nebeneinander, ohne dass
  die Übungsnamen abgeschnitten werden. Und CycleBlockView zeigt auch
  gespeicherte und favorisierte Pläne, die gar nicht veränderbar sind.
*/
public struct DayEditSheet: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var active = ActivePlanStore.shared
    @Environment(\.dismiss) private var dismiss

    private let day: String
    private let cycle: Int
    private let method: TrainingMethod

    @State private var picker: PickerTarget?

    /// `nil` als Index heißt: hinzufügen statt tauschen.
    private struct PickerTarget: Identifiable {
        let index: Int?
        var id: String { index.map(String.init) ?? "add" }
    }

    public init(day: String, cycle: Int, method: TrainingMethod) {
        self.day = day
        self.cycle = cycle
        self.method = method
    }

    private var slots: [ExerciseSlot] { active.slots(day: day, cycle: cycle) }

    public var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                        row(index: index, slot: slot)
                    }

                    KraftDashedButton(i18n.t("dayEdit.add"), systemImage: "plus") {
                        picker = PickerTarget(index: nil)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }

            footer
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(item: $picker) { target in
            ExercisePickerSheet(
                title: target.index == nil ? i18n.t("dayEdit.add") : i18n.t("dayEdit.replace"),
                highlightCategories: target.index
                    .flatMap { slots.indices.contains($0) ? slots[$0].exercise.categories : nil } ?? [],
                alreadyUsed: Set(slots.map(\.exercise.name)),
                onPick: { exercise in
                    if let index = target.index {
                        active.replaceSlot(day: day, cycle: cycle, at: index, with: exercise)
                    } else {
                        active.addSlot(day: day, cycle: cycle, exercise: exercise)
                    }
                    picker = nil
                }
            )
        }
    }

    // MARK: - Kopf & Fuß

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(i18n.t("dayEdit.title"))
                    .font(KraftFont.bebas(22)).tracking(1.2)
                    .foregroundColor(Theme.text)
                Text("\(i18n.weekday(day)) · \(i18n.t("tp.cycleLabel", ["n": "\(cycle + 1)"]))")
                    .font(KraftFont.inter(12))
                    .foregroundColor(Theme.muted)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.muted)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(i18n.t("saved.close"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.border).frame(height: 1)
            KraftPrimaryButton(i18n.t("dayEdit.shuffleDay"), systemImage: "shuffle") {
                withAnimation(.easeOut(duration: 0.2)) {
                    active.reshuffleDay(day: day, cycle: cycle)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Theme.bg)
    }

    // MARK: - Eine Übung

    private func row(index: Int, slot: ExerciseSlot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(index + 1)")
                    .font(KraftFont.mono(11, .bold))
                    .foregroundColor(Theme.muted)
                    .frame(width: 18, alignment: .leading)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(slot.exercise.localizedName(language: i18n.lang))
                        .font(KraftFont.inter(14, .semibold))
                        .foregroundColor(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(slot.exercise.category.localized(i18n.lang)) · \(slot.exercise.equipment.localized(i18n.lang))")
                        .font(KraftFont.inter(11.5))
                        .foregroundColor(Theme.muted)
                }

                Spacer(minLength: 0)

                // Reihenfolge ändern — der Platz reicht nur für Pfeile.
                VStack(spacing: 3) {
                    iconButton("chevron.up", enabled: index > 0) {
                        active.moveSlot(day: day, cycle: cycle, from: index, to: index - 1)
                    }
                    iconButton("chevron.down", enabled: index < slots.count - 1) {
                        active.moveSlot(day: day, cycle: cycle, from: index, to: index + 1)
                    }
                }
            }

            HStack(spacing: 7) {
                actionChip("shuffle", i18n.t("dayEdit.reroll"), tint: Theme.accent) {
                    active.rerollSlot(day: day, cycle: cycle, at: index, method: method)
                }
                actionChip("arrow.left.arrow.right", i18n.t("dayEdit.replace"), tint: Theme.muted) {
                    picker = PickerTarget(index: index)
                }
                actionChip("trash", i18n.t("dayEdit.remove"), tint: Theme.red,
                           // Ein Trainingstag ohne eine einzige Übung wäre keiner.
                           enabled: slots.count > 1) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        active.removeSlot(day: day, cycle: cycle, at: index)
                    }
                }
            }

            setsRow(index: index, slot: slot)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    /// Sätze und Pause direkt hier, statt in einem weiteren Blatt darunter.
    private func setsRow(index: Int, slot: ExerciseSlot) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Text(i18n.t("gen.sets"))
                    .font(KraftFont.mono(10, .bold))
                    .foregroundColor(Theme.muted)
                MiniStepper(
                    value: Binding(
                        get: { slot.sets },
                        set: { active.updateSlot(day: day, cycle: cycle, at: index, sets: $0) }
                    ),
                    range: 1...6
                )
            }

            Spacer(minLength: 0)

            Text("\(slot.reps) · \(slot.restSeconds)s")
                .font(KraftFont.mono(11, .bold))
                .foregroundColor(Theme.muted)
        }
    }

    private func iconButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            guard enabled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(enabled ? Theme.muted : Theme.muted.opacity(0.3))
                .frame(width: 26, height: 20)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surface2))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func actionChip(
        _ symbol: String,
        _ label: String,
        tint: Color,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            guard enabled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 10, weight: .bold))
                Text(label).font(KraftFont.inter(11.5, .semibold))
            }
            .foregroundColor(enabled ? tint : tint.opacity(0.35))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface2))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
