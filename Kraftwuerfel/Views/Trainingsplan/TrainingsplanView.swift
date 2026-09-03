import SwiftUI

/*
  Portierung von src/components/TrainingsplanTab.jsx.

  Der Tab war vorher ein fertiger Plan, der sich beim Öffnen selbst erzeugt hat.
  Im Web ist er zuerst ein Formular: Tage wählen, Dauer wählen, die
  Einstellungen aus dem Generator ansehen — und erst ein Druck auf
  "Pläne würfeln" erzeugt etwas. Genau so läuft es jetzt auch hier.

  Die aufgeklappte Tagesansicht (Zyklen, Übungen, Start) steckt in DayBlockView
  und ist das, was man nach dem Antippen eines Tages sieht.
*/
public struct TrainingsplanView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var settings = GeneratorSettings.shared
    @ObservedObject private var favorites = FavoritesStore.shared
    @ObservedObject private var storeKit = StoreKitManager.shared
    @ObservedObject private var active = ActivePlanStore.shared
    @ObservedObject private var profileStore = UserProfileStore.shared

    @State private var selectedDays: Set<String> = ["Mo", "Mi", "Fr"]
    @State private var durationWeeks: Int = 4
    /// nil, solange nichts gewürfelt wurde — dann steht hier auch nichts.
    @State private var dayPlans: [String: [[ExerciseSlot]]]?
    @State private var expandedDay: String?
    /*
      Woche, die man gerade ansieht. nil heißt "die laufende" — erst ein Tippen
      auf eine Kachel löst die Ansicht vom Kalender, damit man auch in kommende
      Wochen schauen kann.
    */
    @State private var selectedWeek: Int?
    @State private var customDayOrder: [String] = []
    /// Wird gesetzt, wenn ein Gratis-Nutzer über die Favoriten-Grenze stößt.
    @State private var editingDay: DayEdit?
    @State private var showPlanSetup = false
    @State private var showFavoriteLimit = false
    @State private var showPro = false

    public var onStartLiveWorkout: (([ExerciseSlot], String) -> Void)?

    public init(onStartLiveWorkout: (([ExerciseSlot], String) -> Void)? = nil) {
        self.onStartLiveWorkout = onStartLiveWorkout
    }

    /// Welcher Tag gerade bearbeitet wird — Tag und Zyklus zusammen, weil
    /// beide zusammen erst eine Übungsliste ergeben.
    struct DayEdit: Identifiable {
        let day: String
        let cycle: Int
        var id: String { "\(day):\(cycle)" }
    }

    private var sortedDays: [String] { Weekdays.sorted(selectedDays) }
    private var activeOrderedDays: [String] {
        if let plan = active.plan {
            let valid = Set(plan.days)
            let ordered = customDayOrder.filter { valid.contains($0) }
            let remaining = Weekdays.sorted(valid.subtracting(ordered))
            return ordered + remaining
        }
        return sortedDays
    }
    private var generatedOrderedDays: [String] {
        let ordered = customDayOrder.filter { selectedDays.contains($0) }
        let remaining = Weekdays.sorted(selectedDays.subtracting(ordered))
        return ordered + remaining
    }
    private var cycles: Int { settings.cycleMode.cycles(forDuration: durationWeeks) }
    private var planSalt: String { "\(settings.split.rawValue):\(settings.method.rawValue)" }
    private var canRoll: Bool { !settings.activeCategories.isEmpty && !selectedDays.isEmpty }

    private func moveActiveDay(from source: Int, to destination: Int) {
        var days = activeOrderedDays
        guard source != destination, days.indices.contains(source), days.indices.contains(destination) else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeInOut(duration: 0.22)) {
            let moved = days.remove(at: source)
            days.insert(moved, at: destination)
            customDayOrder = days
        }
    }

    private func moveGeneratedDay(from source: Int, to destination: Int) {
        var days = generatedOrderedDays
        guard source != destination, days.indices.contains(source), days.indices.contains(destination) else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeInOut(duration: 0.22)) {
            let moved = days.remove(at: source)
            days.insert(moved, at: destination)
            customDayOrder = days
        }
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Läuft ein Plan, tritt der Fortschritt an die Stelle des
                // Formulars — wie im Web.
                if let plan = active.plan {
                    activePlanView(plan)
                } else {
                    daysSection
                    durationSection
                    settingsSummary
                    countHint
                    rollButton
                    if let dayPlans { generatedSection(dayPlans) }
                }
                if let status = favorites.status ?? active.status { statusBox(status) }
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
        .sheet(isPresented: $showPro) { ProSubscriptionView() }
        .sheet(isPresented: $showPlanSetup) {
            PlanSetupSheet(hasActivePlan: active.plan != nil)
        }
        .sheet(item: $editingDay) { target in
            DayEditSheet(
                day: target.day,
                cycle: target.cycle,
                method: active.plan?.method ?? settings.method
            )
        }
        .kraftDialog(isPresented: $showFavoriteLimit) {
            KraftDialog(
                title: i18n.t("fav.limitTitle"),
                message: i18n.t("fav.limitBody", ["n": "\(FavoritesStore.freeLimit)"]),
                icon: "heart.fill",
                dismissLabel: i18n.t("auth.deleteCancel"),
                confirmLabel: i18n.t("pro.cta"),
                onConfirm: {
                    showFavoriteLimit = false
                    showPro = true
                },
                onDismiss: { showFavoriteLimit = false }
            )
        }
    }

    /*
      Das Herz ist für alle da — die Grenze greift erst beim Antippen.
      Ausgeblendet (wie vorher über `canFavorite: isProUnlocked`) hätte ein
      Gratis-Nutzer nie erfahren, dass es Favoriten überhaupt gibt.
    */
    private func toggleFavorite(day: String, cycles: [[ExerciseSlot]], split: String, method: TrainingMethod) {
        let outcome = favorites.toggle(
            day: day, cycles: cycles, split: split, method: method,
            isPro: storeKit.isProUnlocked
        )
        if outcome == .blockedByLimit {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showFavoriteLimit = true
        }
    }

    /*
      Wird bei jeder Änderung am Plan neu gerechnet. Das ist billig genug —
      die Bewertung läuft über ein paar Dutzend Übungen, nicht über eine
      Datenbank.
    */
    @ViewBuilder
    private func generatedPlanScore(_ plans: [String: [[ExerciseSlot]]]) -> some View {
        let days: [DayPlan] = Weekdays.sorted(selectedDays).compactMap { weekday in
            guard let cycles = plans[weekday], let first = cycles.first, !first.isEmpty else { return nil }
            return DayPlan(
                weekday: weekday,
                name: PlanNames.planName(for: "\(planSalt):\(weekday)"),
                focus: "",
                warmup: [],
                cycle1Slots: first,
                cycle2Slots: cycles.count > 1 ? cycles[1] : []
            )
        }

        if !days.isEmpty {
            let scored = PlanQualityScore.evaluate(
                plan: TrainingPlan(
                    title: settings.split.localized(i18n.lang),
                    summary: "",
                    weeks: durationWeeks,
                    days: days,
                    nutrition: nil,
                    notes: []
                ),
                goal: profileStore.profile.goal,
                targetMinutes: profileStore.profile.durationMinutes
            )
            if scored.overall > 0 {
                PlanScoreCard(score: scored).padding(.top, 16)
            }
        }
    }

    @ViewBuilder
    private func activePlanScore(_ plan: ActivePlan) -> some View {
        let scored = PlanQualityScore.evaluate(
            plan: plan.asTrainingPlan(),
            goal: profileStore.profile.goal,
            targetMinutes: profileStore.profile.durationMinutes
        )
        if scored.overall > 0 {
            PlanScoreCard(score: scored)
                .padding(.top, 12)
        }
    }

    // MARK: - Laufender Plan

    @ViewBuilder
    private func activePlanView(_ plan: ActivePlan) -> some View {
        let progress = PlanProgress.progress(for: plan)
        /*
          Was wirklich im Plan steht, nicht was die Planlänge nahelegt: Seit
          die Zyklenzahl wählbar ist, kann ein 12-Wochen-Plan bewusst einen
          einzigen Zyklus haben. Gerechnet hätte hier sonst 6 gestanden und
          die Reiter hätten auf leere Zyklen gezeigt.
        */
        let planCycles = max(1, plan.dayPlans.values.map(\.count).max() ?? 1)

        if progress.finished {
            EmptyStateBox(i18n.t("tp.finished"),
                          hint: i18n.t("tp.finishedHint", ["n": "\(plan.duration)"]))
            KraftPrimaryButton(i18n.t("tp.newPlan"), systemImage: "arrow.counterclockwise", compact: true) {
                active.end()
            }
            .padding(.top, 14)
        } else {
            let shownWeek = selectedWeek ?? progress.weekIdx
            let shownCycle = shownWeek % 2 == 1 ? 0 : 1

            selectionBadges(shownWeek: shownWeek, shownCycle: shownCycle, planCycles: planCycles)
            progressCard(plan, progress, planCycles)
            /*
              Wie gut der laufende Plan ist, nicht nur wie weit er ist.

              Die Bewertung gab es bisher nur für frisch erzeugte Pläne (im
              KI-Coach und im Plan-Baukasten) — also genau dort, wo man sie
              einmal ansieht und danach nie wieder. Am laufenden Plan zählt
              sie mehr: Er ändert sich, seit einzelne Tage angepasst werden
              können, und eine getauschte Übung kann das Volumen einer
              Muskelgruppe kippen.
            */
            activePlanScore(plan)
            weekTimeline(plan, progress, shownWeek: shownWeek)
            weekdayStatusRow(plan)

            SectionLabel(i18n.t("tp.tapDay", ["cycles": planCycles == 1 ? "" : "\(planCycles) "]))
                .padding(.top, 20).padding(.bottom, 10)

            let daysList = activeOrderedDays
            VStack(spacing: 8) {
                ForEach(Array(daysList.enumerated()), id: \.element) { idx, day in
                    DayBlockView(
                        day: day,
                        cyclePlans: plan.dayPlans[day] ?? [],
                        currentCycleIdx: shownCycle,
                        isOpen: expandedDay == day,
                        isFavorited: favorites.isFavorited(day: day),
                        canFavorite: true,
                        planSalt: "\(plan.split):\(plan.method.rawValue)",
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                expandedDay = expandedDay == day ? nil : day
                            }
                        },
                        onFavorite: {
                            toggleFavorite(
                                day: day,
                                cycles: plan.dayPlans[day] ?? [],
                                split: plan.split,
                                method: plan.method
                            )
                        },
                        onStart: onStartLiveWorkout,
                        onMoveUp: idx > 0 ? { moveActiveDay(from: idx, to: idx - 1) } : nil,
                        onMoveDown: idx < daysList.count - 1 ? { moveActiveDay(from: idx, to: idx + 1) } : nil,
                        /*
                          Beides wirkt auf den GEZEIGTEN Zyklus, nicht auf den
                          laufenden: Wer sich Zyklus 2 ansieht und mischt,
                          erwartet, dass Zyklus 2 gemischt wird.
                        */
                        onEdit: { editingDay = DayEdit(day: day, cycle: shownCycle) },
                        onShuffle: { active.reshuffleDay(day: day, cycle: shownCycle) }
                    )
                }
            }

            KraftDashedButton(i18n.t("planSetup.title"), systemImage: "slider.horizontal.3") {
                showPlanSetup = true
            }
            .padding(.top, 14)

            KraftDashedButton(i18n.t("tp.end"), systemImage: "xmark") {
                active.end()
            }
            .padding(.top, 8)
        }
    }

    /*
      Was man gerade ansieht, steht als Badge ganz oben: Woche, Zyklus und —
      wenn ein Tag aufgeklappt ist — der Tag. Weicht die Auswahl von der
      laufenden Woche ab, kommt ein Knopf zum Zurückspringen dazu.
    */
    private func selectionBadges(shownWeek: Int, shownCycle: Int, planCycles: Int) -> some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            badge("\(i18n.t("tp.week")) \(shownWeek)", filled: true)
            badge(i18n.t("tp.cycle", ["n": "\(shownCycle + 1)", "total": "\(planCycles)"]), filled: false)

            if let expandedDay {
                badge(i18n.weekday(expandedDay), filled: false)
            }

            if selectedWeek != nil {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeOut(duration: 0.18)) { selectedWeek = nil }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.left").font(.system(size: 9, weight: .bold))
                        Text(i18n.t("tp.today"))
                            .font(KraftFont.mono(10, .bold))
                    }
                    .foregroundColor(Theme.muted)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 12)
    }

    private func badge(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(KraftFont.mono(10, .bold))
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundColor(filled ? Theme.bg : Theme.accent)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(filled ? Theme.accent : Theme.accentDim))
    }

    /// .progress-card
    private func progressCard(_ plan: ActivePlan, _ p: PlanProgress.Snapshot, _ planCycles: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(i18n.t("tp.week")) \(p.weekIdx)").kwStyle(.progressWeek)
                    Text("/ \(plan.duration)")
                        .font(KraftFont.inter(16))
                        .foregroundColor(Theme.muted)
                }
                Spacer(minLength: 8)
                Text(i18n.t("tp.cycle", ["n": "\(p.cycleIdx + 1)", "total": "\(planCycles)"]))
                    .kwStyle(.progressBadge)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accentDim))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accent, lineWidth: 1))
            }

            // .progress-bar-track / -fill
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.surface2)
                    RoundedRectangle(cornerRadius: 4).fill(Theme.accent)
                        .frame(width: geo.size.width * min(1, Double(p.weekIdx) / Double(max(1, plan.duration))))
                }
            }
            .frame(height: 6)
            .padding(.top, 12)

            Text("\(p.isTrainingDay ? i18n.t("tp.isTrainingDay") : i18n.t("tp.noTrainingDay")) · "
                 + i18n.t("tp.daysLeft", ["n": "\(p.daysLeftTotal)"]))
                .font(KraftFont.inter(12.5))
                .foregroundColor(Theme.muted)
                .padding(.top, 10)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent, lineWidth: 1))
    }

    /// .tp-timeline — eine Kachel je Woche, die laufende hervorgehoben.
    private func weekTimeline(_ plan: ActivePlan, _ p: PlanProgress.Snapshot, shownWeek: Int) -> some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(1...max(1, plan.duration), id: \.self) { w in
                let isNow = w == shownWeek
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeOut(duration: 0.18)) {
                        // Ein Tippen auf die laufende Woche hebt die Auswahl auf.
                        selectedWeek = (w == p.weekIdx) ? nil : w
                    }
                }) {
                VStack(spacing: 1) {
                    Text("\(w)").kwStyle(.tlWeek)
                    Text("Z\(w % 2 == 1 ? 1 : 2)")
                        .font(KraftFont.bebas(10)).tracking(0.5)
                        .foregroundColor(isNow ? Theme.accent : Theme.muted)
                }
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(isNow ? Theme.accent : Theme.border, lineWidth: isNow ? 2 : 1)
                )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 14)
    }

    /// .weekday-status-row — wann war/ist der Tag dran?
    private func weekdayStatusRow(_ plan: ActivePlan) -> some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(Weekdays.sorted(Set(plan.days)), id: \.self) { day in
                let info = PlanProgress.lastTrained(for: plan, day: day)
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        expandedDay = expandedDay == day ? nil : day
                    }
                }) {
                VStack(spacing: 2) {
                    Text(i18n.weekday(day)).kwStyle(.wdLabel)
                    HStack(spacing: 5) {
                        if info.upcoming {
                            Text(i18n.t("tp.inDays", ["n": "\(info.inDays)"])).kwStyle(.wdInfo)
                        } else {
                            Text(info.isToday
                                 ? i18n.t("tp.today")
                                 : i18n.t("tp.daysAgo", ["n": "\(info.daysAgo)"]))
                                .kwStyle(.wdInfo)
                            Text("Z\(info.cycleIdx + 1)")
                                .font(KraftFont.inter(9.5, .bold))
                                .foregroundColor(Theme.accent)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Theme.accentDim))
                        }
                    }
                }
                .frame(minWidth: 64)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(expandedDay == day ? Theme.accent
                                : (info.isToday ? Theme.accent.opacity(0.5) : Theme.border),
                                lineWidth: expandedDay == day ? 2 : 1)
                )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Formular

    private var daysSection: some View {
        Group {
            SectionLabel(i18n.t("tp.pickDays")).padding(.bottom, 10)
            HStack(spacing: 5) {
                ForEach(Weekdays.all, id: \.self) { d in
                    let isSelected = selectedDays.contains(d)
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if selectedDays.contains(d) { selectedDays.remove(d) } else { selectedDays.insert(d) }
                    }) {
                        Text(i18n.weekday(d))
                            .font(KraftFont.inter(12.5, isSelected ? .bold : .semibold))
                            .foregroundColor(isSelected ? Theme.bg : Theme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .allowsTightening(true)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isSelected ? Theme.accent : Theme.surface2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var durationSection: some View {
        Group {
            SectionLabel(i18n.t("tp.duration")).padding(.top, 20).padding(.bottom, 10)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach([2, 4, 6], id: \.self) { w in
                    KraftChip(i18n.t("tp.weeksShort", ["n": "\(w)"]), isActive: durationWeeks == w) {
                        durationWeeks = w
                    }
                }
                if dayPlans != nil {
                    // .reset-chip-btn — gestrichelt, damit er sich von der Auswahl abhebt.
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dayPlans = nil
                        expandedDay = nil
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise").font(.system(size: 11, weight: .semibold))
                            Text(i18n.t("tp.resetPlans")).font(KraftFont.inter(13, .semibold))
                        }
                        .foregroundColor(Theme.muted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(
                            Capsule().stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                .foregroundColor(Theme.border)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /*
      Antippbar, statt nur zu berichten.

      Hier stand „Einstellungen aus dem Generator" und darunter, was dort
      eingestellt war — ohne Weg dorthin. Wer Split, Methode oder Zyklen
      ändern wollte, musste den Reiter wechseln, dort suchen und
      zurückkommen. Jetzt öffnet dieselbe Karte die Auswahl an Ort und Stelle.
    */
    private var settingsSummary: some View {
        Group {
            SectionLabel(i18n.t("planSetup.title")).padding(.top, 20).padding(.bottom, 10)
            Button(action: { showPlanSetup = true }) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(i18n.t("tp.summary", [
                            "split": i18n.split(settings.split),
                            "count": "\(settings.count)",
                            "method": i18n.method(settings.method),
                            "rest": "\(settings.restTime)",
                        ]))
                        .font(KraftFont.inter(13))
                        .foregroundColor(Theme.muted)
                        .multilineTextAlignment(.leading)

                        Text(settings.cycleMode.localized(i18n.lang))
                            .font(KraftFont.mono(11, .bold))
                            .foregroundColor(Theme.accent)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.accent)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var countHint: some View {
        if !selectedDays.isEmpty {
            (
                Text(i18n.t("tp.countHint", ["days": "\(selectedDays.count)", "cycles": "\(cycles)"]) + " ")
                    .foregroundColor(Theme.muted)
                + Text(i18n.t("tp.countHintStrong", ["n": "\(selectedDays.count * cycles)"]))
                    .foregroundColor(Theme.accent)
            )
            .font(KraftFont.inter(12.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundColor(Theme.border)
            )
            .padding(.top, 12)
        }
    }

    private var rollButton: some View {
        KraftPrimaryButton(i18n.t("tp.rollPlans"), systemImage: "die.face.5.fill",
                           isEnabled: canRoll, compact: true) {
            rollPlans()
        }
        .padding(.top, 14)
    }

    // MARK: - Ergebnis

    @ViewBuilder
    private func generatedSection(_ plans: [String: [[ExerciseSlot]]]) -> some View {
        /*
          Die Bewertung auch beim frisch gewürfelten Plan.

          Sie stand nur im laufenden Plan — also erst NACH dem Start. Wer noch
          keinen gestartet hat, sah sie nie, und das ist genau der Zustand, in
          dem sich ein Gratis-Nutzer beim Ausprobieren befindet: Er konnte
          nicht wissen, dass es die Bewertung überhaupt gibt. Gesperrt zeigt
          die Karte, was sie kann und was Pro dafür kostet.
        */
        generatedPlanScore(plans)

        SectionLabel(i18n.t("tp.tapDay", ["cycles": "\(cycles) "]))
            .padding(.top, 20).padding(.bottom, 10)

        let daysList = generatedOrderedDays
        VStack(spacing: 8) {
            ForEach(Array(daysList.enumerated()), id: \.element) { idx, day in
                DayBlockView(
                    day: day,
                    cyclePlans: plans[day] ?? [],
                    isOpen: expandedDay == day,
                    isFavorited: favorites.isFavorited(day: day),
                    canFavorite: true,
                    planSalt: planSalt,
                    onToggle: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            expandedDay = expandedDay == day ? nil : day
                        }
                    },
                    onFavorite: {
                        toggleFavorite(
                            day: day,
                            cycles: plans[day] ?? [],
                            split: settings.split.rawValue,
                            method: settings.method
                        )
                    },
                    onStart: onStartLiveWorkout,
                    onMoveUp: idx > 0 ? { moveGeneratedDay(from: idx, to: idx - 1) } : nil,
                    onMoveDown: idx < daysList.count - 1 ? { moveGeneratedDay(from: idx, to: idx + 1) } : nil
                )
            }
        }

        KraftDashedButton(i18n.t("tp.rollAgain"), systemImage: "arrow.counterclockwise") {
            rollPlans()
        }
        .padding(.top, 14)

        // Erst das Starten macht aus den gewürfelten Plänen einen laufenden
        // Plan mit Startdatum — ab dann zeigt der Tab den Fortschritt.
        if storeKit.isProUnlocked {
            KraftPrimaryButton(i18n.t("tp.start"), systemImage: "dumbbell.fill", compact: true) {
                active.start(
                    days: generatedOrderedDays,
                    duration: durationWeeks,
                    split: settings.split.rawValue,
                    method: settings.method,
                    count: settings.count,
                    restTime: settings.restTime,
                    dayPlans: plans
                )
                expandedDay = generatedOrderedDays.first
            }
            .padding(.top, 10)
        }
    }

    private func statusBox(_ text: String) -> some View {
        Text(text)
            .font(KraftFont.inter(13, .semibold))
            .foregroundColor(Theme.accent)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accentDim))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent, lineWidth: 1))
            .padding(.top, 10)
    }

    // MARK: - Erzeugen

    private func rollPlans() {
        let days = sortedDays
        let categories = settings.activeCategories
        guard !days.isEmpty, !categories.isEmpty else { return }

        dayPlans = PlanGenerator.buildDayPlans(
            days: days,
            cycles: cycles,
            categories: categories,
            count: settings.count,
            method: settings.method,
            restTime: settings.restTime
        )
        expandedDay = days.first
    }
}
