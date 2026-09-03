import SwiftUI

/*
  Die Felder des Profils — einmal definiert, an zwei Stellen benutzt.

  Der Fragebogen nach der Registrierung zeigt sie nacheinander, die
  Einstellungen zeigen sie untereinander. Wären das zwei Formulare, würde die
  eine Seite bei der nächsten Änderung die andere überholen: In genau dieser
  Verdopplung lag der Fehler, den diese Änderung beseitigt — vorher standen
  dieselben Fragen im KI-Coach und in der Home-Challenge nebeneinander.

  Jede Sektion schreibt über `UserProfileStore.binding`, also über den einen
  Weg, der auch speichert.
*/

// MARK: - Körper

public struct ProfileBodySection: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var store = UserProfileStore.shared

    /// Im Fragebogen steht die Auswertung mit dabei; in den Einstellungen
    /// wäre sie zwischen den Feldern nur im Weg.
    private let showsEvaluation: Bool

    public init(showsEvaluation: Bool = true) {
        self.showsEvaluation = showsEvaluation
    }

    private var profile: UserProfile { store.profile }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(i18n.t("ai.sex"))
            ChipGrid(count: 3) {
                WizardCardChip(i18n.t("ai.sexMale"), isActive: profile.sex == "male") {
                    store.update { $0.sex = "male" }
                }
                WizardCardChip(i18n.t("ai.sexFemale"), isActive: profile.sex == "female") {
                    store.update { $0.sex = "female" }
                }
                WizardCardChip(i18n.t("ai.sexOther"), isActive: profile.sex == "other") {
                    store.update { $0.sex = "other" }
                }
            }

            HStack(alignment: .top, spacing: 9) {
                EditableStepper(i18n.t("ai.age"), value: store.binding(\.age), range: 14...90)
                EditableStepper(i18n.t("ai.height"), unit: "cm", value: heightBinding, range: 130...220)
                EditableStepper(i18n.t("ai.weight"), unit: "kg", value: weightBinding, range: 40...160)
            }

            SectionLabel(i18n.t("ai.goalWeight"))
            HStack(alignment: .top, spacing: 9) {
                EditableStepper(i18n.t("ai.goalWeight"), unit: "kg", value: goalWeightBinding, range: 40...160)
                VStack(alignment: .leading, spacing: 4) {
                    Text(goalWeightHint)
                        .font(KraftFont.inter(12))
                        .foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if profile.goalWeightKg != nil {
                        Button(action: { store.update { $0.goalWeightKg = nil } }) {
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

            if showsEvaluation {
                BMIEvaluationCard(heightCm: profile.heightCm, weightKg: profile.weightKg)
                    .padding(.top, 4)

                BiometricsBreakdownView(
                    somatotype: store.binding(\.somatotype),
                    activityLevel: store.binding(\.activityLevel),
                    biometrics: profile.biometrics,
                    goal: profile.goal,
                    goalWeightKg: profile.goalWeightKg
                )
                .padding(.top, 6)
            } else {
                SectionLabel(i18n.t("ai.somatotypeTitle"))
                SomatotypePicker(selection: store.binding(\.somatotype))

                SectionLabel(i18n.t("ai.activityTitle"))
                ChipGrid(count: 2) {
                    ForEach(ActivityLevel.allCases) { a in
                        WizardCardChip(a.localized(i18n.lang), isActive: profile.activityLevel == a) {
                            store.update { $0.activityLevel = a }
                        }
                    }
                }
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
            get: { Int((profile.goalWeightKg ?? profile.weightKg).rounded()) },
            set: { newValue in store.update { $0.goalWeightKg = Double(newValue) } }
        )
    }

    private var heightBinding: Binding<Int> {
        Binding(
            get: { Int(profile.heightCm) },
            set: { newValue in store.update { $0.heightCm = Double(newValue) } }
        )
    }

    private var weightBinding: Binding<Int> {
        Binding(
            get: { Int(profile.weightKg) },
            set: { newValue in store.update { $0.weightKg = Double(newValue) } }
        )
    }

    private var goalWeightHint: String {
        guard let goal = profile.goalWeightKg else { return i18n.t("ai.goalWeightNone") }
        let delta = goal - profile.weightKg
        if abs(delta) < 1 { return i18n.t("ai.goalWeightHold") }
        let kg = String(format: "%.0f", abs(delta))
        return i18n.t(delta > 0 ? "ai.goalWeightGain" : "ai.goalWeightLose", ["kg": kg])
    }
}

// MARK: - Ziel & Erfahrung

public struct ProfileGoalSection: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var store = UserProfileStore.shared

    public init() {}

    private var profile: UserProfile { store.profile }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(i18n.t("ai.goal"))
            ChipGrid(count: 2) {
                ForEach(TrainingGoal.allCases) { g in
                    WizardCardChip(g.localized(i18n.lang), isActive: profile.goal == g) {
                        store.update { $0.goal = g }
                    }
                }
            }

            SectionLabel(i18n.t("ai.experience"))
            ChipGrid(count: 3) {
                ForEach(ExperienceLevel.allCases) { e in
                    WizardCardChip(e.localizedShort(i18n.lang), isActive: profile.experience == e) {
                        store.update { $0.experience = e }
                    }
                }
            }

            SectionLabel(i18n.t("profile.selfAssessment"))
            VStack(alignment: .leading, spacing: 12) {
                labelledChips(i18n.t("ai.pushups")) {
                    ChipGrid(count: PushupLevel.allCases.count) {
                        ForEach(PushupLevel.allCases) { p in
                            WizardCardChip(i18n.lang == "en" ? p.labelEn : p.labelDe,
                                           isActive: profile.pushupLevel == p) {
                                store.update { $0.pushupLevel = p }
                            }
                        }
                    }
                }
                labelledChips(i18n.t("ai.pullups")) {
                    ChipGrid(count: PullupLevel.allCases.count) {
                        ForEach(PullupLevel.allCases) { p in
                            WizardCardChip(i18n.lang == "en" ? p.labelEn : p.labelDe,
                                           isActive: profile.pullupLevel == p) {
                                store.update { $0.pullupLevel = p }
                            }
                        }
                    }
                }
                labelledChips(i18n.t("ai.plank")) {
                    ChipGrid(count: PlankLevel.allCases.count) {
                        ForEach(PlankLevel.allCases) { p in
                            WizardCardChip(i18n.lang == "en" ? p.labelEn : p.labelDe,
                                           isActive: profile.plankLevel == p) {
                                store.update { $0.plankLevel = p }
                            }
                        }
                    }
                }
            }
        }
    }

    private func labelledChips<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(KraftFont.inter(12, .semibold))
                .foregroundColor(Theme.muted)
            content()
        }
    }
}

