import SwiftUI

public struct AICoachWizardView: View {
    @ObservedObject private var i18n = I18n.shared
    /*
      Der Zustand liegt in AICoachSession, nicht in dieser View: SwiftUI wirft
      @State beim Tabwechsel weg, und genau deshalb fing das Formular jedes Mal
      wieder von vorn an.
    */
    @ObservedObject private var session = AICoachSession.shared
    @State private var loadingPulse: Bool = false
    
    public var onStartLiveWorkout: (([ExerciseSlot], String) -> Void)?
    
    private let allWeekdays = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    
    public init(onStartLiveWorkout: (([ExerciseSlot], String) -> Void)? = nil) {
        self.onStartLiveWorkout = onStartLiveWorkout
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if let plan = session.generatedPlan {
                planTabs
                planContent(plan)
            } else {
                wizard
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        // Der Plan trägt seine Texte in sich; nach einem Sprachwechsel müssen
        // sie nachgezogen werden, sonst steht der Fokus weiter auf Deutsch.
        .onChange(of: i18n.lang) { lang in session.relocalizeIfNeeded(to: lang) }
        .onAppear { session.relocalizeIfNeeded(to: i18n.lang) }
    }

    // MARK: - Fertiger Plan

    private var planTabs: some View {
        HStack(spacing: 8) {
            planTabButton("workout", i18n.t("ai.tabWorkout"), icon: "dumbbell.fill")
            planTabButton("nutrition", i18n.t("ai.tabNutrition"), icon: "leaf.fill")
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private func planTabButton(_ id: String, _ label: String, icon: String) -> some View {
        let isActive = session.planTab == id
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            session.planTab = id
        }) {
            HStack {
                Image(systemName: icon)
                Text(label).font(KraftFont.inter(13, .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isActive ? Theme.accent : Theme.surface)
            .foregroundColor(isActive ? Theme.bg : Theme.text)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Theme.accent : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /*
      Der Plan selbst liegt in AIPlanView — dieselbe Ansicht zeigt auch den
      gespeicherten Plan unter GESPEICHERT. Vorher stand der ganze Block hier
      und war damit nur im Assistenten zu haben.
    */
    /*
      Der Plan liegt in der Sitzung, damit Änderungen an Sätzen und
      Wiederholungen einen Tabwechsel überleben und beim Speichern mitgehen.
      Der Rückfallwert greift nur in dem Moment, in dem SwiftUI die Ansicht
      noch mit dem alten Wert zeichnet.
    */
    private func planBinding(fallback: TrainingPlan) -> Binding<TrainingPlan> {
        Binding(
            get: { session.generatedPlan ?? fallback },
            set: { session.generatedPlan = $0 }
        )
    }

    @ViewBuilder
    private func planContent(_ plan: TrainingPlan) -> some View {
        if session.planTab == "workout" {
            AIPlanView(
                plan: planBinding(fallback: plan),
                viewingCycle: $session.viewingCycle,
                input: session.lastInput,
                onStartLiveWorkout: onStartLiveWorkout,
                showsSaveButton: true,
                onReset: {
                    session.reset()
                }
            )
        } else if let nutrition = plan.nutrition {
            MealGuideView(nutrition: nutrition, suggestedName: plan.title)
        }
    }

    // MARK: - Assistent
    /*
      Portierung von .ai-wizard-container aus AiCoachTab.jsx.

      Der Aufbau folgt jetzt dem Web: eine Kopfkarte mit Schrittzähler, Titel
      und anklickbarem Fortschrittsbalken, darunter je Schritt eine Überschrift,
      ein Erklärkasten und Auswahlkarten im Raster, unten eine Fußzeile mit
      Zurück links und Weiter rechts.

      Vorher gab es weder Kopfkarte noch Überschrift oder Erklärkasten, die
      Auswahl lag als volle Breite untereinander statt im Raster, und die
      Reihenfolge der Schritte wich ab: Ernährung stand allein auf Schritt 5,
      die Übersicht fehlte ganz. Jetzt ist Schritt 4 Equipment + Aufwärmen +
      Ernährung und Schritt 5 die Übersicht — wie im Web.
    */
    private var wizard: some View {
        Group {
            if session.isGenerating { aiLoading } else { wizardForm }
        }
    }

    /// `.ai-loading` — pulsierender Würfel, Text, Hinweis.
    private var aiLoading: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Theme.accentDim)
                RoundedRectangle(cornerRadius: 16).stroke(Theme.accent, lineWidth: 1)
                Image(systemName: "die.face.5.fill")
                    .font(.system(size: 26))
                    .foregroundColor(Theme.accent)
            }
            .frame(width: 58, height: 58)
            .scaleEffect(loadingPulse ? 1.08 : 1.0)
            .opacity(loadingPulse ? 0.65 : 1.0)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: loadingPulse)
            .onAppear { loadingPulse = true }
            .onDisappear { loadingPulse = false }

            Text(i18n.t("ai.loading"))
                .font(KraftFont.bebas(19)).tracking(1)
                .foregroundColor(Theme.text)
            Text(i18n.t("ai.loadingHint"))
                .font(KraftFont.inter(12.5))
                .foregroundColor(Theme.muted)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var wizardForm: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                wizardHeader
                stepContent
                wizardFooter
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    private var stepTitle: String {
        switch session.currentStep {
        case 1:  return i18n.t("ai.goal")
        case 2:  return i18n.t("ai.biometricsTitle")
        case 3:  return i18n.t("ai.days")
        case 4:  return i18n.t("ai.equipment")
        default: return i18n.t("ai.review")
        }
    }

    private var wizardHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(i18n.t("ai.step", ["current": "\(session.currentStep)", "total": "5"]))
                    .font(KraftFont.mono(11.5, .bold))
                    .foregroundColor(Theme.accent)
                Spacer(minLength: 8)
                Text(stepTitle)
                    .font(KraftFont.bebas(15)).tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.muted)
            }

