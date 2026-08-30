import SwiftUI

/*
  Einen Plan selbst zusammenstellen.

  Das fehlte bisher ganz. Der Generator würfelt, der KI-Coach schlägt vor —
  aber wer genau weiß, was er will, hatte keinen Weg dorthin. Einzelne Übungen
  ließen sich nur neu würfeln, nicht auswählen.

  Der Aufbau folgt dem Generator, damit nichts neu gelernt werden muss: Liste
  von Übungen, je Eintrag Sätze, Wiederholungen und Pause, unten speichern
  oder direkt starten. Die Bewertung läuft mit und rechnet bei jeder Änderung
  neu — man sieht sofort, was das Hinzufügen einer Übung am Volumen ändert.
*/
public struct PlanBuilderView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var settings = GeneratorSettings.shared
    @ObservedObject private var saved = SavedPlansStore.shared
    @ObservedObject private var storeKit = StoreKitManager.shared

    public var onStartLiveWorkout: (([ExerciseSlot], String) -> Void)?

    @State private var showPicker = false
    @State private var showPro = false
    @State private var showClearConfirm = false
    @State private var showActivateConfirm = false

    public init(onStartLiveWorkout: (([ExerciseSlot], String) -> Void)? = nil) {
        self.onStartLiveWorkout = onStartLiveWorkout
    }

    private var slots: [ExerciseSlot] { settings.builderSlots }

    /*
      Für die Bewertung wird der Entwurf in einen Ein-Tages-Plan verpackt.
      PlanQualityScore rechnet auf Wochenbasis; ein einzelner Tag ist die
      Woche mit einem Trainingstag — Volumen und Balance stimmen damit, nur
      die Regenerationsbewertung hat nichts zu vergleichen und fällt neutral
      aus. Genau richtig für einen einzelnen Tag.
    */
    private var score: PlanQualityScore {
        let day = DayPlan(
            weekday: Weekdays.today(),
            name: settings.builderName.isEmpty ? "Custom" : settings.builderName,
            focus: "",
            slots: slots
        )
        let plan = TrainingPlan(
            title: settings.builderName,
            summary: "",
            weeks: 1,
            days: [day],
            nutrition: nil,
            notes: [],
            language: i18n.lang
        )
        return PlanQualityScore.evaluate(plan: plan, goal: .muscle)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            intro

            if slots.isEmpty {
                emptyState
            } else {
                PlanScoreCard(score: score)
                slotList
            }

            addButton

            if !slots.isEmpty {
                actionRow
                if storeKit.isProUnlocked { saveRow } else { premiumGate }
            }
        }
        .sheet(isPresented: $showPicker) {
            ExercisePickerSheet(
                title: i18n.lang == "en" ? "Add exercise" : "Übung hinzufügen",
                alreadyUsed: Set(slots.map(\.exercise.name))
            ) { picked in
                append(picked)
            }
        }
        .sheet(isPresented: $showPro) { ProSubscriptionView() }
        .kraftDialog(isPresented: $showClearConfirm) {
            KraftDialog(
                title: i18n.lang == "en" ? "Clear plan?" : "Plan verwerfen?",
                message: i18n.lang == "en"
                    ? "All \(slots.count) exercises will be removed. This cannot be undone."
                    : "Alle \(slots.count) Übungen werden entfernt. Das lässt sich nicht rückgängig machen.",
                isError: true,
                dismissLabel: i18n.t("auth.deleteCancel"),
                confirmLabel: i18n.lang == "en" ? "Clear" : "Verwerfen",
                onConfirm: {
                    showClearConfirm = false
                    withAnimation(.easeInOut(duration: 0.2)) {
                        settings.builderSlots = []
                        settings.builderName = ""
                    }
                },
                onDismiss: { showClearConfirm = false }
            )
        }
        .kraftDialog(isPresented: $showActivateConfirm) {
            KraftDialog(
                title: i18n.t("saved.setActiveTitle"),
                message: i18n.t(
                    ActivePlanStore.shared.plan == nil ? "saved.setActiveBody" : "saved.setActiveReplace",
                    ["name": builderTitle]
                ),
                icon: "calendar.badge.plus",
                dismissLabel: i18n.t("auth.deleteCancel"),
                confirmLabel: i18n.t("saved.setActive"),
                onConfirm: {
                    showActivateConfirm = false
                    activateAsPlan()
                },
                onDismiss: { showActivateConfirm = false }
            )
        }
    }

    /// Ohne eigenen Namen trägt der Plan einen sprechenden Ersatz — „" wäre
    /// in der Rückfrage und später im Trainingsplan eine leere Zeile.
    private var builderTitle: String {
        let typed = settings.builderName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }
        return i18n.lang == "en" ? "Custom plan" : "Eigener Plan"
    }

    /*
      Die Trainingstage kommen aus dem Profil: Der Baukasten fragt sie nicht
      ab, und ein zusätzliches Formular an dieser Stelle wäre genau die Art
      Doppelfrage, die aus dem Rest der App verschwunden ist.
    */
    private func activateAsPlan() {
        ActivePlanStore.shared.activate(
            slots: slots,
            name: builderTitle,
            days: Weekdays.sorted(UserProfileStore.shared.profile.selectedDays),
            durationWeeks: UserProfileStore.shared.profile.weeks
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Kopf

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(i18n.lang == "en" ? "BUILD YOUR OWN PLAN" : "EIGENEN PLAN BAUEN")
                .kwStyle(.wizardHeadline)

            Text(i18n.lang == "en"
                 ? "Pick exercises from the catalogue and set your own sets, reps and rest. The score updates as you go."
                 : "Wähle Übungen aus dem Katalog und lege Sätze, Wiederholungen und Pausen selbst fest. Die Bewertung rechnet live mit.")
                .font(KraftFont.inter(13))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            TextField(
                "",
                text: $settings.builderName,
                prompt: Text(i18n.lang == "en" ? "Plan name (e.g. Push Day)" : "Planname (z. B. Push-Tag)")
                    .foregroundColor(Theme.muted)
            )
            .font(KraftFont.inter(14))
            .foregroundColor(Theme.text)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            .padding(.top, 2)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 26))
                .foregroundColor(Theme.muted)
            Text(i18n.lang == "en"
                 ? "No exercises yet. Add your first one below."
                 : "Noch keine Übungen. Füge unten die erste hinzu.")
                .font(KraftFont.inter(13))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundColor(Theme.border)
        )
    }

    // MARK: - Übungsliste

    private var slotList: some View {
        VStack(spacing: 10) {
            ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                slotCard(index: index, slot: slot)
            }
        }
    }

    private func slotCard(index: Int, slot: ExerciseSlot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ExerciseVisual(category: slot.exercise.category, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(i18n.exerciseName(slot.exercise))
                        .font(KraftFont.inter(13.5, .semibold))
                        .foregroundColor(Theme.text)
                        .lineLimit(2)
                    Text(slot.exercise.categories.map { i18n.category($0) }.joined(separator: " · "))
                        .font(KraftFont.inter(10.5))
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                HStack(spacing: 4) {
                    if index > 0 {
                        iconButton("chevron.up", label: i18n.lang == "en" ? "Move up" : "Nach oben") {
                            move(from: index, to: index - 1)
                        }
                    }
                    if index < slots.count - 1 {
                        iconButton("chevron.down", label: i18n.lang == "en" ? "Move down" : "Nach unten") {
                            move(from: index, to: index + 1)
                        }
                    }
                    iconButton("trash", label: i18n.lang == "en" ? "Remove" : "Entfernen", isDestructive: true) {
                        remove(at: index)
                    }
                }
            }

            Rectangle().fill(Theme.surface2).frame(height: 1)

            FlowLayout(spacing: 14, lineSpacing: 10) {
                HStack(spacing: 6) {
                    Text(i18n.t("gen.sets")).kwStyle(.controlLabel)
                    MiniStepper(
                        value: Binding(
                            get: { settings.builderSlots[safe: index]?.sets ?? 3 },
                            set: { settings.builderSlots[safe: index]?.sets = $0 }
                        ),
                        range: 1...10
                    )
                }
                HStack(spacing: 6) {
                    Text(i18n.t("gen.reps")).kwStyle(.controlLabel)
                    TextField("", text: Binding(
                        get: { settings.builderSlots[safe: index]?.reps ?? "" },
                        set: { settings.builderSlots[safe: index]?.reps = $0 }
                    ))
                    .font(KraftFont.mono(13, .bold))
                    .foregroundColor(Theme.text)
                    .multilineTextAlignment(.center)
                    .frame(width: 64)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surface2))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
                }
                HStack(spacing: 6) {
                    Text(i18n.t("gen.restShort")).kwStyle(.controlLabel)
                    HStack(spacing: 4) {
                        ForEach(PlanGenerator.restOptions, id: \.self) { seconds in
                            RestChip(seconds: seconds, isActive: slot.restSeconds == seconds) {
                                settings.builderSlots[safe: index]?.restSeconds = seconds
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                EquipmentTag(i18n.equipment(slot.exercise.equipment))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    private func iconButton(
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
                .frame(width: 28, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface2))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Aktionen

    private var addButton: some View {
        KraftDashedButton(
            i18n.lang == "en" ? "ADD EXERCISE" : "ÜBUNG HINZUFÜGEN",
            systemImage: "plus"
        ) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showPicker = true
        }
    }

    private var actionRow: some View {
        VStack(spacing: 10) {
            if let onStartLiveWorkout {
                KraftGradientButton(i18n.t("live.startTraining"), systemImage: "play.fill") {
                    let title = settings.builderName.trimmingCharacters(in: .whitespacesAndNewlines)
                    onStartLiveWorkout(
                        slots,
                        title.isEmpty ? (i18n.lang == "en" ? "Custom plan" : "Eigener Plan") : title
                    )
                }
            }

            /*
              Den eigenen Plan als laufenden Plan setzen.

              Er ließ sich bisher speichern und als Live-Session starten, aber
              nicht über Wochen verfolgen — das blieb dem gewürfelten Plan
              vorbehalten. Wer sich sein Workout selbst zusammenstellt, will
              es aber gerade nicht einmal machen, sondern regelmäßig.
            */
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showActivateConfirm = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus").font(.system(size: 13, weight: .bold))
                    Text(i18n.t("saved.setActive")).font(KraftFont.bebas(15)).tracking(1)
                }
                .foregroundColor(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accentDim))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showClearConfirm = true
            }) {
                Text(i18n.lang == "en" ? "Clear plan" : "Plan verwerfen")
                    .font(KraftFont.inter(12.5, .semibold))
                    .foregroundColor(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
    }

    private var saveRow: some View {
        VStack(spacing: 10) {
            Button(action: savePlan) {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark.fill").font(.system(size: 13, weight: .bold))
                    Text(i18n.t("gen.save")).font(KraftFont.bebas(15)).tracking(1)
                }
                .foregroundColor(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accentDim))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if let status = saved.status {
                Text(status)
                    .font(KraftFont.inter(13, .semibold))
                    .foregroundColor(Theme.accent)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accentDim))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent, lineWidth: 1))
            }
        }
    }

    private var premiumGate: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showPro = true
        }) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold))
                    Text(i18n.t("pro.badge")).font(KraftFont.bebas(15)).tracking(1.5)
                }
                .foregroundColor(Theme.accent)

                Text(i18n.t("pro.gateText", ["feature": i18n.t("pro.feature.save")]))
                    .font(KraftFont.inter(13))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundColor(Theme.accent)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bearbeiten

    private func append(_ exercise: Exercise) {
        guard slots.count < 20 else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            settings.builderSlots.append(
                ExerciseSlot(
                    exercise: exercise,
                    sets: 3,
                    reps: PlanGenerator.defaultReps,
                    restSeconds: settings.restTime
                )
            )
        }
    }

    private func remove(at index: Int) {
        guard settings.builderSlots.indices.contains(index) else { return }
        settings.builderSlots.remove(at: index)
    }

    private func move(from: Int, to: Int) {
        guard settings.builderSlots.indices.contains(from),
              settings.builderSlots.indices.contains(to) else { return }
        let item = settings.builderSlots.remove(at: from)
        settings.builderSlots.insert(item, at: to)
    }

    private func savePlan() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard !slots.isEmpty else { return }
        if saved.save(name: settings.builderName, slots: slots) {
            settings.builderName = ""
        }
    }
}

/*
  Schreibender Zugriff über einen Index, der ins Leere zeigen kann.

  Die Felder in der Liste schreiben über `settings.builderSlots[index]`. Fällt
  ein Eintrag weg, während ein Textfeld noch den alten Index hält, wäre das
  ein Absturz. Hier gehen solche Schreibvorgänge ins Leere statt in den
  Abgrund.
*/
extension Array {
    subscript(safe index: Int) -> Element? {
        get { indices.contains(index) ? self[index] : nil }
        set {
            guard indices.contains(index), let newValue else { return }
            self[index] = newValue
        }
    }
}
