import Combine
import Foundation
import SwiftUI

/*
  Der Zustand der Home-Challenge.

  Wie AICoachSession hält diese Klasse nur noch das Ergebnis. Die Antworten
  stehen im Profil (UserProfileStore) — vorher lagen Geschlecht, Alter, Größe
  und Gewicht hier ein zweites Mal, und wer sie im Coach änderte, änderte sie
  hier nicht mit.

  Bewusst getrennt von ChallengeStore: Der hält Fortschritt, Streak und
  Erinnerung der laufenden Challenge. Hier steht der erzeugte Plan.
*/
public final class ChallengeSession: ObservableObject {
    public static let shared = ChallengeSession()

    private static let storageKey = "kraftwuerfel:challengeSession"

    private let profileStore = UserProfileStore.shared
    private var profileObserver: AnyCancellable?

    // MARK: - Ergebnis

    @Published public var generatedPlan: TrainingPlan? { didSet { save() } }
    @Published public var lastInput: AICoachInput? { didSet { save() } }

    // Reine Anzeigezustände — die müssen den Neustart nicht überleben.
    @Published public var planTab: String = "plan"
    @Published public var viewingCycle: Int = 1
    @Published public var isGenerating: Bool = false
    @Published public var errorMessage: String?

    private var loading = false

    private init() {
        load()
        profileObserver = profileStore.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    // MARK: - Auswahlmöglichkeiten
    /*
      Die Listen müssen zu den Werten passen, die der Server akzeptiert
      (ChallengeAnswers.DurationDayOptions / SessionMinuteOptions). Weicht die
      App ab, rundet der Server still auf den nächsten Wert — der Nutzer
      bekäme etwas anderes, als er angetippt hat.
    */
    public static let durationOptions = [10, 20, 30, 45, 60, 90]
    public static let minuteOptions = [10, 15, 20, 30, 45, 60]
    public static let daysPerWeekOptions = [3, 4, 5, 6, 7]

    /// Zu Hause steht selten mehr herum als das hier.
    public static let homeEquipment: [EquipmentType] = [.bodyweight, .dumbbell, .kettlebell, .weightPlate]

    // MARK: - Antworten (Durchreiche auf das Profil)

    private var profile: UserProfile { profileStore.profile }

    public var goal: ChallengeGoal {
        get { profile.challengeGoal }
        set { profileStore.update { $0.challengeGoal = newValue } }
    }
    public var experience: ExperienceLevel {
        get { profile.experience }
        set { profileStore.update { $0.experience = newValue } }
    }
    public var sex: String {
        get { profile.sex }
        set { profileStore.update { $0.sex = newValue } }
    }
    public var age: Int {
        get { profile.age }
        set { profileStore.update { $0.age = newValue } }
    }
    public var heightCm: Double {
        get { profile.heightCm }
        set { profileStore.update { $0.heightCm = newValue } }
    }
    public var weightKg: Double {
        get { profile.weightKg }
        set { profileStore.update { $0.weightKg = newValue } }
    }
    public var goalWeightKg: Double? {
        get { profile.goalWeightKg }
        set { profileStore.update { $0.goalWeightKg = newValue } }
    }
    public var durationDays: Int {
        get { profile.challengeDurationDays }
        set { profileStore.update { $0.challengeDurationDays = newValue } }
    }
    public var daysPerWeek: Int {
        get { profile.challengeDaysPerWeek }
        set { profileStore.update { $0.challengeDaysPerWeek = newValue } }
    }
    public var sessionMinutes: Int {
        get { profile.challengeSessionMinutes }
        set { profileStore.update { $0.challengeSessionMinutes = newValue } }
    }
    public var equipment: Set<EquipmentType> {
        get { profile.challengeEquipment }
        set { profileStore.update { $0.challengeEquipment = newValue } }
    }
    public var diet: DietType {
        get { profile.diet }
        set { profileStore.update { $0.diet = newValue } }
    }
    public var limitations: String {
        get { profile.limitations }
        set { profileStore.update { $0.limitations = newValue } }
    }

    // MARK: - Abgeleitetes

    public var biometrics: UserBiometrics {
        UserBiometrics(
            sex: sex,
            age: age,
            heightCm: heightCm,
            weightKg: weightKg,
            somatotype: .mesomorph,
            activityLevel: profile.challengeActivityLevel
        )
    }

    /// Die Wochentage, auf die `daysPerWeek` fällt — gleiche Verteilung wie im Server.
    public var selectedDays: [String] { profile.challengeDays }

    /// Für die lokale Ernährungsberechnung und die Plananzeige.
    public var asCoachInput: AICoachInput {
        AICoachInput(
            goal: goal.trainingGoal,
            experience: experience,
            biometrics: biometrics,
            selectedDays: selectedDays,
            sessionDurationMinutes: sessionMinutes,
            weeks: max(1, Int(ceil(Double(durationDays) / 7.0))),
            equipment: equipment.isEmpty ? [.bodyweight] : equipment,
            diet: diet,
            includeWarmup: true,
            goalWeightKg: goalWeightKg,
            method: .standard,
            pushupLevel: experience == .beginner ? .beginner : .intermediate,
            pullupLevel: experience == .advanced ? .advanced : .beginner,
            plankLevel: experience == .beginner ? .under30s : .under60s,
            trainingLocation: .homeBodyweight
        )
    }

    public func toggleEquipment(_ item: EquipmentType) {
        // Körpergewicht lässt sich nicht abwählen — ohne das gibt es zu Hause nichts.
        guard item != .bodyweight else { return }
        profileStore.update {
            if $0.challengeEquipment.contains(item) {
                $0.challengeEquipment.remove(item)
            } else {
                $0.challengeEquipment.insert(item)
            }
            $0.challengeEquipment.insert(.bodyweight)
        }
    }

    public var goalWeightDeltaText: String? { profile.goalWeightDeltaText }

    // MARK: - Ablauf

    public func apply(plan: TrainingPlan, input: AICoachInput, language: String) {
        loading = true
        lastInput = input
        var stamped = plan
        if stamped.language == nil { stamped.language = language }
        generatedPlan = stamped
        planTab = "plan"
        viewingCycle = 1
        errorMessage = nil
        loading = false
        save()
    }

    /// Zurück zur Übersicht. Die Antworten bleiben stehen — meistens will man
    /// genau eine Sache ändern und neu erzeugen.
    public func resetPlan() {
        loading = true
        generatedPlan = nil
        lastInput = nil
        errorMessage = nil
        planTab = "plan"
        viewingCycle = 1
        loading = false
        save()
    }

    /*
      Für die Kontolöschung. Die Körperdaten liegen im Profil und gehen dort
      weg; hier geht der Plan weg, der sie ebenfalls in sich trägt.
    */
    public func wipe() {
        loading = true
        generatedPlan = nil
        lastInput = nil
        errorMessage = nil
        planTab = "plan"
        viewingCycle = 1
        loading = false
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    // MARK: - Speichern

    private struct Snapshot: Codable {
        var generatedPlan: TrainingPlan?
        var lastInput: AICoachInput?
    }

    private func save() {
        guard !loading else { return }
        let snapshot = Snapshot(generatedPlan: generatedPlan, lastInput: lastInput)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let s = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return }

        loading = true
        generatedPlan = s.generatedPlan
        lastInput = s.lastInput
        loading = false
    }
}

/*
  Das Ziel der Challenge, in der Sprache des Fragebogens.

  Der KI-Coach kennt fünf Ziele; für eine Home-Challenge sind das drei zu
  viel. „Definition" und „Maximalkraft" ohne Studio abzufragen wäre eine
  Auswahl, die zu einem Plan führt, den man so gar nicht bauen kann.
*/
public enum ChallengeGoal: String, CaseIterable, Identifiable, Codable {
    case buildMuscle = "muscle"
    case loseWeight = "weight_loss"
    case getFit = "fitness"

