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
    @ObservedObject private var storeKit = StoreKitManager.shared

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
    @State private var showPro = false
    /// Erklärt die Pro-Sperre, bevor das Kaufblatt aufgeht.
    @State private var proNotice: SaveAlert?
    /// Welche Tage offen sind. Beim Start genau der erste.
    @State private var expandedDays: Set<UUID> = []
    @State private var didSetInitialExpansion = false
    /// Welche Übung gerade getauscht wird — Tag, Zyklus und Slot.
    @State private var swapping: SwapTarget?
    /// Welchem Tag eine Übung hinzugefügt wird.
    @State private var addingTo: AddTarget?

    private struct SwapTarget: Identifiable {
        let id = UUID()
        let dayID: UUID
        let cycle: Int
        let slot: ExerciseSlot
        let usedNames: Set<String>
    }

    private struct AddTarget: Identifiable {
        let id = UUID()
        let dayID: UUID
        let cycle: Int
        let usedNames: Set<String>
    }

    /// In welchen Zyklus Änderungen gehen. Ohne zweiten Zyklus immer 1 —
    /// sonst editiert der Nutzer etwas, das er gar nicht sieht.
    private var activeCycle: Int { plan.hasTwoCycles ? viewingCycle : 1 }

    /*
      Die Bewertung wird bei jeder Änderung neu gerechnet. Das ist reine
      Arithmetik über höchstens ein paar Dutzend Übungen — kein Grund, sie zu
      puffern, und der Wert stimmt so immer mit dem überein, was auf dem
      Schirm steht.
    */
    private var score: PlanQualityScore {
        PlanQualityScore.evaluate(
            plan: plan,
            goal: input?.goal ?? .muscle,
            targetMinutes: input?.sessionDurationMinutes
        )
    }

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

                PlanScoreCard(score: score)
                    .padding(.horizontal, 20)

                cycleToggleRow

                if plan.hasTwoCycles {
                    cycleSelector
                }
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
        .kraftDialog(item: $alert) { entry in
            KraftDialog(title: entry.title, message: entry.message, isError: entry.isError) {
                alert = nil
            }
        }
        .kraftDialog(item: $proNotice) { entry in
            KraftDialog(
                title: entry.title,
                message: entry.message,
                icon: "sparkles",
                dismissLabel: i18n.t("auth.deleteCancel"),
                confirmLabel: i18n.t("pro.cta"),
                onConfirm: {
                    proNotice = nil
                    showPro = true
                },
                onDismiss: { proNotice = nil }
            )
        }
        .sheet(isPresented: $showPro) {
            ProSubscriptionView()
        }
        .sheet(item: $swapping) { target in
            ExercisePickerSheet(
                title: i18n.lang == "en" ? "Swap exercise" : "Übung tauschen",
                highlightCategories: target.slot.exercise.categories,
                alreadyUsed: target.usedNames,
                allowedEquipment: input?.equipment
            ) { picked in
                plan.replaceSlot(
                    dayID: target.dayID,
                    cycle: target.cycle,
                    slotID: target.slot.id,
                    with: picked
                )
            }
        }
        .sheet(item: $addingTo) { target in
            ExercisePickerSheet(
                title: i18n.lang == "en" ? "Add exercise" : "Übung hinzufügen",
                alreadyUsed: target.usedNames,
                allowedEquipment: input?.equipment
            ) { picked in
                plan.addSlot(dayID: target.dayID, cycle: target.cycle, exercise: picked)
            }
        }
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

    /*
      Der Schalter für den zweiten Zyklus.

      Vorher gab es ihn nicht: Ob ein Plan mit ein oder zwei Zyklen lief,
      ergab sich daraus, ob das Modell zwei unterschiedliche Wochen geliefert
      hatte. Wer mit drei Trainingstagen einfach dreimal dasselbe machen
      wollte, konnte das nicht einstellen — und wer den Wechsel wollte, bekam
      ihn nur mit Glück.
    */
    private var cycleToggleRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(plan.hasTwoCycles ? Theme.accent : Theme.muted)

            VStack(alignment: .leading, spacing: 2) {
                Text(i18n.lang == "en" ? "Two alternating cycles" : "Zwei Zyklen im Wechsel")
                    .font(KraftFont.inter(13, .semibold))
                    .foregroundColor(Theme.text)
                Text(plan.hasTwoCycles
                     ? (i18n.lang == "en"
                        ? "Week A and week B alternate — more variety per muscle."
                        : "Woche A und B wechseln sich ab — mehr Reize je Muskel.")
                     : (i18n.lang == "en"
                        ? "Every week runs the same plan."
                        : "Jede Woche läuft derselbe Plan."))
                    .font(KraftFont.inter(11))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            Toggle("", isOn: Binding(
                get: { plan.hasTwoCycles },
                set: { enabled in
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        plan.setTwoCycles(
                            enabled,
                            equipment: input?.equipment,
                            method: input?.method ?? .standard
                        )
                        if !enabled { viewingCycle = 1 }
                    }
                }
            ))
            .labelsHidden()
            .tint(Theme.accent)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
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
        let activeCycle = plan.hasTwoCycles ? viewingCycle : 1
        let slots = day.slots(forCycle: activeCycle)
        let cycleLabel = plan.hasTwoCycles ? i18n.t("tp.cycleLabel", ["n": "\(viewingCycle)"]) : ""
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
                            if plan.hasTwoCycles {
                                Text(cycleLabel)
                                    .font(KraftFont.bebas(14)).tracking(0.5)
                                    .foregroundColor(Theme.accent)
                            }
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
                            let title = plan.hasTwoCycles
                                ? "\(day.name) · \(i18n.weekday(day.weekday)) (\(cycleLabel))"
                                : "\(day.name) · \(i18n.weekday(day.weekday))"
                            onStartLiveWorkout(slots, title)
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

                    dayToolbar(day: day, slots: slots)

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

    /*
      Werkzeuge für genau diesen Tag.

      „Neu mischen“ trifft nur diesen einen Tag. Vorher gab es dafür nichts:
      Wer mit dem Montag unzufrieden war, musste den ganzen Plan neu erzeugen
      und verlor damit auch Mittwoch und Freitag. Gemischt wird innerhalb der
      Muskelgruppen, die der Tag ohnehin trifft — ein Brust-Tag bleibt einer.
    */
    private func dayToolbar(day: DayPlan, slots: [ExerciseSlot]) -> some View {
        HStack(spacing: 8) {
            Button(action: { reshuffle(day) }) {
                HStack(spacing: 5) {
                    Image(systemName: "shuffle").font(.system(size: 11, weight: .bold))
                    Text(i18n.lang == "en" ? "SHUFFLE DAY" : "TAG NEU MISCHEN")
                        .font(KraftFont.bebas(12.5)).tracking(0.8)
                }
                .foregroundColor(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accentDim))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent.opacity(0.45), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                addingTo = AddTarget(
                    dayID: day.id,
                    cycle: activeCycle,
                    usedNames: Set(slots.map(\.exercise.name))
                )
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                    Text(i18n.lang == "en" ? "ADD" : "ÜBUNG")
                        .font(KraftFont.bebas(12.5)).tracking(0.8)
                }
                .foregroundColor(Theme.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface2))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func reshuffle(_ day: DayPlan) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeInOut(duration: 0.22)) {
            let ok = plan.reshuffleDay(
                dayID: day.id,
                cycle: activeCycle,
                equipment: input?.equipment,
                method: input?.method ?? .standard
            )
            if !ok { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
        }
    }

    // MARK: - Eine Übung, direkt anpassbar

    private func slotRow(day: DayPlan, slot: ExerciseSlot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                ExerciseVisual(exercise: slot.exercise, size: 40)
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

                // Tauschen, würfeln, entfernen — für genau diese eine Übung.
                HStack(spacing: 5) {
                    slotAction("arrow.left.arrow.right", label: i18n.lang == "en" ? "Swap exercise" : "Übung tauschen") {
                        swapping = SwapTarget(
                            dayID: day.id,
                            cycle: activeCycle,
                            slot: slot,
                            usedNames: Set(day.slots(forCycle: activeCycle).map(\.exercise.name))
                        )
                    }
                    slotAction("die.face.5", label: i18n.lang == "en" ? "Roll a different one" : "Andere würfeln") {
                        plan.rerollSlot(
                            dayID: day.id,
                            cycle: activeCycle,
                            slotID: slot.id,
                            method: input?.method ?? .standard
                        )
                    }
                    if day.slots(forCycle: activeCycle).count > 1 {
                        slotAction("trash", label: i18n.lang == "en" ? "Remove" : "Entfernen", isDestructive: true) {
                            plan.removeSlot(dayID: day.id, cycle: activeCycle, slotID: slot.id)
                        }
                    }
                }
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

    private func slotAction(
        _ symbol: String,
        label: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.18)) { action() }
        }) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isDestructive ? Theme.red : Theme.muted)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /*
      Jede Änderung geht durch `updateSlot`. Das trifft genau diesen Slot in
      genau diesem Zyklus dieses Tages — die übrigen Übungen bleiben, wie sie
      sind, auch wenn Zyklus 1 und 2 dieselben Kennungen tragen.
    */
    private func setSets(day: DayPlan, slot: ExerciseSlot, to value: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        plan.updateSlot(dayID: day.id, cycle: activeCycle, slotID: slot.id, sets: value)
    }

    private func setReps(day: DayPlan, slot: ExerciseSlot, to value: String) {
        plan.updateSlot(dayID: day.id, cycle: activeCycle, slotID: slot.id, reps: value)
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

        /*
          Erst sagen, warum — dann anbieten. Vorher sprang hier ohne ein Wort
          das Kaufblatt auf; wer nur speichern wollte, stand unvermittelt vor
          einer Preisliste und wusste nicht, was das mit seinem Tippen zu tun
          hat.
        */
        guard storeKit.isProUnlocked else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            proNotice = SaveAlert.info(
                title: i18n.t("pro.badge"),
                message: i18n.t("ai.savingIsProFeature")
            )
            return
        }

        guard !isSaved else {
            alert = .info(title: i18n.t("ai.planAlreadySaved"), message: i18n.t("ai.planSavedBody"))
            return
        }

        if store.save(plan: plan, input: input) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            alert = .info(title: i18n.t("ai.planSavedTitle"), message: i18n.t("ai.planSavedBody"))
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            alert = .error(
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
