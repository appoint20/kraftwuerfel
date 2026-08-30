import SwiftUI

/*
  Portierung von src/components/GeneratorTab.jsx.

  Aufbau und Reihenfolge sind bewusst identisch zum Web: Split, ggf. eigene
  Muskelgruppen, Anzahl, Methode, Pause, Würfeln-Knopf, danach die Planliste.

  Zwei Verhaltensunterschiede zur bisherigen nativen Fassung sind Absicht, weil
  das Web es so macht:
  - Ein Tippen auf einen Chip würfelt NICHT sofort neu. Gewürfelt wird nur über
    den Knopf. Vorher sprang der Plan bei jeder Einstellung weg.
  - Die Chips brechen um, statt seitlich wegzuscrollen — alle neun Splits sind
    auf einen Blick da.
*/

/// Portierung von hooks/useReel.js — die Übungsnamen rattern durch, bis eine
/// Karte nach der anderen stehenbleibt.
public final class ReelController: ObservableObject {
    @Published public var rollingIdx: Set<Int> = []
    @Published public var scramble: [Int: String] = [:]

    private var ticker: Timer?
    private var stops: [DispatchWorkItem] = []

    public init() {}

    /*
      Eine einzelne Karte rattern lassen.

      Beim Neuwürfeln einer Übung lief bisher `runReel(count:)` über den
      ganzen Plan: Ausgetauscht wurde zwar nur der eine Eintrag, aber alle
      Karten zeigten währenddessen zufällige Namen. Von außen sah das aus, als
      hätte sich der komplette Trainingsplan geändert — genau das war die
      gemeldete Beobachtung.

      Hier läuft nur der angetippte Index. Die übrigen Karten zeigen
      unverändert ihre echten Namen.
    */
    public func runReel(only index: Int) {
        stopEverything()
        guard index >= 0 else { return }

        rollingIdx = [index]
        scramble = [index: ExerciseDatabase.all.randomElement()?.name ?? ""]

        ticker = Timer.scheduledTimer(withTimeInterval: 0.055, repeats: true) { [weak self] _ in
            guard let self, self.rollingIdx.contains(index) else { return }
            self.scramble[index] = ExerciseDatabase.all.randomElement()?.name ?? ""
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.rollingIdx.remove(index)
            self.stopTicker()
        }
        stops.append(work)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42, execute: work)
    }

    public func runReel(count: Int) {
        stopEverything()
        guard count > 0 else { return }

        rollingIdx = Set(0..<count)
        var initialScramble: [Int: String] = [:]
        for i in 0..<count {
            initialScramble[i] = ExerciseDatabase.all.randomElement()?.name ?? ""
        }
        scramble = initialScramble

        // 55 ms Taktung wie im Web.
        ticker = Timer.scheduledTimer(withTimeInterval: 0.055, repeats: true) { [weak self] _ in
            guard let self else { return }
            var next = self.scramble
            for i in self.rollingIdx {
                next[i] = ExerciseDatabase.all.randomElement()?.name ?? ""
            }
            self.scramble = next
        }

        // Erste Karte nach 420 ms, danach alle 160 ms die nächste.
        for i in 0..<count {
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.rollingIdx.remove(i)
                if i == count - 1 { self.stopTicker() }
            }
            stops.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.420 + Double(i) * 0.160, execute: work)
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    public func stopEverything() {
        stopTicker()
        stops.forEach { $0.cancel() }
        stops = []
        rollingIdx = []
        scramble = [:]
    }

    deinit {
        ticker?.invalidate()
    }
}

