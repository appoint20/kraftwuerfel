import SwiftUI

/*
  Der Home-Challenge-Tab.

  Vorher stand hier direkt die Würfel-Arena: zwei Würfel, eine Zufallsübung,
  fertig. Das war ein Spielzeug ohne Zusammenhang zum Nutzer — dieselbe
  Übung für alle, unabhängig von Alter, Gewicht, Ziel oder verfügbarer Zeit.

  Jetzt steht davor ein Fragebogen. Aus den Antworten baut der Server eine
  Challenge über die gewählte Anzahl Tage: mindestens fünf Übungen je
  Trainingstag mit Sätzen und Wiederholungen, dazu ein 7-Tage-Ernährungsplan.
  Die Würfel bleiben — als Tab daneben, für den spontanen Extra-Satz.

  Der Fragebogen ist nicht Pro-gesperrt, aber die Erzeugung braucht ein Konto:
  Der Aufruf kostet Geld und wird pro Konto und Tag begrenzt (RateLimiter im
  Server). Ohne Anmeldung gibt es deshalb einen klaren Hinweis statt eines
  stillen Fehlschlags.
*/
public struct HomeChallengeView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var session = ChallengeSession.shared
    @ObservedObject private var challengeStore = ChallengeStore.shared
    @ObservedObject private var auth = AuthService.shared

    public var onStartLiveWorkout: (([ExerciseSlot], String) -> Void)?

    @State private var showThrowOverlay = false
    @State private var showAuth = false

    public init(onStartLiveWorkout: (([ExerciseSlot], String) -> Void)? = nil) {
        self.onStartLiveWorkout = onStartLiveWorkout
    }

    public var body: some View {
        Group {
            if session.generatedPlan != nil {
                resultView
            } else {
                HomeChallengeWizardView(onSubmit: generateChallenge)
            }
        }
        .sheet(isPresented: $showAuth) { AuthView() }
        // Der Wurf liegt über allem — währenddessen ist der Fragebogen tabu.
        .overlay {
            if showThrowOverlay {
                DiceThrowOverlay(isLoading: session.isGenerating) {
                    withAnimation(.easeOut(duration: 0.25)) { showThrowOverlay = false }
                }
            }
        }
    }

    // MARK: - Ergebnis

    @ViewBuilder
    private var resultView: some View {
        if let plan = session.generatedPlan {
            /*
              Nur noch die Challenge.

              Hier standen drei Reiter: Challenge, Ernährung und Würfel. Die
              beiden hinteren waren an dieser Stelle Beiwerk — der Meal Guide
              gehört zum KI-Coach, der ihn ohnehin zeigt, und die Würfel sind
              ein eigener Reiter in der Hauptleiste. Wer eine Challenge
              startet, will die Challenge sehen; ein Reiterband über einem
              einzigen Inhalt ist nur Weg.
            */
            VStack(spacing: 14) {
                challengeHeader(plan)

                AIPlanView(
                    plan: planBinding(fallback: plan),
                    viewingCycle: $session.viewingCycle,
                    input: session.lastInput,
                    onStartLiveWorkout: onStartLiveWorkout,
                    showsSaveButton: true,
                    onReset: { session.resetPlan() }
                )
            }
        }
    }

    /// Kopfzeile mit Tagesstand, Fortschritt und dem Weg zurück in den Fragebogen.
    private func challengeHeader(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.title)
                        .font(KraftFont.bebas(19)).tracking(0.8)
                        .foregroundColor(Theme.text)
                        .lineLimit(2)

                    Text(challengeSubtitle)
                        .font(KraftFont.inter(11.5))
                        .foregroundColor(Theme.muted)
                }

                Spacer(minLength: 8)

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    session.resetPlan()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 10, weight: .bold))
                        Text(i18n.lang == "en" ? "NEW" : "NEU")
                            .font(KraftFont.bebas(12)).tracking(1)
                    }
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accentDim))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            // Fortschrittsbalken der laufenden Challenge
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surface2).frame(height: 6)
                    Capsule()
                        .fill(KraftGradientButton.gradient)
                        .frame(width: max(6, geo.size.width * challengeStore.progressPercent), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private var challengeSubtitle: String {
        let en = i18n.lang == "en"
        let day = challengeStore.currentDayNumber
        let total = session.durationDays
        let minutes = session.sessionMinutes
        return en
            ? "Day \(day) of \(total) · \(minutes) min per session · \(challengeStore.streak) done"
            : "Tag \(day) von \(total) · \(minutes) Min pro Einheit · \(challengeStore.streak) erledigt"
    }

    private func planBinding(fallback: TrainingPlan) -> Binding<TrainingPlan> {
        Binding(
            get: { session.generatedPlan ?? fallback },
            set: { session.generatedPlan = $0 }
        )
    }

    // MARK: - Erzeugung

    /*
      Kein stiller Ersatzplan.

      Der KI-Coach hatte diesen Fehler einmal: Bei jedem Fehlschlag sprang die
      lokale Erzeugung ein, der Nutzer bekam wortlos einen schwächeren Plan
      und die Fehlermeldung daneben hat nie jemand gesehen. Hier gilt: Klappt
      es nicht, sagt die App das — die Antworten bleiben stehen, ein zweiter
      Versuch ist ein Tippen entfernt.
    */
    private func generateChallenge() {
        guard auth.isSignedIn else {
            session.errorMessage = i18n.t("ai.errorSignedOut")
            showAuth = true
            return
        }

        session.errorMessage = nil
        session.isGenerating = true
        withAnimation(.easeIn(duration: 0.2)) { showThrowOverlay = true }

        let input = session.asCoachInput
        let language = i18n.lang

        let request = KraftAPI.ChallengeRequest(
            sex: session.sex,
            age: session.age,
            height: Int(session.heightCm),
            weight: Int(session.weightKg),
            goalWeight: session.goalWeightKg.map { Int($0.rounded()) },
            goal: session.goal.rawValue,
            experience: session.experience.rawValue,
            durationDays: session.durationDays,
            daysPerWeek: session.daysPerWeek,
            days: session.selectedDays,
            sessionMinutes: session.sessionMinutes,
            equipment: session.equipment.map(\.rawValue),
            diet: session.diet.rawValue,
            limitations: session.limitations.trimmingCharacters(in: .whitespacesAndNewlines),
            language: language
        )

        Task { @MainActor in
            var attempts = 0
            let maxAttempts = 3

            while attempts < maxAttempts {
                attempts += 1
                do {
                    let raw = try await KraftAPI.shared.generateChallenge(request)
                    if let plan = PlanMapper.trainingPlan(
                        from: raw,
                        language: language,
                        input: input,
                        exerciseRange: PlanMapper.challengeExerciseRange(forMinutes: session.sessionMinutes)
                    ) {
                        applyGenerated(plan: plan, input: input, language: language)
                        session.isGenerating = false
                        return
                    }
                    // Antwort kam an, ließ sich aber nicht abbilden — erneut versuchen.
                    if attempts >= maxAttempts {
                        session.errorMessage = i18n.t("ai.errorGarbled")
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

            session.isGenerating = false
            /*
              Zweiter Riegel gegen eine stehengebliebene Überlagerung: Die
              Animation darf den Fragebogen nicht überdauern, auch wenn ihr
              eigener Ablauf einmal nicht zum Ende kommt. Ohne das war ein
              gescheiterter Aufruf von einem hängenden nicht zu unterscheiden.
            */
            withAnimation(.easeOut(duration: 0.25)) { showThrowOverlay = false }
        }
    }

    /*
      Ein neuer Plan startet auch die Challenge neu: Der Fortschrittszähler in
      ChallengeStore zählt Tag 1 von n. Ohne das Zurücksetzen stünde über einer
      frischen 30-Tage-Challenge „Tag 17 von 30", weil die alte noch lief.
    */
    private func applyGenerated(plan: TrainingPlan, input: AICoachInput, language: String) {
        session.apply(plan: plan, input: input, language: language)

        challengeStore.durationDays = session.durationDays
        challengeStore.resetChallenge()

        NotificationManager.shared.scheduleWorkoutDayReminders(
            days: session.selectedDays,
            language: language,
            trainedDates: WorkoutHistoryStore.shared.trainedDates()
        )
    }
}