            // Die Segmente sind auch im Web anklickbar — zurück zu einem
            // Schritt, den man schon ausgefüllt hat.
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { s in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(s <= session.currentStep ? Theme.accent : Theme.surface2)
                        .frame(height: 5)
                        .shadow(color: s <= session.currentStep ? Theme.accent.opacity(0.35) : .clear, radius: 5)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard s < session.currentStep else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeOut(duration: 0.2)) { session.currentStep = s }
                        }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    @ViewBuilder
    private var stepContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch session.currentStep {
            case 1: step1Goals
            case 2: step2Profile
            case 3: step3Schedule
            case 4: step4Equipment
            default: step5Review
            }
        }
    }

    private var wizardFooter: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.border).frame(height: 1)

            HStack(spacing: 12) {
                if session.currentStep > 1 {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeOut(duration: 0.2)) { session.currentStep -= 1 }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left").font(.system(size: 11, weight: .bold))
                            Text(i18n.t("ai.back")).font(KraftFont.inter(13, .semibold))
                        }
                        .foregroundColor(Theme.muted)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                // margin-left:auto — der Weiter-Knopf sitzt rechts, nicht auf
                // halber Breite.
                Spacer(minLength: 0)

                if session.currentStep < 5 {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.easeOut(duration: 0.2)) { session.currentStep += 1 }
                    }) {
                        HStack(spacing: 8) {
                            Text(i18n.t("ai.next"))
                                .font(KraftFont.bebas(14)).tracking(1)
                            Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(Theme.bg)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent))
                        .shadow(color: Theme.accent.opacity(0.2), radius: 8, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 14)
        }
        .padding(.top, 14)
    }

    // MARK: - Schritt 1: Ziel & Erfahrung

    private var step1Goals: some View {
        Group {
            Text(i18n.t("ai.title")).kwStyle(.wizardHeadline)
            AiIntroBox(i18n.t("ai.intro"))

            SectionLabel(i18n.t("ai.goal"))
            ChipGrid(count: TrainingGoal.allCases.count) {
                ForEach(TrainingGoal.allCases, id: \.self) { g in
                    WizardCardChip(g.localized(i18n.lang), isActive: session.goal == g) { session.goal = g }
                }
            }

            SectionLabel(i18n.t("ai.experience"))
            ChipGrid(count: ExperienceLevel.allCases.count) {
                ForEach(ExperienceLevel.allCases, id: \.self) { e in
                    WizardCardChip(e.localized(i18n.lang), isActive: session.experience == e) { session.experience = e }
                }
            }
        }
    }

    // MARK: - Schritt 2: Körper & Physis

    private var step2Profile: some View {
        Group {
            Text(i18n.t("ai.biometricsTitle")).kwStyle(.wizardHeadline)

            SectionLabel(i18n.t("ai.sex"))
            ChipGrid(count: 3) {
                WizardCardChip(i18n.t("ai.sexMale"), isActive: session.sex == "male") { session.sex = "male" }
                WizardCardChip(i18n.t("ai.sexFemale"), isActive: session.sex == "female") { session.sex = "female" }
                WizardCardChip(i18n.t("ai.sexOther"), isActive: session.sex == "other") { session.sex = "other" }
            }

            // Alter, Größe und Gewicht stehen nebeneinander und lassen sich
            // direkt eintippen statt nur über Plus/Minus.
            HStack(alignment: .top, spacing: 9) {
                EditableStepper(i18n.t("ai.age"), value: $session.age, range: 14...90)
                EditableStepper(i18n.t("ai.height"), unit: "cm", value: heightBinding, range: 130...220)
                EditableStepper(i18n.t("ai.weight"), unit: "kg", value: weightBinding, range: 40...160)
            }

            SectionLabel(i18n.t("ai.goalWeight"))
            HStack(alignment: .top, spacing: 9) {
                EditableStepper(i18n.t("ai.goalWeight"), unit: "kg",
                                value: goalWeightBinding, range: 40...160)
                // Was das Ziel bedeutet, steht daneben — sonst ist die Zahl
                // nur eine zweite Gewichtsangabe.
                VStack(alignment: .leading, spacing: 4) {
                    Text(goalWeightHint)
                        .font(KraftFont.inter(12))
                        .foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if session.goalWeightKg != nil {
                        Button(action: { session.goalWeightKg = nil }) {
                            Text(i18n.t("ai.goalWeightClear"))
                                .font(KraftFont.inter(11.5, .semibold))
                                .foregroundColor(Theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 22)
            }
        }
    }

    /*
      Solange niemand daran gedreht hat, zeigt der Stepper das aktuelle
      Gewicht — und `goalWeightKg` bleibt `nil`, also „kein Ziel“. Erst eine
      Eingabe macht daraus ein Ziel.
    */
    private var goalWeightBinding: Binding<Int> {
        Binding(
            get: { Int((session.goalWeightKg ?? session.weightKg).rounded()) },
            set: { session.goalWeightKg = Double($0) }
        )
    }

    private var goalWeightHint: String {
        guard let goal = session.goalWeightKg else { return i18n.t("ai.goalWeightNone") }
        let delta = goal - session.weightKg
        if abs(delta) < 1 { return i18n.t("ai.goalWeightHold") }
        let kg = String(format: "%.0f", abs(delta))
        return i18n.t(delta > 0 ? "ai.goalWeightGain" : "ai.goalWeightLose", ["kg": kg])
    }

    private var heightBinding: Binding<Int> {
        Binding(get: { Int(session.heightCm) }, set: { session.heightCm = Double($0) })
    }

    private var weightBinding: Binding<Int> {
        Binding(get: { Int(session.weightKg) }, set: { session.weightKg = Double($0) })
    }

    // MARK: - Schritt 3: Tage, Dauer, Planlänge

    private var step3Schedule: some View {
        Group {
            Text(i18n.t("ai.days")).kwStyle(.wizardHeadline)

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(allWeekdays, id: \.self) { day in
                    KraftChip(i18n.weekday(day), isActive: session.selectedDays.contains(day)) {
                        if session.selectedDays.contains(day) {
                            if session.selectedDays.count > 1 { session.selectedDays.remove(day) }
                        } else {
                            session.selectedDays.insert(day)
                        }
                    }
                }
            }

            SectionLabel(i18n.t("ai.duration"))
            ChipGrid(count: 4) {
                // SESSION_MINUTES aus AiCoachTab.jsx
                ForEach([30, 45, 60, 90], id: \.self) { m in
                    WizardCardChip(i18n.t("ai.minutes", ["n": "\(m)"]), isActive: session.durationMinutes == m) {
                        session.durationMinutes = m
                    }
                }
            }

            SectionLabel(i18n.t("ai.weeks"))
            ChipGrid(count: 3) {
                // WEEK_OPTIONS aus AiCoachTab.jsx ist [2, 4, 6]
                ForEach([2, 4, 6], id: \.self) { w in
                    WizardCardChip(i18n.t("ai.weeksValue", ["n": "\(w)"]), isActive: session.weeks == w) {
                        session.weeks = w
                    }
                }
            }

            // Dieselben Methoden wie im Generator. Der KI-Coach hat bisher
            // immer mit „Standard“ gerechnet, ohne danach zu fragen.
            SectionLabel(i18n.t("gen.method"))
            ChipGrid(count: TrainingMethod.allCases.count) {
                ForEach(TrainingMethod.allCases) { m in
                    WizardCardChip(i18n.method(m), isActive: session.method == m) {
                        session.method = m
                    }
                }
            }
        }
    }

    // MARK: - Schritt 4: Equipment, Aufwärmen, Ernährung

    private var step4Equipment: some View {
        Group {
            Text(i18n.t("ai.equipment")).kwStyle(.wizardHeadline)

            ChipGrid(count: EquipmentType.allCases.count + 1) {
                let allEq = EquipmentType.allCases
                let isAllSelected = session.selectedEquipment.isEmpty || session.selectedEquipment.count == allEq.count
                WizardCardChip(i18n.t("ai.equipmentAll"), isActive: isAllSelected) {
                    session.selectedEquipment = isAllSelected ? [.bodyweight] : Set(allEq)
                }
                ForEach(allEq, id: \.self) { eq in
                    WizardCardChip(
                        i18n.equipment(eq),
                        isActive: !isAllSelected && session.selectedEquipment.contains(eq)
                    ) {
                        if session.selectedEquipment.contains(eq) {
                            session.selectedEquipment.remove(eq)
                        } else {
                            session.selectedEquipment.insert(eq)
                        }
                    }
                }
            }

            SectionLabel(i18n.t("ai.warmupTitle"))
            ChipGrid(count: 3) {
                ForEach(["auto", "yes", "no"], id: \.self) { w in
                    WizardCardChip(
                        i18n.t("ai.warmup.\(w)"),
                        subtitle: i18n.t("ai.warmupHint.\(w)"),
                        isActive: session.warmup == w
                    ) { session.warmup = w }
                }
            }

            SectionLabel(i18n.t("ai.dietTitle"))
            ChipGrid(count: DietType.allCases.count) {
                ForEach(DietType.allCases, id: \.self) { d in
                    WizardCardChip(d.localized(i18n.lang), isActive: session.diet == d) { session.diet = d }
                }
            }
        }
    }

    // MARK: - Schritt 5: Übersicht

    private var step5Review: some View {
        Group {
            Text(i18n.t("ai.review")).kwStyle(.wizardHeadline)
            AiIntroBox(i18n.t("ai.reviewSummary"))

            VStack(alignment: .leading, spacing: 12) {
                ReviewRow(i18n.t("ai.goal"), session.goal.localized(i18n.lang), highlight: true)
                ReviewRow(i18n.t("ai.experience"), session.experience.localized(i18n.lang))
                ReviewRow(i18n.t("ai.sex"), sexLabel)
                ReviewRow(i18n.t("ai.age"), "\(session.age) \(i18n.t("ai.years"))")
                ReviewRow(i18n.t("ai.height"), "\(Int(session.heightCm)) cm")
                ReviewRow(i18n.t("ai.weight"), "\(Int(session.weightKg)) kg")
                ReviewRow(i18n.t("ai.goalWeight"), session.goalWeightKg.map {
                    "\(Int($0.rounded())) kg"
                } ?? i18n.t("ai.goalWeightNone"))
                ReviewRow(i18n.t("ai.days"), Weekdays.sorted(session.selectedDays).map { i18n.weekday($0) }.joined(separator: ", "))
                ReviewRow(i18n.t("ai.duration"), i18n.t("ai.minutes", ["n": "\(session.durationMinutes)"]))
                ReviewRow(i18n.t("ai.weeks"), i18n.t("ai.weeksValue", ["n": "\(session.weeks)"]))
                ReviewRow(i18n.t("gen.method"), i18n.method(session.method))
                ReviewRow(i18n.t("ai.dietTitle"), session.diet.localized(i18n.lang), isLast: true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.25), radius: 10, y: 4)

            KraftPrimaryButton(i18n.t("ai.submit"), systemImage: "sparkles") {
                generatePlan()
            }
            .padding(.top, 2)
        }
    }

    private var sexLabel: String {
        switch session.sex {
        case "female": return i18n.t("ai.sexFemale")
        case "other":  return i18n.t("ai.sexOther")
        default:       return i18n.t("ai.sexMale")
        }
    }

    /*
      Erst die API, dann lokal.

      Der Server hält den OpenRouter-Schlüssel und liefert die besseren Pläne.
      Er braucht aber ein Supabase-Token — und solange die App keine Anmeldung
      hat, gibt es keins. Statt dann eine Fehlermeldung zu zeigen, erzeugt die
      App den Plan selbst: lieber ein einfacherer Plan als gar keiner.
    */
    private func generatePlan() {
        session.isGenerating = true
        session.errorMessage = nil
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        let input = AICoachInput(
            goal: session.goal,
            experience: session.experience,
            biometrics: UserBiometrics(sex: session.sex, age: session.age,
                                       heightCm: session.heightCm, weightKg: session.weightKg),
            selectedDays: Array(session.selectedDays),
            sessionDurationMinutes: session.durationMinutes,
            weeks: session.weeks,
            equipment: session.selectedEquipment.isEmpty
                ? Set(EquipmentType.allCases) : session.selectedEquipment,
            diet: session.diet,
            includeWarmup: session.warmup != "no",
            goalWeightKg: session.goalWeightKg,
            method: session.method
        )

        Task {
            let request = KraftAPI.PlanRequest(
                goal: session.goal.rawValue,
                experience: session.experience.rawValue,
                sex: session.sex,
                age: session.age,
                height: Int(session.heightCm),
                weight: Int(session.weightKg),
                goalWeight: session.goalWeightKg.map { Int($0.rounded()) },
                method: session.method.rawValue,
                days: Weekdays.sorted(session.selectedDays),
                sessionMinutes: session.durationMinutes,
                weeks: session.weeks,
                equipment: session.selectedEquipment.map(\.rawValue),
                focus: [],
                limitations: "",
                warmup: session.warmup,
                diet: session.diet.rawValue,
                language: i18n.lang
            )

            do {
                let raw = try await KraftAPI.shared.generatePlan(request)
                if let plan = PlanMapper.trainingPlan(from: raw, language: i18n.lang) {
                    session.apply(plan: plan, input: input, language: i18n.lang)
                    session.isGenerating = false
                    return
                }
                session.errorMessage = i18n.t("ai.fallbackReason", ["reason": i18n.t("ai.badResponse")])
            } catch KraftAPI.APIError.unauthorized {
                // Erwartet, solange es keine Anmeldung gibt — kein Fehler für den Nutzer.
                session.errorMessage = i18n.t("ai.localFallback")
            } catch KraftAPI.APIError.rateLimited {
                session.errorMessage = i18n.t("ai.limitReached")
            } catch {
                session.errorMessage = i18n.t("ai.fallbackReason",
                                              ["reason": error.localizedDescription])
            }

            let local = AICoachService.shared.generatePlan(input: input, language: i18n.lang)
            session.apply(plan: local, input: input, language: i18n.lang)
            session.isGenerating = false
        }
    }
}
