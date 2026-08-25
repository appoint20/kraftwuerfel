import Foundation

/*
  Alles, was der Nutzer unter GESPEICHERT wiederfindet.

  Die Typen lagen bisher teils in Ansichtsdateien — `SavedWorkoutPlan` stand
  mitten in SavedPlansView.swift. Ein Modell, das eine View besitzt, findet
  niemand wieder und lässt sich nicht ohne die View testen. Deshalb liegen sie
  jetzt beieinander.

  Alle drei tragen ihr eigenes `id` und `savedAt` und sind `Codable` — sie
  gehen unverändert durch CodableListStore in die UserDefaults.
*/

/// Ein gewürfelter Plan aus dem Generator.
public struct SavedWorkoutPlan: Identifiable, Codable, Hashable {
    public var id = UUID()
    public let name: String
    public let slots: [ExerciseSlot]
    public let savedAt: Date

    public init(id: UUID = UUID(), name: String, slots: [ExerciseSlot], savedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.slots = slots
        self.savedAt = savedAt
    }
}

/// Ein Ernährungsplan aus dem KI-Coach.
public struct SavedMealGuide: Identifiable, Codable, Hashable {
    public var id = UUID()
    public let name: String
    public let nutrition: NutritionPlan
    public let savedAt: Date

    public init(id: UUID = UUID(), name: String, nutrition: NutritionPlan, savedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.nutrition = nutrition
        self.savedAt = savedAt
    }
}

/// Ein kompletter Trainingsplan aus dem KI-Coach.
public struct SavedAIPlan: Identifiable, Codable, Hashable {
    public var id = UUID()
    public let name: String
    public let plan: TrainingPlan
    public let savedAt: Date
    /*
      Die Eingaben, aus denen der Plan entstand. Damit lässt er sich auch Wochen
      später noch in die andere Sprache übertragen — Titel, Fokus und Meal Guide
      stecken sonst für immer in der Sprache vom Tag des Speicherns fest.
    */
    public let input: AICoachInput?

    public init(
        id: UUID = UUID(),
        name: String,
        plan: TrainingPlan,
        input: AICoachInput? = nil,
        savedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.plan = plan
        self.input = input
        self.savedAt = savedAt
    }

    /// Der Plan in der gewünschten Sprache. Fehlen die Eingaben (alter
    /// Eintrag), bleibt er, wie er ist — die Übungsnamen übersetzt die Ansicht
    /// ohnehin beim Zeichnen.
    public func localizedPlan(in language: String) -> TrainingPlan {
        guard let input, plan.language != language else { return plan }
        return AICoachService.shared.relocalize(plan, input: input, language: language)
    }

    /// Summe der Übungen über alle Tage und beide Zyklen — für die Kartenzeile.
    public var exerciseCount: Int {
        plan.days.reduce(0) { $0 + $1.cycle1Slots.count }
    }
}
