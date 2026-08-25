import SwiftUI

/*
  Ein fertiger KI-Plan — anzeigen, anpassen, speichern.

  Diese Ansicht lag als 180-Zeilen-Block mitten in AICoachWizardView. Sie wird
  an zwei Stellen gebraucht — im Assistenten direkt nach dem Erzeugen und unter
  GESPEICHERT → KI-PLÄNE — und liegt deshalb für sich.

  Drei Dinge, die den Aufbau bestimmen:

  - Der Plan kommt als `@Binding`. Sätze und Wiederholungen lassen sich direkt
    hier ändern, ohne den Plan neu zu erzeugen; geschrieben wird über
    `TrainingPlan.updateSlot`, das genau einen Slot in genau einem Zyklus
    trifft.
  - Die Tage sind zugeklappt. Ein Plan über sechs Tage mit je acht Übungen ist
    sonst eine endlose Liste. Offen bleibt, was der Nutzer aufmacht.
  - Übungsnamen und Equipment gehen durch I18n. Vorher stand hier
    `slot.exercise.name` — also immer Deutsch, auch wenn die Oberfläche auf
    Englisch lief.
*/
public struct AIPlanView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var store = SavedAIPlansStore.shared

    @Binding public var plan: TrainingPlan
    @Binding public var viewingCycle: Int
    /// Nur im Assistenten bekannt — wird mitgespeichert, damit der Plan später
    /// noch die Sprache wechseln kann.
    public var input: AICoachInput?

    public var onStartLiveWorkout: (([ExerciseSlot], String) -> Void)?
    /// Im Assistenten sichtbar, in der gespeicherten Ansicht nicht.
    public var showsSaveButton: Bool
    /// „Neuen Plan konfigurieren“ — nur im Assistenten.
    public var onReset: (() -> Void)?

    @State private var alert: SaveAlert?
    /// Welche Tage offen sind. Beim Start genau der erste.
    @State private var expandedDays: Set<UUID> = []
    @State private var didSetInitialExpansion = false

    public init(
        plan: Binding<TrainingPlan>,
        viewingCycle: Binding<Int>,
        input: AICoachInput? = nil,
        onStartLiveWorkout: (([ExerciseSlot], String) -> Void)? = nil,
        showsSaveButton: Bool = true,
        onReset: (() -> Void)? = nil
    ) {
        self._plan = plan
        self._viewingCycle = viewingCycle
        self.input = input
        self.onStartLiveWorkout = onStartLiveWorkout
        self.showsSaveButton = showsSaveButton
        self.onReset = onReset
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                titleCard
                cycleSelector
                ForEach(plan.days) { day in
                    dayCard(day)
                }
                if showsSaveButton { saveButton.padding(.top, 4) }
                if let onReset { resetButton(onReset) }
            }
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .background(Theme.bg.ignoresSafeArea())
        .alert(item: $alert) { $0.alert }
        .onAppear {
            guard !didSetInitialExpansion else { return }
            didSetInitialExpansion = true
            if let first = plan.days.first { expandedDays = [first.id] }
        }
    }

    // MARK: - Kopf

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(plan.title)
                .font(KraftFont.bebas(21)).tracking(1)
                .foregroundColor(Theme.text)
            Text(plan.summary)
                .font(KraftFont.inter(13))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private var cycleSelector: some View {
        HStack {
            cycleButton(1)
            cycleButton(2)
        }
        .padding(4)
        .background(Theme.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private func cycleButton(_ cycle: Int) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeOut(duration: 0.15)) { viewingCycle = cycle }
        }) {
            HStack(spacing: 6) {
                Text(i18n.t("tp.cycleLabel", ["n": "\(cycle)"]))
                    .font(KraftFont.bebas(14)).tracking(0.5)
                if cycle == 1 {
                    Text(i18n.t("ai.cycleActive"))
                        .font(KraftFont.inter(9.5, .bold)).tracking(0.5)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Theme.accent)
                        .foregroundColor(Theme.bg)
                        .cornerRadius(4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(viewingCycle == cycle ? Theme.surface2 : Color.clear)
            .foregroundColor(Theme.text)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tage

    private func isExpanded(_ day: DayPlan) -> Bool { expandedDays.contains(day.id) }

    private func toggle(_ day: DayPlan) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.18)) {
            if expandedDays.contains(day.id) {
                expandedDays.remove(day.id)
            } else {
                expandedDays.insert(day.id)
            }
        }
    }

    private func dayCard(_ day: DayPlan) -> some View {
        let slots = day.slots(forCycle: viewingCycle)
        let cycleLabel = i18n.t("tp.cycleLabel", ["n": "\(viewingCycle)"])
        let open = isExpanded(day)

        return VStack(alignment: .leading, spacing: 0) {
            // Kopfzeile: immer sichtbar, klappt auf und zu.
            Button(action: { toggle(day) }) {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.muted)
                        .rotationEffect(.degrees(open ? 90 : 0))

                    Text(i18n.weekday(day.weekday))
                        .font(KraftFont.bebas(17)).tracking(1)
                        .foregroundColor(Theme.accent)
                        .frame(width: 34, height: 34)
                        .background(Theme.accentDim)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(day.name)
                                .font(KraftFont.bebas(18)).tracking(0.5)
                                .foregroundColor(Theme.text)
                            Text(cycleLabel)
                                .font(KraftFont.bebas(14)).tracking(0.5)
                                .foregroundColor(Theme.accent)
                        }
                        Text(day.focus)
                            .font(KraftFont.inter(11.5))
                            .foregroundColor(Theme.muted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    // Zugeklappt sieht man wenigstens den Umfang.
                    Text(i18n.t("saved.exercises", ["n": "\(slots.count)"]))
                        .font(KraftFont.mono(10.5, .medium))
                        .foregroundColor(Theme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                VStack(alignment: .leading, spacing: 10) {
                    if let onStartLiveWorkout, !slots.isEmpty {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onStartLiveWorkout(
                                slots,
                                "\(day.name) · \(i18n.weekday(day.weekday)) (\(cycleLabel))"
                            )
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill").font(.system(size: 11, weight: .bold))
                                Text(i18n.t("live.startTraining"))
                                    .font(KraftFont.bebas(14)).tracking(0.8)
                                    .textCase(.uppercase)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Theme.accent)
                            .foregroundColor(Theme.bg)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }

                    if !day.warmup.isEmpty { warmupBlock(day) }

                    ForEach(slots) { slot in
                        slotRow(day: day, slot: slot)
                    }
                }
                .padding(.top, 12)
                .transition(.opacity)
            }
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(open ? Theme.accent.opacity(0.45) : Theme.border, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private func warmupBlock(_ day: DayPlan) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(i18n.t("ai.warmupSection"))
                .font(KraftFont.inter(10, .bold)).tracking(1)
                .textCase(.uppercase)
                .foregroundColor(Theme.muted)
            ForEach(day.warmup) { item in
                HStack {
                    Text(item.name)
                        .font(KraftFont.inter(12))
                        .foregroundColor(Theme.muted)
                    Spacer(minLength: 6)
                    Text(item.duration)
                        .font(KraftFont.mono(11, .medium))
                        .foregroundColor(Theme.muted)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface2))
    }

    // MARK: - Eine Übung, direkt anpassbar

    private func slotRow(day: DayPlan, slot: ExerciseSlot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(i18n.exerciseName(slot.exercise))
                        .font(KraftFont.inter(13.5, .semibold))
                        .foregroundColor(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Text(i18n.category(slot.exercise.category))
                            .font(KraftFont.inter(10.5))
                            .foregroundColor(Theme.muted)
                        // Das Gerät stand hier bisher gar nicht — im Generator
                        // und in den Favoriten schon.
                        EquipmentTag(i18n.equipment(slot.exercise.equipment))
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                StepperField(
                    label: i18n.t("gen.sets"),
                    value: "\(slot.sets)",
                    onDecrement: { setSets(day: day, slot: slot, to: slot.sets - 1) },
                    onIncrement: { setSets(day: day, slot: slot, to: slot.sets + 1) }
                )
                RepsField(
                    label: i18n.t("gen.reps"),
                    text: Binding(
                        get: { slot.reps },
                        set: { setReps(day: day, slot: slot, to: $0) }
                    )
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface2))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    /*
      Jede Änderung geht durch `updateSlot`. Das trifft genau diesen Slot in
      genau diesem Zyklus dieses Tages — die übrigen Übungen bleiben, wie sie
      sind, auch wenn Zyklus 1 und 2 dieselben Kennungen tragen.
    */
    private func setSets(day: DayPlan, slot: ExerciseSlot, to value: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        plan.updateSlot(dayID: day.id, cycle: viewingCycle, slotID: slot.id, sets: value)
    }

    private func setReps(day: DayPlan, slot: ExerciseSlot, to value: String) {
        plan.updateSlot(dayID: day.id, cycle: viewingCycle, slotID: slot.id, reps: value)
    }

    // MARK: - Speichern

    private var isSaved: Bool { store.contains(plan) }

    private var saveButton: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                Image(systemName: isSaved ? "checkmark" : "bookmark.fill")
                    .font(.system(size: 14))
                Text(isSaved ? i18n.t("ai.planAlreadySaved") : i18n.t("ai.savePlan"))
                    .font(KraftFont.bebas(15)).tracking(1)
                    .textCase(.uppercase)
            }
            .foregroundColor(isSaved ? Theme.muted : Theme.bg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSaved ? Theme.surface : Theme.accent)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSaved ? Theme.border : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSaved)
        .padding(.horizontal, 20)
    }

    private func resetButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text(i18n.t("ai.newPlan"))
                    .font(KraftFont.bebas(15)).tracking(1)
                    .textCase(.uppercase)
            }
            .foregroundColor(Theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    /// Erfolg meldet nur, wer wirklich gespeichert hat. Gespeichert wird der
    /// Plan in dem Zustand, in dem er gerade auf dem Schirm steht — also
    /// inklusive geänderter Sätze und Wiederholungen.
    private func save() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        guard !isSaved else {
            alert = .info(title: i18n.t("ai.planAlreadySaved"), message: i18n.t("ai.planSavedBody"))
            return
        }

        if store.save(plan: plan, input: input) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            alert = .info(title: i18n.t("ai.planSavedTitle"), message: i18n.t("ai.planSavedBody"))
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            alert = .info(
                title: i18n.t("ai.planFailedTitle"),
                message: i18n.t("ai.planFailedBody", ["reason": store.lastError ?? ""])
            )
        }
    }
}

// MARK: - Kleine Eingabefelder

/// Minus / Wert / Plus — dieselbe Optik wie die Stepper im Generator.
struct StepperField: View {
    let label: String
    let value: String
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            Text(label).kwStyle(.controlLabel)
            HStack(spacing: 4) {
                miniButton("minus", onDecrement)
                Text(value)
                    .font(KraftFont.mono(14, .bold))
                    .foregroundColor(Theme.text)
                    .frame(maxWidth: .infinity)
                miniButton("plus", onIncrement)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
    }

    private func miniButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.text)
                .frame(width: 26, height: 24)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface2))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Wiederholungen sind eine Spanne („6-10“), keine Zahl — deshalb ein Feld.
struct RepsField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(spacing: 5) {
            Text(label).kwStyle(.controlLabel)
            TextField("", text: $text)
                .font(KraftFont.mono(14, .bold))
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface2))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.border, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
    }
}
