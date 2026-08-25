import Foundation
import SwiftUI

/*
  Der Zustand des KI-Assistenten.

  Vorher lag alles als @State in der View. SwiftUI wirft den Zustand weg,
  sobald die View aus der Hierarchie fällt — beim Tabwechsel also. Deshalb
  fing das Formular jedes Mal wieder bei Schritt 1 an.

  Hier liegt derselbe Zustand außerhalb der View und wird zusätzlich
  gespeichert, so wie das Web es mit usePersistentState macht: Wer die App
  schließt und später zurückkommt, steht wieder da, wo er aufgehört hat.
*/
public final class AICoachSession: ObservableObject {
    public static let shared = AICoachSession()

    private static let storageKey = "kraftwuerfel:aiCoachSession"

    // Antworten des Assistenten
    @Published public var currentStep: Int = 1          { didSet { save() } }
    @Published public var goal: TrainingGoal = .muscle  { didSet { save() } }
    @Published public var experience: ExperienceLevel = .intermediate { didSet { save() } }
    @Published public var sex: String = "male"          { didSet { save() } }
    @Published public var age: Int = 28                 { didSet { save() } }
    @Published public var heightCm: Double = 180        { didSet { save() } }
    @Published public var weightKg: Double = 80         { didSet { save() } }
    /// `nil` heißt: kein Zielgewicht gesetzt. Die Ansicht zeigt dann das
    /// aktuelle Gewicht, ohne dass daraus schon ein Ziel wird.
    @Published public var goalWeightKg: Double?         { didSet { save() } }
    @Published public var method: TrainingMethod = .standard { didSet { save() } }
    @Published public var selectedDays: Set<String> = ["Mo", "Mi", "Fr"] { didSet { save() } }
    @Published public var durationMinutes: Int = 60     { didSet { save() } }
    @Published public var weeks: Int = 4                { didSet { save() } }
    @Published public var selectedEquipment: Set<EquipmentType> = [] { didSet { save() } }
    @Published public var diet: DietType = .lactoVegetarian { didSet { save() } }
    @Published public var warmup: String = "auto"       { didSet { save() } }

    /// Der fertige Plan bleibt auch erhalten — sonst wäre er nach einem
    /// Tabwechsel weg, obwohl er Geld gekostet hat.
    @Published public var generatedPlan: TrainingPlan?  { didSet { save() } }

    /// Die Eingaben, aus denen der Plan entstanden ist. Ohne sie ließe er sich
    /// nach einem Sprachwechsel nicht neu beschriften.
    @Published public var lastInput: AICoachInput?      { didSet { save() } }

    // Reine Anzeigezustände: die müssen den Neustart nicht überleben.
    @Published public var planTab: String = "workout"
    @Published public var viewingCycle: Int = 1
    @Published public var isGenerating: Bool = false
    @Published public var errorMessage: String?

    private var loading = false

    private init() { load() }

    /// Von vorn anfangen — nach „Neuen Plan erstellen“.
    public func reset() {
        loading = true
        currentStep = 1
        generatedPlan = nil
        lastInput = nil
        errorMessage = nil
        planTab = "workout"
        viewingCycle = 1
        loading = false
        save()
    }

    /*
      Einen frisch erzeugten Plan übernehmen.

      Vorher setzte der Assistent `generatedPlan` direkt und rief nebenbei
      `onSavePlan?(plan)` auf — einen Rückruf, den MainTabView nie durchreichte.
      Der Plan war damit weder gespeichert noch speicherbar. Speichern ist
      jetzt eine Entscheidung des Nutzers in AIPlanView; hier wird nur der
      Zustand des Assistenten gesetzt.
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

    /// Nach einem Sprachwechsel die Texte des Plans nachziehen — die Übungen
    /// bleiben, wie sie sind.
    public func relocalizeIfNeeded(to language: String) {
        guard let plan = generatedPlan, let input = lastInput,
              plan.language != language
        else { return }
        generatedPlan = AICoachService.shared.relocalize(plan, input: input, language: language)
    }

    // MARK: - Speichern

    private struct Snapshot: Codable {
        var currentStep: Int
        var goal: TrainingGoal
        var experience: ExperienceLevel
        var sex: String
        var age: Int
        var heightCm: Double
        var weightKg: Double
        var goalWeightKg: Double?
        var method: TrainingMethod?
        var selectedDays: [String]
        var durationMinutes: Int
        var weeks: Int
        var selectedEquipment: [EquipmentType]
        var diet: DietType
        var warmup: String
        var generatedPlan: TrainingPlan?
        var lastInput: AICoachInput?
    }

    private func save() {
        guard !loading else { return }
        let snapshot = Snapshot(
            currentStep: currentStep, goal: goal, experience: experience,
            sex: sex, age: age, heightCm: heightCm, weightKg: weightKg,
            goalWeightKg: goalWeightKg, method: method,
            selectedDays: Array(selectedDays), durationMinutes: durationMinutes,
            weeks: weeks, selectedEquipment: Array(selectedEquipment),
            diet: diet, warmup: warmup, generatedPlan: generatedPlan,
            lastInput: lastInput
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let s = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return }

        // Während des Ladens nicht bei jedem Feld zurückschreiben.
        loading = true
        currentStep = s.currentStep
        goal = s.goal
        experience = s.experience
        sex = s.sex
        age = s.age
        heightCm = s.heightCm
        weightKg = s.weightKg
        goalWeightKg = s.goalWeightKg
        // Ältere Stände kennen die Methode noch nicht.
        method = s.method ?? .standard
        selectedDays = Set(s.selectedDays)
        durationMinutes = s.durationMinutes
        weeks = s.weeks
        selectedEquipment = Set(s.selectedEquipment)
        diet = s.diet
        warmup = s.warmup
        generatedPlan = s.generatedPlan
        lastInput = s.lastInput
        loading = false
    }
}
