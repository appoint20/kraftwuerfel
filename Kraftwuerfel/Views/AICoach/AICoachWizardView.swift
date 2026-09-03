import SwiftUI

public struct AICoachWizardView: View {
    @ObservedObject private var i18n = I18n.shared
    /*
      Der Zustand liegt in AICoachSession, nicht in dieser View: SwiftUI wirft
      @State beim Tabwechsel weg, und genau deshalb fing das Formular jedes Mal
      wieder von vorn an.
    */
    @ObservedObject private var session = AICoachSession.shared
    @ObservedObject private var storeKit = StoreKitManager.shared
    @ObservedObject private var adManager = AdManager.shared
    @ObservedObject private var auth = AuthService.shared
    @ObservedObject private var profileStore = UserProfileStore.shared
    @State private var loadingPulse: Bool = false
    @State private var showPro = false
    @State private var showAuth = false
    @State private var showProfile = false

    public var onStartLiveWorkout: (([ExerciseSlot], String) -> Void)?


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
        .dismissKeyboardOnTap()
        // Der Plan trägt seine Texte in sich; nach einem Sprachwechsel müssen
        // sie nachgezogen werden, sonst steht der Fokus weiter auf Deutsch.
        .onChange(of: i18n.lang) { lang in session.relocalizeIfNeeded(to: lang) }
        .onAppear { session.relocalizeIfNeeded(to: i18n.lang) }
        .sheet(isPresented: $showPro) { ProSubscriptionView() }
        .sheet(isPresented: $showAuth) { AuthView() }
        .sheet(isPresented: $showProfile) { ProfileSettingsView() }
    }

    // MARK: - Pro-Sperre
    // Der KI-Coach ist eine Pro-Funktion; ohne diese Prüfung bekam jeder
    // Nutzer den Assistenten vollständig kostenlos (Richtlinie 3.1.1 / 2.3.1).

    private var proGate: some View {
        VStack(spacing: 18) {
            Spacer()
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 15, weight: .bold))
                    Text(i18n.t("pro.badge")).font(KraftFont.bebas(17)).tracking(1.5)
                }
                .foregroundColor(Theme.accent)

                Text(i18n.t("pro.gateText", ["feature": i18n.t("pro.feature.ai")]))
                    .font(KraftFont.inter(14))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            KraftPrimaryButton(i18n.t("pro.cta"), systemImage: "sparkles", compact: true) {
                showPro = true
            }
            .frame(maxWidth: 220)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
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
        } else {
            mealGuideErrorCard
        }
    }

    private var mealGuideErrorCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(Theme.orange)
                .padding(.top, 12)

            Text(i18n.t("meal.generateFailed"))
                .font(KraftFont.inter(14, .semibold))
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if let input = session.lastInput {
                    let nutr = AICoachService.shared.generateNutrition(input: input, language: i18n.lang)
                    if var current = session.generatedPlan {
                        current = TrainingPlan(
                            title: current.title,
                            summary: current.summary,
                            weeks: current.weeks,
                            days: current.days,
                            nutrition: nutr,
                            notes: current.notes,
                            language: current.language
                        )
                        session.generatedPlan = current
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text(i18n.t("meal.regenerate"))
                        .font(KraftFont.bebas(14)).tracking(1)
                }
                .foregroundColor(Theme.bg)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Theme.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, 20)
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
    // MARK: - Ein Tipp statt fünf Schritten
    /*
      Aus dem Fragebogen ist eine Übersicht geworden.

      Vorher lief der Nutzer vor JEDEM Plan durch fünf Schritte: Ziel,
      Körper, Tage, Equipment, Übersicht. Beim zweiten Plan waren die
      Antworten dieselben wie beim ersten, beim dritten auch — gefragt wurde
      trotzdem jedes Mal. Und dieselben Fragen standen ein zweites Mal in der
      Home-Challenge.

      Die Antworten stehen jetzt im Profil (UserProfile). Hier steht nur
      noch, was daraus folgt, und ein Knopf. Ändern führt an genau eine
      Stelle: den Fragebogen, den auch die Einstellungen öffnen.
    */
    private var wizard: some View {
        Group {
            if session.isGenerating {
                AICoachGeneratingView()
            } else if !profileStore.profile.isComplete {
                ProfileGateView()
            } else {
                readyScreen
            }
        }
    }

    private var readyScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                AiIntroBox(i18n.t("ready.coachText"))

                profileCard

                if let error = session.errorMessage {
                    errorCard(error)
                }

                /*
                  Die Schranke für Gratis-Nutzer.

                  `isAIPlanUnlockedForFree` gab es zwar, aber gefragt hat sie
                  niemand: Der Knopf rief direkt `generatePlan()`. Ein
                  Gratis-Nutzer bekam also beliebig viele KI-Pläne, ohne ein
                  einziges Video zu sehen — die Videos waren reine Zierde.

                  `consumeAIPlanReward()` setzt den Zähler nach jedem Plan
                  zurück, also gilt die Schranke auch für den zweiten und
                  jeden weiteren Plan.
                */
                if storeKit.isProUnlocked || adManager.isAIPlanUnlockedForFree {
                    KraftPrimaryButton(i18n.t("ready.generateCoach"), systemImage: "sparkles") {
                        generatePlan()
                    }
                } else {
                    rewardGate
                }
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    /*
      Was ein Gratis-Nutzer statt des Erstellen-Knopfes sieht: wie viele
      Videos noch fehlen, ein Knopf dafür — und der Weg an den Videos vorbei.
    */
    private var rewardGate: some View {
        let watched = adManager.rewardedVideosWatched
        let needed = adManager.requiredRewardedVideos

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.accent)
                Text(i18n.t("ai.gateTitle", ["done": "\(watched)", "total": "\(needed)"]))
                    .font(KraftFont.inter(15, .bold))
                    .foregroundColor(Theme.text)
            }

            Text(i18n.t("ai.gateText"))
                .font(KraftFont.inter(13))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            // Fortschritt als Balken — „1 von 2" liest sich schneller als Text.
            HStack(spacing: 5) {
                ForEach(0..<max(needed, 1), id: \.self) { index in
                    Capsule()
                        .fill(index < watched ? Theme.accent : Theme.surface2)
                        .frame(height: 5)
                }
            }

            KraftPrimaryButton(i18n.t("ai.gateWatch"), systemImage: "play.fill") {
                adManager.watchRewardedVideoForAIPlan { _ in }
            }

            Button(action: { showPro = true }) {
                Text(i18n.t("ai.gateSkipWithPro"))
                    .font(KraftFont.inter(12.5, .semibold))
                    .foregroundColor(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .kraftCard()
    }

    private var profileCard: some View {
        let p = profileStore.profile
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(i18n.t("ready.profileTitle"))
                    .font(KraftFont.bebas(15)).tracking(1.5)
                    .foregroundColor(Theme.accent)
                Spacer()
                Button(action: { showProfile = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil").font(.system(size: 11, weight: .bold))
                        Text(i18n.t("ready.edit")).font(KraftFont.inter(12.5, .semibold))
                    }
                    .foregroundColor(Theme.accent)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 10) {
                ReviewRow(i18n.t("ai.goal"), p.goal.localized(i18n.lang), highlight: true)
                ReviewRow(i18n.t("ai.experience"), p.experience.localizedShort(i18n.lang))
                ReviewRow(
                    i18n.t("ai.biometricsTitle"),
                    "\(p.age) · \(Int(p.heightCm)) cm · \(Int(p.weightKg)) kg"
                )
                ReviewRow(i18n.t("ai.days"), Weekdays.sorted(p.selectedDays).joined(separator: " "))
                ReviewRow(i18n.t("ai.duration"), i18n.t("ai.minutes", ["n": "\(p.durationMinutes)"]))
                ReviewRow(i18n.t("ai.weeks"), i18n.t("ai.weeksValue", ["n": "\(p.weeks)"]))
                ReviewRow(i18n.t("gen.method"), i18n.method(p.method))
                ReviewRow(i18n.t("ai.dietTitle"), p.diet.localized(i18n.lang), isLast: true)
            }
        }
        .padding(16)
        .kraftCard()
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(message).font(KraftFont.inter(13, .semibold))
            }
            .foregroundColor(Theme.orange)

            /*
              Der Notausgang bleibt: Wenn der Dienst nicht antwortet, ist ein
              gewürfelter Plan besser als kein Training. Er wird hier
              angeboten und nicht still eingesetzt — bezahlt wird für den
              KI-Plan, und was stattdessen kommt, muss der Nutzer wissen.
            */
            Button(action: { generatePlanLocally() }) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill").font(.system(size: 13))
                    Text(i18n.lang == "en" ? "Generate Offline Plan (Instant)" : "Offline-Plan sofort erstellen")
                        .font(KraftFont.inter(12.5, .semibold))
                }
                .foregroundColor(Theme.accent)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(Theme.accentDim)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.orange.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.orange.opacity(0.5), lineWidth: 1))
    }

    private var currentBiometrics: UserBiometrics {
        UserBiometrics(
            sex: session.sex,
            age: session.age,
            heightCm: session.heightCm,
            weightKg: session.weightKg,
            somatotype: session.somatotype,
            activityLevel: session.activityLevel
        )
    }


    private func generatePlanLocally() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        session.isGenerating = true
        session.errorMessage = nil

        let input = AICoachInput(
            goal: session.goal,
            experience: session.experience,
            biometrics: currentBiometrics,
            selectedDays: Array(session.selectedDays),
            sessionDurationMinutes: session.durationMinutes,
            weeks: session.weeks,
            equipment: session.selectedEquipment.isEmpty
                ? Set(EquipmentType.allCases) : session.selectedEquipment,
            diet: session.diet,
            includeWarmup: session.warmup != "no",
            goalWeightKg: session.goalWeightKg,
            method: session.method,
            pushupLevel: session.pushupLevel,
            pullupLevel: session.pullupLevel,
            plankLevel: session.plankLevel,
            trainingLocation: session.trainingLocation,
            restSeconds: session.restSeconds
        )

        let plan = AICoachService.shared.generatePlan(input: input, language: i18n.lang)
        if !storeKit.isProUnlocked {
            adManager.consumeAIPlanReward()
        }
        NotificationManager.shared.scheduleWorkoutDayReminders(
            days: Array(session.selectedDays),
            language: i18n.lang,
            trainedDates: WorkoutHistoryStore.shared.trainedDates()
        )
        session.apply(plan: plan, input: input, language: i18n.lang)
        session.isGenerating = false
    }

    private var sexLabel: String {
        switch session.sex {
        case "female": return i18n.t("ai.sexFemale")
        case "other":  return i18n.t("ai.sexOther")
        default:       return i18n.t("ai.sexMale")
        }
    }

    /*
      Nur die API. Keinen lokalen Ersatzplan.

      Vorher sprang bei jedem Fehler `AICoachService` ein und baute den Plan
      auf dem Gerät. Das sah aus wie ein Erfolg, war aber keiner: Der Nutzer
      bekam wortlos einen schwächeren, nicht-KI-Plan — die Fehlermeldung
      daneben hat nie jemand angezeigt (`session.errorMessage` wurde gesetzt
      und nirgends gelesen). Für eine Pro-Funktion ist das doppelt falsch:
      bezahlt wird für den KI-Plan, geliefert wurde ein Würfelplan.

      Jetzt gilt: klappt es nicht, sagt die App das — und der Nutzer behält
      seine Eingaben und kann es erneut versuchen.
    */
    private func generatePlan() {
        session.isGenerating = true
        session.errorMessage = nil
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        let input = AICoachInput(
            goal: session.goal,
            experience: session.experience,
            biometrics: currentBiometrics,
            selectedDays: Array(session.selectedDays),
            sessionDurationMinutes: session.durationMinutes,
            weeks: session.weeks,
            equipment: session.selectedEquipment.isEmpty
                ? Set(EquipmentType.allCases) : session.selectedEquipment,
            diet: session.diet,
            includeWarmup: session.warmup != "no",
            goalWeightKg: session.goalWeightKg,
            method: session.method,
            pushupLevel: session.pushupLevel,
            pullupLevel: session.pullupLevel,
            plankLevel: session.plankLevel,
            trainingLocation: session.trainingLocation,
            restSeconds: session.restSeconds
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
                // Die Einstellung aus dem Profil geht jetzt wirklich mit.
                restSeconds: session.restSeconds,
                diet: session.diet.rawValue,
                excludedFoods: [],
                allergies: [],
                intolerances: [],
                dietPreferences: "",
                language: i18n.lang,
                somatotype: session.somatotype.rawValue,
                activityLevel: session.activityLevel.rawValue,
                pushupLevel: session.pushupLevel.rawValue,
                pullupLevel: session.pullupLevel.rawValue,
                plankLevel: session.plankLevel.rawValue,
                trainingLocation: session.trainingLocation.rawValue,
                bmi: currentBiometrics.bmi,
                bmr: currentBiometrics.bmr,
                tdee: currentBiometrics.tdee
            )

            var attempts = 0
            let maxAttempts = 3
            var succeeded = false

            while attempts < maxAttempts && !succeeded {
                attempts += 1
                do {
                    let raw = try await KraftAPI.shared.generatePlan(request)
                    if let plan = PlanMapper.trainingPlan(from: raw, language: i18n.lang, input: input) {
                        if !storeKit.isProUnlocked {
                            adManager.consumeAIPlanReward()
                        }
                        NotificationManager.shared.scheduleWorkoutDayReminders(
                            days: Array(session.selectedDays),
                            language: i18n.lang,
                            trainedDates: WorkoutHistoryStore.shared.trainedDates()
                        )
                        session.apply(plan: plan, input: input, language: i18n.lang)
                        succeeded = true
                        session.isGenerating = false
                        return
                    }
                } catch KraftAPI.APIError.unauthorized {
                    session.errorMessage = i18n.t("ai.errorSignedOut")
                    break
                } catch KraftAPI.APIError.rateLimited {
                    if attempts < maxAttempts {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        continue
                    }
                    session.errorMessage = i18n.t("ai.errorLimit")
                } catch {
                    if attempts < maxAttempts {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        continue
                    }
                    session.errorMessage = i18n.t("ai.errorOffline")
                }
            }

            if !succeeded && session.errorMessage == nil {
                session.errorMessage = i18n.t("ai.errorGarbled")
            }
            session.isGenerating = false
        }
    }
}

