import Combine
import Foundation
import SwiftUI

/*
  Der Zustand des KI-Assistenten.

  Hier liegt nur noch das ERGEBNIS — der erzeugte Plan und die Eingaben, aus
  denen er entstand. Die Antworten des Nutzers stehen in UserProfileStore:
  Sie waren vorher zweimal da, einmal hier und einmal in ChallengeSession,
  und die beiden Stände konnten auseinanderlaufen.

  Die Eigenschaften unten bleiben als Durchreiche stehen. Aufrufer schreiben
  weiter `session.weightKg = 82`, landen damit aber im Profil. Zwei Wege zum
  selben Wert wären der Fehler gewesen, den diese Änderung beseitigen soll —
  ein Weg, an zwei Namen erreichbar, ist keiner.
*/
public final class AICoachSession: ObservableObject {
    public static let shared = AICoachSession()

    private static let storageKey = "kraftwuerfel:aiCoachSession"

    private let profileStore = UserProfileStore.shared
    private var profileObserver: AnyCancellable?

    // MARK: - Ergebnis

    /// Der fertige Plan bleibt erhalten — sonst wäre er nach einem
    /// Tabwechsel weg, obwohl er Geld gekostet hat.
    @Published public var generatedPlan: TrainingPlan? { didSet { save() } }

    /// Die Eingaben, aus denen der Plan entstanden ist. Ohne sie ließe er sich
    /// nach einem Sprachwechsel nicht neu beschriften.
    @Published public var lastInput: AICoachInput? { didSet { save() } }

    // Reine Anzeigezustände: die müssen den Neustart nicht überleben.
    @Published public var planTab: String = "workout"
    @Published public var viewingCycle: Int = 1
    @Published public var isGenerating: Bool = false
    @Published public var errorMessage: String?

    private var loading = false

    private init() {
        load()
        /*
          Ändert sich das Profil, muss auch diese Sitzung neu zeichnen: Die
          Ansichten beobachten `session`, lesen aber Werte, die im Profil
          liegen. Ohne diese Weiterleitung bliebe die Übersicht im Assistenten
          auf dem alten Gewicht stehen, bis etwas anderes ein Neuzeichnen
          auslöst.
        */
        profileObserver = profileStore.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    // MARK: - Antworten (Durchreiche auf das Profil)

    private var profile: UserProfile { profileStore.profile }

    public var goal: TrainingGoal {
        get { profile.goal }
        set { profileStore.update { $0.goal = newValue } }
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
    public var somatotype: Somatotype {
        get { profile.somatotype }
        set { profileStore.update { $0.somatotype = newValue } }
    }
    public var activityLevel: ActivityLevel {
        get { profile.activityLevel }
        set { profileStore.update { $0.activityLevel = newValue } }
    }
    public var pushupLevel: PushupLevel {
        get { profile.pushupLevel }
        set { profileStore.update { $0.pushupLevel = newValue } }
    }
    public var pullupLevel: PullupLevel {
        get { profile.pullupLevel }
        set { profileStore.update { $0.pullupLevel = newValue } }
    }
    public var plankLevel: PlankLevel {
        get { profile.plankLevel }
        set { profileStore.update { $0.plankLevel = newValue } }
    }
    /// Ein Ortswechsel räumt das Equipment gleich mit auf — eine Multipresse
    /// im Park wäre sonst stehen geblieben.
    public var trainingLocation: TrainingLocation {
        get { profile.trainingLocation }
        set {
            profileStore.update {
                $0.trainingLocation = newValue
                $0.normalizeEquipmentForLocation()
            }
        }
    }
    public var startWeightKg: Double? {
        get { profile.startWeightKg }
        set { profileStore.update { $0.startWeightKg = newValue } }
    }
    public var goalWeightKg: Double? {
        get { profile.goalWeightKg }
        set { profileStore.update { $0.goalWeightKg = newValue } }
    }
    public var method: TrainingMethod {
        get { profile.method }
        set { profileStore.update { $0.method = newValue } }
    }
    public var selectedDays: Set<String> {
        get { profile.selectedDays }
        set { profileStore.update { $0.selectedDays = newValue } }
    }
    public var durationMinutes: Int {
        get { profile.durationMinutes }
        set { profileStore.update { $0.durationMinutes = newValue } }
    }
    public var restSeconds: Int {
        get { profile.restSeconds }
        set { profileStore.update { $0.restSeconds = newValue } }
    }
    public var weeks: Int {
        get { profile.weeks }
        set { profileStore.update { $0.weeks = newValue } }
    }
    public var selectedEquipment: Set<EquipmentType> {
        get { profile.equipment }
        set { profileStore.update { $0.equipment = newValue } }
    }
    public var diet: DietType {
        get { profile.diet }
        set { profileStore.update { $0.diet = newValue } }
    }
    public var warmup: String {
        get { profile.warmup }
        set { profileStore.update { $0.warmup = newValue } }
    }

    public static func allowedEquipment(for location: TrainingLocation) -> Set<EquipmentType> {
        UserProfile.allowedEquipment(for: location)
    }

    public func normalizeEquipmentForLocation() {
        profileStore.update { $0.normalizeEquipmentForLocation() }
    }

    // MARK: - Ablauf

    /// Von vorn anfangen — nach „Neuen Plan erstellen“. Die Antworten bleiben
    /// absichtlich stehen: die ändern sich nicht zwischen zwei Plänen, und
    /// sie liegen ohnehin im Profil.
    public func reset() {
        loading = true
        generatedPlan = nil
        lastInput = nil
        errorMessage = nil
        planTab = "workout"
        viewingCycle = 1
        loading = false
        save()
    }

    /*
      Für die Kontolöschung. Die Körperdaten liegen im Profil und werden dort
      gelöscht (UserProfileStore.wipe()); hier geht der Plan weg, der sie
      ebenfalls in sich trägt.
    */
    public func wipe() {
        loading = true
        generatedPlan = nil
        lastInput = nil
        errorMessage = nil
        planTab = "workout"
        viewingCycle = 1
        loading = false
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    /*
      Einen frisch erzeugten Plan übernehmen. Speichern ist eine Entscheidung
      des Nutzers in AIPlanView; hier wird nur der Zustand gesetzt.
    */
    public func apply(plan: TrainingPlan, input: AICoachInput, language: String) {
        loading = true
        lastInput = input
        var stamped = plan
        if stamped.language == nil { stamped.language = language }
        generatedPlan = stamped
        planTab = "workout"
        viewingCycle = 1
        loading = false
        save()
    }

    /// Passt die Beschriftung eines vorhandenen Plans an die neue Sprache an,
    /// ohne die Übungsauswahl neu zu würfeln.
    public func relocalizeIfNeeded(to language: String) {
        guard let plan = generatedPlan,
              plan.language != language,
              let input = lastInput
        else { return }
        generatedPlan = AICoachService.shared.relocalize(plan, input: input, language: language)
    }

    // MARK: - Speichern

    /*
      Nur noch Plan und Eingaben. Die Antwortfelder stehen weiterhin im alten
      Stand unter demselben Schlüssel — der Decoder überliest sie, und
      UserProfileStore holt sie sich einmalig von dort ab, damit niemand nach
      dem Update alles neu eintippen muss.
    */
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
