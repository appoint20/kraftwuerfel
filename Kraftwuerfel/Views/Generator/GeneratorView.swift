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

    public func runReel(count: Int) {
        stopEverything()
        guard count > 0 else { return }

        rollingIdx = Set(0..<count)

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

    private var canRoll: Bool { !(settings.split == .custom && settings.customCats.isEmpty) }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                settingsSection
                rollButton
                if plan.isEmpty { emptyState } else { planList }
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
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

        if settings.split == .custom {
            SectionLabel(i18n.t("gen.muscles"))
                .padding(.top, 20).padding(.bottom, 10)

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(ExerciseDatabase.categories) { c in
                    KraftChip(i18n.category(c), isActive: settings.customCats.contains(c)) {
                        settings.toggleCustomCat(c)
                    }
                }
            }
        }

        SectionLabel(i18n.t("gen.count"))
            .padding(.top, 20).padding(.bottom, 10)
        KraftStepper(value: $settings.count, range: 2...12)

        SectionLabel(i18n.t("gen.method"))
            .padding(.top, 20).padding(.bottom, 10)
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(TrainingMethod.allCases) { m in
                KraftChip(i18n.method(m), isActive: settings.method == m) { settings.method = m }
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

    private var rollButton: some View {
        KraftPrimaryButton(i18n.t("gen.roll"), systemImage: "shuffle", isEnabled: canRoll) {
            generate()
        }
        .padding(.top, 22)
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
                Button(action: { reroll(idx) }) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Theme.text)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface2))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
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

    private var premiumGate: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 13, weight: .bold))
                Text(i18n.t("pro.badge"))
                    .font(KraftFont.bebas(15)).tracking(1.5)
            }
            .foregroundColor(Theme.accent)

            Text(i18n.t("pro.gateText", ["feature": i18n.t("pro.feature.save")]))
                .font(KraftFont.inter(13))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundColor(Theme.accent)
        )
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
        let cats = settings.activeCategories
        guard !cats.isEmpty else { return }
        let slots = PlanGenerator.buildPlan(
            categories: cats, count: settings.count, method: settings.method, restTime: settings.restTime
        )
        guard !slots.isEmpty else { return }
        plan = slots
        saved.clearStatus()
        reel.runReel(count: slots.count)
    }

    private func reroll(_ idx: Int) {
        guard let newSlot = PlanGenerator.rerollSlot(plan: plan, at: idx, method: settings.method) else { return }
        plan[idx] = newSlot
        reel.runReel(count: plan.count)
    }

    private func savePlan() {
        guard !plan.isEmpty else { return }
        if saved.save(name: settings.planName, slots: plan) { settings.planName = "" }
    }
}