// MARK: - Training

public struct ProfileTrainingSection: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var store = UserProfileStore.shared

    public init() {}

    private var profile: UserProfile { store.profile }

    private var allowedEquipment: [EquipmentType] {
        let allowed = UserProfile.allowedEquipment(for: profile.trainingLocation)
        return EquipmentType.allCases.filter { allowed.contains($0) }
    }

    /// „Alles“ ist aktiv, wenn nichts fehlt — auch dann, wenn der Nutzer
    /// die Kacheln einzeln angetippt hat, bis alle standen.
    private var hasAllEquipment: Bool {
        let allowed = UserProfile.allowedEquipment(for: profile.trainingLocation)
        return !allowed.isEmpty && profile.equipment.isSuperset(of: allowed)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(i18n.lang == "en" ? "TRAINING LOCATION" : "TRAININGSORT")
            ChipGrid(count: 2) {
                ForEach(TrainingLocation.allCases) { loc in
                    WizardCardChip(loc.localized(i18n.lang), isActive: profile.trainingLocation == loc) {
                        store.update {
                            $0.trainingLocation = loc
                            $0.normalizeEquipmentForLocation()
                        }
                    }
                }
            }

            SectionLabel(i18n.t("ai.equipment"))
            /*
              „Alles“ als eigene Auswahl.

              Wer im Studio trainiert, hat alles — und musste bisher acht
              Kacheln einzeln antippen, um genau das zu sagen. Ein Tipp
              setzt jetzt alles, was es an diesem Ort gibt.
            */
            ChipGrid(count: 2) {
                WizardCardChip(
                    i18n.t("ai.equipmentAll"),
                    subtitle: i18n.t("ai.equipmentAllHint"),
                    isActive: hasAllEquipment
                ) {
                    store.update { $0.equipment = Set(UserProfile.allowedEquipment(for: $0.trainingLocation)) }
                }

                ForEach(allowedEquipment) { eq in
                    WizardCardChip(
                        eq.localized(i18n.lang),
                        isActive: !hasAllEquipment && profile.equipment.contains(eq)
                    ) {
                        store.update {
                            /*
                              Aus „alles“ heraus auf eine einzelne Kachel zu
                              tippen heißt: nur diese. Sonst müsste der Nutzer
                              erst sieben abwählen, um eine zu wählen.
                            */
                            if $0.equipment.count == UserProfile.allowedEquipment(for: $0.trainingLocation).count {
                                $0.equipment = [eq]
                            } else if $0.equipment.contains(eq) {
                                $0.equipment.remove(eq)
                            } else {
                                $0.equipment.insert(eq)
                            }
                            // Leer wäre für den Server „alles“ — das Gegenteil der Absicht.
                            if $0.equipment.isEmpty { $0.normalizeEquipmentForLocation() }
                        }
                    }
                }
            }

            SectionLabel(i18n.t("ai.days"))
            ChipGrid(count: 4) {
                ForEach(Weekdays.all, id: \.self) { day in
                    WizardCardChip(day, isActive: profile.selectedDays.contains(day)) {
                        store.update {
                            if $0.selectedDays.contains(day) {
                                // Ein Plan ohne einen einzigen Trainingstag wäre keiner.
                                if $0.selectedDays.count > 1 { $0.selectedDays.remove(day) }
                            } else {
                                $0.selectedDays.insert(day)
                            }
                        }
                    }
                }
            }

            SectionLabel(i18n.lang == "en" ? "MINUTES PER SESSION" : "MINUTEN PRO EINHEIT")
            ChipGrid(columns: 3) {
                ForEach([30, 45, 60, 75, 90, 120], id: \.self) { m in
                    WizardCardChip(i18n.t("ai.minutes", ["n": "\(m)"]), isActive: profile.durationMinutes == m) {
                        store.update { $0.durationMinutes = m }
                    }
                }
            }

            SectionLabel(i18n.lang == "en" ? "REST TIME PER EXERCISE" : "SATZPAUSE PRO ÜBUNG")
            ChipGrid(columns: 4) {
                ForEach([45, 60, 90, 120], id: \.self) { s in
                    WizardCardChip("\(s)s", isActive: profile.restSeconds == s) {
                        store.update { $0.restSeconds = s }
                    }
                }
            }

            SectionLabel(i18n.t("ai.weeks"))
            ChipGrid(count: 4) {
                ForEach([2, 4, 6, 8], id: \.self) { w in
                    WizardCardChip(i18n.t("ai.weeksValue", ["n": "\(w)"]), isActive: profile.weeks == w) {
                        store.update { $0.weeks = w }
                    }
                }
            }

            SectionLabel(i18n.t("gen.method"))
            /*
              Einspaltig statt im Raster: Die Erklärung unter dem Namen ist
              der eigentliche Inhalt, und in einer halbbreiten Kachel wäre
              sie auf vier Zeilen umgebrochen.
            */
            ChipGrid(columns: 1) {
                ForEach(TrainingMethod.allCases) { m in
                    WizardCardChip(
                        i18n.method(m),
                        subtitle: m.explainer(i18n.lang),
                        isActive: profile.method == m
                    ) {
                        store.update { $0.method = m }
                    }
                }
            }

            SectionLabel(i18n.t("ai.warmupTitle"))
            ChipGrid(count: 3) {
                ForEach(["auto", "yes", "no"], id: \.self) { mode in
                    WizardCardChip(i18n.t("ai.warmup.\(mode)"), isActive: profile.warmup == mode) {
                        store.update { $0.warmup = mode }
                    }
                }
            }
        }
    }
}