public struct GeneratorView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var saved = SavedPlansStore.shared
    @ObservedObject private var storeKit = StoreKitManager.shared
    @StateObject private var reel = ReelController()
    @State private var showPro = false
    @State private var isRolling = false
    @State private var showExercisePicker = false

    /*
      Der gewählte Tab liegt in GeneratorSettings, nicht als @State: SwiftUI
      wirft @State beim Tabwechsel weg, und wer in der Home-Challenge stand,
      kam im Studio-Generator zurück.
    */
    private var selectedMode: GeneratorMode { settings.mode }

    // Split, Anzahl, Methode und Pause teilt sich der Generator mit dem
    // Trainingsplan — genau wie im Web über App.jsx.
    /*
      Der gewürfelte Plan und der Name liegen ebenfalls in GeneratorSettings.
      Als @State waren sie beim Tabwechsel weg — man kam zurück und stand
      wieder vor „Noch kein Plan gewürfelt“.
    */
    @ObservedObject private var settings = GeneratorSettings.shared

    private var plan: [ExerciseSlot] {
        get { settings.plan }
        nonmutating set { settings.plan = newValue }
    }
    private var planName: Binding<String> { $settings.planName }

    public var onStartLiveWorkout: (([ExerciseSlot], String) -> Void)?

    public init(onStartLiveWorkout: (([ExerciseSlot], String) -> Void)? = nil) {
        self.onStartLiveWorkout = onStartLiveWorkout
    }

    /*
      Bei „Eigene" wird nicht mehr über Kategorien gewürfelt, sondern der
      Plan aus den selbst gewählten Übungen gebaut — ohne Auswahl gibt es
      also nichts zu bauen.
    */
    private var canRoll: Bool {
        settings.split == .custom
            ? !settings.customExercises.isEmpty
            : true
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                modeSegmentedControl
                    .padding(.horizontal, selectedMode == .challenge ? 20 : 0)
                    .padding(.bottom, 18)

                switch selectedMode {
                case .generator:
                    settingsSection
                    rollButton
                    if plan.isEmpty { emptyState } else { planList }
                case .challenge:
                    HomeChallengeView(onStartLiveWorkout: onStartLiveWorkout)
                case .builder:
                    PlanBuilderView(onStartLiveWorkout: onStartLiveWorkout)
                }
            }
            .padding(.horizontal, selectedMode == .challenge ? 0 : 20)
            .padding(.vertical, 20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
        .onDisappear {
            reel.stopEverything()
            isRolling = false
        }
        .sheet(isPresented: $showPro) { ProSubscriptionView() }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerSheet(
                title: i18n.lang == "en" ? "Your exercises" : "Deine Übungen",
                isMultiSelect: true,
                selectedNames: settings.customExerciseNames,
                selectionLimit: settings.customExerciseLimit
            ) { picked in
                settings.toggleCustomExercise(picked)
            }
        }
    }

    // MARK: - Modus Umschalter (Generator vs Home-Challenge)

    private var modeSegmentedControl: some View {
        HStack(spacing: 0) {
            // Drei Tabs statt zwei — die Beschriftungen sind deshalb kurz.
            ForEach(GeneratorMode.allCases) { mode in
                modeTabButton(mode: mode, title: mode.title(i18n.lang), icon: mode.icon)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface2))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    private func modeTabButton(mode: GeneratorMode, title: String, icon: String) -> some View {
        let isSelected = selectedMode == mode
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.18)) {
                settings.mode = mode
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(KraftFont.bebas(13.5)).tracking(0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(isSelected ? Theme.bg : Theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected ? Theme.accent : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Einstellungen

    @ViewBuilder
    private var settingsSection: some View {
        SectionLabel(i18n.t("gen.split"))
            .padding(.bottom, 10)

        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(SplitType.allCases) { s in
                KraftChip(i18n.split(s), isActive: settings.split == s) { settings.split = s }
            }
        }

        SectionLabel(i18n.t("gen.count"))
            .padding(.top, 20).padding(.bottom, 10)
        KraftStepper(value: $settings.count, range: 2...12)

        /*
          Die Übungsauswahl steht bewusst UNTER „Anzahl Übungen": Die Anzahl
          ist die Obergrenze der Auswahl, und eine Grenze zu zeigen, bevor
          man sie kennt, wäre die falsche Reihenfolge.
        */
        if settings.split == .custom {
            customExerciseSection
        }

        SectionLabel(i18n.t("gen.method"))
            .padding(.top, 20).padding(.bottom, 10)
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(TrainingMethod.allCases) { m in
                let isLegsConflict = (m == .legsFocus && settings.split == .legs)
                KraftChip(
                    i18n.method(m),
                    isActive: !isLegsConflict && settings.method == m
                ) {
                    guard !isLegsConflict else { return }
                    settings.method = m
                }
                .opacity(isLegsConflict ? 0.35 : 1.0)
                .disabled(isLegsConflict)
            }
        }

        SectionLabel(i18n.t("gen.rest"))
            .padding(.top, 20).padding(.bottom, 10)
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(PlanGenerator.restOptions, id: \.self) { r in
                KraftChip("\(r) s", isActive: settings.restTime == r) { settings.restTime = r }
            }
        }
    }

    // MARK: - Eigene Übungen (Split „Eigene")

    /*
      Zusammenstellen statt würfeln.

      Die Auswahl ist auf „Anzahl Übungen" begrenzt. Die Grenze steht sichtbar
      im Zähler, das Blatt lässt darüber hinaus nichts mehr anhaken, und
      `GeneratorSettings.toggleCustomExercise` setzt sie zusätzlich im Modell
      durch — eine Regel, die nur in der Ansicht steht, ist keine Regel.
    */
    @ViewBuilder
    private var customExerciseSection: some View {
        let selected = settings.customExercises
        let limit = settings.customExerciseLimit
        let isFull = settings.isCustomSelectionFull

        HStack {
            SectionLabel(i18n.lang == "en" ? "PICK YOUR EXERCISES" : "ÜBUNGEN AUSWÄHLEN")
            Spacer()
            Text("\(selected.count) / \(limit)")
                .font(KraftFont.mono(12, .bold))
                .foregroundColor(isFull ? Theme.orange : Theme.accent)
        }
        .padding(.top, 20).padding(.bottom, 10)

        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showExercisePicker = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "plus.magnifyingglass").font(.system(size: 13, weight: .bold))
                Text(i18n.lang == "en" ? "BROWSE EXERCISES" : "ÜBUNGEN DURCHSUCHEN")
                    .font(KraftFont.bebas(15)).tracking(1)
            }
            .foregroundColor(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accentDim))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)

        if selected.isEmpty {
            Text(i18n.lang == "en"
                 ? "Nothing picked yet. Choose up to \(limit) exercises — they become your plan."
                 : "Noch nichts gewählt. Wähle bis zu \(limit) Übungen — daraus entsteht dein Plan.")
                .font(KraftFont.inter(12))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        } else {
            VStack(spacing: 7) {
                ForEach(Array(selected.enumerated()), id: \.element.id) { index, exercise in
                    customExerciseRow(index: index, exercise: exercise)
                }
            }
            .padding(.top, 10)

            if isFull {
                HStack(spacing: 7) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.orange)
                    Text(i18n.lang == "en"
                         ? "Maximum reached. Raise “Exercise count” to pick more."
                         : "Maximum erreicht. Erhöhe „Anzahl Übungen“, um mehr zu wählen.")
                        .font(KraftFont.inter(11.5))
                        .foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
            }
        }
    }

    private func customExerciseRow(index: Int, exercise: Exercise) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(KraftFont.mono(11, .bold))
                .foregroundColor(Theme.muted)
                .frame(width: 16)

            ExerciseVisual(category: exercise.category, size: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(i18n.exerciseName(exercise))
                    .font(KraftFont.inter(12.5, .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                Text(exercise.categories.map { i18n.category($0) }.joined(separator: " · "))
                    .font(KraftFont.inter(10))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if index > 0 {
                customRowButton("chevron.up", label: i18n.lang == "en" ? "Move up" : "Nach oben") {
                    settings.moveCustomExercise(from: index, to: index - 1)
                }
            }
            if index < settings.customExercises.count - 1 {
                customRowButton("chevron.down", label: i18n.lang == "en" ? "Move down" : "Nach unten") {
                    settings.moveCustomExercise(from: index, to: index + 1)
                }
            }
            customRowButton("xmark", label: i18n.lang == "en" ? "Remove" : "Entfernen", isDestructive: true) {
                settings.removeCustomExercise(at: index)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
    }

    private func customRowButton(
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
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isDestructive ? Theme.red : Theme.muted)
                .frame(width: 26, height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface2))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /*
      Derselbe Knopf, zwei Bedeutungen.

      Im normalen Split würfelt er die Übungen. Bei „Eigene" stehen die
      Übungen fest — dort baut er den Plan daraus und würfelt nur noch das
      Satzschema aus. Er darf die Auswahl unter keinen Umständen austauschen,
      sonst wäre das Zusammenstellen sinnlos.
    */
    @ViewBuilder
    private var rollButton: some View {
        KraftPrimaryButton(
            settings.split == .custom
                ? (i18n.lang == "en" ? "BUILD MY PLAN" : "PLAN ERSTELLEN")
                : i18n.t("gen.roll"),
            systemImage: settings.split == .custom ? "checkmark" : "shuffle",
            isEnabled: canRoll && !isRolling
        ) {
            generate()
        }
        .padding(.top, 22)

        if settings.split == .custom && settings.customExercises.isEmpty {
            Text(i18n.lang == "en"
                 ? "Pick at least one exercise first."
                 : "Wähle zuerst mindestens eine Übung.")
                .font(KraftFont.inter(11.5))
                .foregroundColor(Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    private var emptyState: some View {
        EmptyStateBox(i18n.t("gen.empty"), hint: i18n.t("gen.emptyHint"))
            .padding(.top, 30)
    }

    // MARK: - Planliste

    private var planList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(plan.enumerated()), id: \.element.id) { idx, slot in
                planCard(idx: idx, slot: slot)
            }

            if let onStartLiveWorkout {
                KraftPrimaryButton(i18n.t("live.startTraining"), systemImage: "play.fill") {
                    onStartLiveWorkout(plan, "\(i18n.split(settings.split)) · \(plan.count)")
                }
                .padding(.top, 14)
            }

            KraftDashedButton(i18n.t("gen.remix"), systemImage: "arrow.counterclockwise") {
                generate()
            }
            .padding(.top, 14)

            if storeKit.isProUnlocked { saveRow } else { premiumGate }
        }
        .padding(.top, 24)
    }

    private func planCard(idx: Int, slot: ExerciseSlot) -> some View {
        let isRolling = reel.rollingIdx.contains(idx)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    ExerciseVisual(category: slot.exercise.category, size: 44)
                    Text(isRolling ? (reel.scramble[idx] ?? i18n.exerciseName(slot.exercise))
                                   : i18n.exerciseName(slot.exercise))
                        .kwStyle(.planName)
                        .foregroundColor(isRolling ? Theme.muted : Theme.text)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    if idx > 0 {
                        Button(action: { moveSlot(from: idx, to: idx - 1) }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.muted)
                                .frame(width: 28, height: 36)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface2))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    if idx < plan.count - 1 {
                        Button(action: { moveSlot(from: idx, to: idx + 1) }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.muted)
                                .frame(width: 28, height: 36)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface2))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: { reroll(idx) }) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.text)
                            .frame(width: 36, height: 36)
                            .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface2))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            if !isRolling {
                Rectangle().fill(Theme.surface2).frame(height: 1)

                FlowLayout(spacing: 14, lineSpacing: 10) {
                    HStack(spacing: 6) {
                        Text(i18n.t("gen.sets")).kwStyle(.controlLabel)
                        MiniStepper(value: setsBinding(idx), range: 1...10)
                    }
                    HStack(spacing: 6) {
                        Text(i18n.t("gen.reps")).kwStyle(.controlLabel)
                        TextField("", text: repsBinding(idx))
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
                            ForEach(PlanGenerator.restOptions, id: \.self) { r in
                                RestChip(seconds: r, isActive: slot.restSeconds == r) {
                                    plan[idx].restSeconds = r
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRolling ? Theme.accent : Theme.border, lineWidth: 1)
        )
        .onLongPressGesture(minimumDuration: 0.4) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            if idx < plan.count - 1 {
                moveSlot(from: idx, to: idx + 1)
            } else if idx > 0 {
                moveSlot(from: idx, to: idx - 1)
            }
        }
    }

    // MARK: - Speichern

    private var saveRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("", text: planName, prompt:
                    Text(i18n.t("gen.namePlaceholder")).foregroundColor(Theme.muted)
                )
                .font(KraftFont.inter(14))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                .onSubmit(savePlan)

                Button(action: savePlan) {
                    HStack(spacing: 8) {
                        Image(systemName: "dumbbell.fill").font(.system(size: 13, weight: .bold))
                        Text(i18n.t("gen.save")).font(KraftFont.inter(13, .bold))
                    }
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accentDim))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

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
        .padding(.top, 14)
    }

    /// Die Karte ersetzt das Speichern-Feld für Gratis-Nutzer. Sie ist
    /// anklickbar — vorher stand hier nur Text, und wer Pro wollte, musste
    /// erst raten, dass der Knopf dafür oben in der Kopfzeile sitzt.
    private var premiumGate: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showPro = true
        }) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold))
                    Text(i18n.t("pro.badge"))
                        .font(KraftFont.bebas(15)).tracking(1.5)
                }
                .foregroundColor(Theme.accent)

                Text(i18n.t("pro.gateText", ["feature": i18n.t("pro.feature.save")]))
                    .font(KraftFont.inter(13))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(i18n.t("pro.cta"))
                    .font(KraftFont.bebas(14)).tracking(1)
                    .foregroundColor(Theme.accent)
                    .padding(.top, 2)
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
        .padding(.top, 14)
    }

    // MARK: - Bindings & Aktionen

    private func setsBinding(_ idx: Int) -> Binding<Int> {
        Binding(get: { plan[idx].sets }, set: { plan[idx].sets = $0 })
    }

    private func repsBinding(_ idx: Int) -> Binding<String> {
        Binding(get: { plan[idx].reps }, set: { plan[idx].reps = $0 })
    }

    private func generate() {
        guard canRoll, !isRolling else { return }
        isRolling = true

        let slots: [ExerciseSlot]

        if settings.split == .custom {
            /*
              Die Übungen stehen fest; gewürfelt wird nur das Satzschema.
              `applySetScheme` verteilt bei 5x4x3 und 4x4x3 die schweren Sätze
              zufällig — das ist der Würfel, der hier noch übrig ist.
            */
            slots = PlanGenerator.applySetScheme(
                settings.customExercises,
                method: settings.method,
                restTime: settings.restTime
            )
        } else {
            let cats = settings.activeCategories
            guard !cats.isEmpty else {
                isRolling = false
                return
            }
            slots = PlanGenerator.buildPlan(
                categories: cats, count: settings.count, method: settings.method, restTime: settings.restTime
            )
        }

        guard !slots.isEmpty else {
            isRolling = false
            return
        }
        plan = slots
        saved.clearStatus()
        reel.runReel(count: slots.count)
        AdManager.shared.triggerDiceGeneratorAd()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            self.isRolling = false
        }
    }

    /*
      Neu würfeln trifft genau die angetippte Übung.

      `plan[idx] = newSlot` war schon immer richtig — der Fehler saß in der
      Animation daneben: `runReel(count: plan.count)` ließ sämtliche Karten
      Zufallsnamen durchlaufen, sodass der ganze Plan neu gewürfelt aussah.
    */
    private func reroll(_ idx: Int) {
        guard plan.indices.contains(idx) else { return }
        guard let newSlot = PlanGenerator.rerollSlot(plan: plan, at: idx, method: settings.method) else {
            // Keine Alternative in dieser Kategorie — dann lieber nichts tun,
            // als wortlos dieselbe Übung noch einmal einzusetzen.
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        plan[idx] = newSlot
        reel.runReel(only: idx)
    }

    private func moveSlot(from source: Int, to destination: Int) {
        guard source != destination, plan.indices.contains(source), plan.indices.contains(destination) else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeInOut(duration: 0.22)) {
            let item = plan.remove(at: source)
            plan.insert(item, at: destination)
        }
    }

    private func savePlan() {
        guard !plan.isEmpty else { return }
        if saved.save(name: settings.planName, slots: plan) { settings.planName = "" }
    }
}