    public var id: String { rawValue }

    public var trainingGoal: TrainingGoal {
        switch self {
        case .buildMuscle: return .muscle
        case .loseWeight: return .weightLoss
        case .getFit: return .fitness
        }
    }

    public var icon: String {
        switch self {
        case .buildMuscle: return "figure.strengthtraining.traditional"
        case .loseWeight: return "flame.fill"
        case .getFit: return "heart.fill"
        }
    }

    public var titleDe: String {
        switch self {
        case .buildMuscle: return "Muskeln aufbauen"
        case .loseWeight: return "Abnehmen"
        case .getFit: return "Fit werden"
        }
    }

    public var titleEn: String {
        switch self {
        case .buildMuscle: return "Build Muscle"
        case .loseWeight: return "Lose Weight"
        case .getFit: return "Get Fit"
        }
    }

    public var subtitleDe: String {
        switch self {
        case .buildMuscle: return "Kraftausdauer & Volumen"
        case .loseWeight: return "Kaloriendefizit & Tempo"
        case .getFit: return "Ausdauer & Beweglichkeit"
        }
    }

    public var subtitleEn: String {
        switch self {
        case .buildMuscle: return "Strength endurance & volume"
        case .loseWeight: return "Calorie deficit & pace"
        case .getFit: return "Endurance & mobility"
        }
    }

    public func localized(_ lang: String) -> String { lang == "en" ? titleEn : titleDe }
    public func localizedSubtitle(_ lang: String) -> String { lang == "en" ? subtitleEn : subtitleDe }
}