// MARK: - Home-Challenge

public struct ProfileChallengeSection: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var store = UserProfileStore.shared

    public init() {}

    private var profile: UserProfile { store.profile }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            /*
              Erst die Frage, ob überhaupt. Wer nur im Studio trainiert,
              beantwortete bisher vier Fragen zu einer Funktion, die er nie
              öffnet — und konnte sie nicht überspringen.
            */
            SectionLabel(i18n.t("challenge.wantTitle"))
            Text(i18n.t("challenge.wantText"))
                .font(KraftFont.inter(13))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            ChipGrid(count: 2) {
                WizardCardChip(i18n.t("challenge.wantYes"), isActive: profile.wantsChallenge) {
                    store.update { $0.wantsChallenge = true }
                }
                WizardCardChip(i18n.t("challenge.wantNo"), isActive: !profile.wantsChallenge) {
                    store.update { $0.wantsChallenge = false }
                }
            }

            if profile.wantsChallenge {
                challengeDetails
            }
        }
    }

    @ViewBuilder
    private var challengeDetails: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(i18n.t("ai.goal"))
            ChipGrid(count: 3) {
                ForEach(ChallengeGoal.allCases) { g in
                    WizardCardChip(
                        g.localized(i18n.lang),
                        subtitle: g.localizedSubtitle(i18n.lang),
                        isActive: profile.challengeGoal == g
                    ) {
                        store.update { $0.challengeGoal = g }
                    }
                }
            }

            SectionLabel(i18n.lang == "en" ? "CHALLENGE LENGTH" : "LÄNGE DER CHALLENGE")
            ChipGrid(columns: 3) {
                ForEach(ChallengeSession.durationOptions, id: \.self) { d in
                    WizardCardChip(
                        i18n.lang == "en" ? "\(d) days" : "\(d) Tage",
                        isActive: profile.challengeDurationDays == d
                    ) {
                        store.update { $0.challengeDurationDays = d }
                    }
                }
            }

            SectionLabel(i18n.lang == "en" ? "TRAINING DAYS PER WEEK" : "TRAININGSTAGE PRO WOCHE")
            ChipGrid(columns: 5) {
                ForEach(ChallengeSession.daysPerWeekOptions, id: \.self) { d in
                    WizardCardChip("\(d)", isActive: profile.challengeDaysPerWeek == d) {
                        store.update { $0.challengeDaysPerWeek = d }
                    }
                }
            }

            SectionLabel(i18n.lang == "en" ? "MINUTES PER SESSION" : "MINUTEN PRO EINHEIT")
            ChipGrid(columns: 3) {
                ForEach(ChallengeSession.minuteOptions, id: \.self) { m in
                    WizardCardChip(i18n.t("ai.minutes", ["n": "\(m)"]), isActive: profile.challengeSessionMinutes == m) {
                        store.update { $0.challengeSessionMinutes = m }
                    }
                }
            }

            SectionLabel(i18n.t("ai.equipment"))
            ChipGrid(count: 2) {
                ForEach(ChallengeSession.homeEquipment) { eq in
                    WizardCardChip(eq.localized(i18n.lang), isActive: profile.challengeEquipment.contains(eq)) {
                        // Körpergewicht bleibt — ohne das gibt es zu Hause nichts.
                        guard eq != .bodyweight else { return }
                        store.update {
                            if $0.challengeEquipment.contains(eq) {
                                $0.challengeEquipment.remove(eq)
                            } else {
                                $0.challengeEquipment.insert(eq)
                            }
                            $0.challengeEquipment.insert(.bodyweight)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Ernährung & Einschränkungen

public struct ProfileNutritionSection: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var store = UserProfileStore.shared

    public init() {}

    private var profile: UserProfile { store.profile }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(i18n.t("ai.dietTitle"))
            ChipGrid(count: DietType.allCases.count) {
                ForEach(DietType.allCases) { d in
                    WizardCardChip(d.localized(i18n.lang), isActive: profile.diet == d) {
                        store.update { $0.diet = d }
                    }
                }
            }

            /*
              Eine einzelne Ja/Nein-Frage, weil daran genau eine Sache hängt:
              ob nach dem Training an den Shake erinnert wird. Sie steht bei
              der Ernährung und nicht bei den Mitteilungen, weil sie eine
              Gewohnheit beschreibt und keine Einstellung.
            */
            SectionLabel(i18n.t("profile.shakesTitle"))
            Toggle(isOn: store.binding(\.usesProteinShakes)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(i18n.t("profile.shakesLabel"))
                        .font(KraftFont.inter(14, .semibold))
                        .foregroundColor(Theme.text)
                    Text(i18n.t("profile.shakesHint"))
                        .font(KraftFont.inter(11.5))
                        .foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Theme.accent)
            .padding(12)
            .background(Theme.surface2)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))

            SectionLabel(i18n.t("profile.limitations"))
            VStack(alignment: .leading, spacing: 6) {
                TextField(
                    i18n.t("profile.limitationsHint"),
                    text: store.binding(\.limitations),
                    axis: .vertical
                )
                .font(KraftFont.inter(14))
                .foregroundColor(Theme.text)
                .lineLimit(2...4)
                .padding(12)
                .background(Theme.surface2)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1)
                )
            }
        }
    }
}