// MARK: - KI-Coach Ladebildschirm mit Live-Facts & Artwork

struct AICoachGeneratingView: View {
    @ObservedObject private var i18n = I18n.shared
    @State private var currentFactIndex = 0
    @State private var progressPercent: Double = 0.05
    @State private var timerSeconds: Double = 0.0
    @State private var timer: Timer?

    private let facts = FitnessFactsProvider.facts

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Titel
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.accent)
                    Text("DEIN PERSÖNLICHER PLAN WIRD ERSTELLT …")
                        .font(KraftFont.bebas(17)).tracking(1.2)
                        .foregroundColor(Theme.text)
                }
                .padding(.top, 12)

                /*
                  Die Würfel statt des Standbilds. Kein Rahmen, keine Kachel,
                  kein Schatten: Die Animation liegt auf dem App-Hintergrund,
                  sonst sieht man ein Kästchen mit einer Animation darin
                  statt einer Animation in der App.

                  Die Tipps darunter bleiben — sie sind der Grund, warum die
                  Wartezeit auszuhalten ist.
                */
                DiceLoaderView(size: 190)
                    .padding(.vertical, 4)

                // Animierter Ladebalken & Stufen-Text
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.surface2)
                                .frame(height: 6)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.accent, Theme.accent.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(14, geo.size.width * CGFloat(progressPercent)), height: 6)
                                .animation(.linear(duration: 0.2), value: progressPercent)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, 8)

                    Text(currentStageText)
                        .font(KraftFont.inter(11.5, .medium))
                        .foregroundColor(Theme.accent)
                        .transition(.opacity)
                }
                .padding(.horizontal, 16)

                // Rotierende Fitness-Fact-Karte (alle 4 Sekunden neuer Fakt)
                let fact = facts[currentFactIndex % facts.count]
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Theme.orange)
                        Text(i18n.lang == "en" ? "DID YOU KNOW?" : "WUSSTEST DU SCHON?")
                            .font(KraftFont.bebas(14)).tracking(1.2)
                            .foregroundColor(Theme.orange)

                        Spacer()

                        Text(fact.category)
                            .font(KraftFont.mono(9.5, .bold))
                            .foregroundColor(Theme.muted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.surface2)
                            .cornerRadius(4)
                    }

                    Text(fact.title(for: i18n.lang))
                        .font(KraftFont.inter(13.5, .bold))
                        .foregroundColor(Theme.text)

                    Text(fact.fact(for: i18n.lang))
                        .font(KraftFont.inter(12.5))
                        .foregroundColor(Theme.muted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent.opacity(0.35), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 3)
                .padding(.horizontal, 16)
                .id(currentFactIndex)
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)), removal: .opacity))
            }
            .padding(.bottom, 24)
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private var currentStageText: String {
        if timerSeconds < 4 {
            return i18n.lang == "en" ? "1. Analyzing biometrics & goals..." : "1. Analysiere Biometrie & Trainingsziele..."
        } else if timerSeconds < 9 {
            return i18n.lang == "en" ? "2. Selecting optimal exercises & splits..." : "2. Wähle optimale Übungsprogression & Splits..."
        } else if timerSeconds < 15 {
            return i18n.lang == "en" ? "3. Calculating macros & 7-day meal plan..." : "3. Berechne Makronährstoffe & Ernährungsplan..."
        } else if timerSeconds < 22 {
            return i18n.lang == "en" ? "4. Structuring training cycles & sets..." : "4. Strukturiere Trainingszyklen & Satzschemata..."
        } else {
            return i18n.lang == "en" ? "5. Finalizing your AI smart plan..." : "5. Finalisiere deinen KI-Plan..."
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timerSeconds = 0.0
        progressPercent = 0.05
        currentFactIndex = Int.random(in: 0..<facts.count)

        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            timerSeconds += 0.2
            let targetProgress = min(0.96, 0.05 + (1.0 - exp(-timerSeconds / 10.0)) * 0.91)
            progressPercent = targetProgress

            if Int(timerSeconds * 10) % 40 == 0 {
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentFactIndex = (currentFactIndex + 1) % facts.count
                }
            }
        }
    }
}
