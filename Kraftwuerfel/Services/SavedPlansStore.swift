import Foundation
import SwiftUI

/*
  Entspricht dem lokalen Modus aus lib/repository.js: ohne Backend leben die
  gespeicherten Pläne im Gerät.

  Die Mechanik (JSON, UserDefaults, ein Schlüssel) liegt jetzt in
  CodableListStore. Wichtig dabei: `save` meldet, ob wirklich geschrieben
  wurde. Vorher endete `persist()` bei einem Kodierfehler in einem stillen
  `return`, und `save` gab trotzdem `true` zurück — die Statuszeile behauptete
  dann „gespeichert als …“, obwohl nichts gespeichert war.
*/
public final class SavedPlansStore: CodableListStore<SavedWorkoutPlan> {
    public static let shared = SavedPlansStore()

    /// Kurzmeldung unter dem Speichern-Feld (.save-status im Web).
    @Published public var status: String?

    private init() { super.init(storageKey: "kraftwuerfel:savedPlans") }

    /// Bisheriger Name der Liste — die Ansichten lesen `plans`.
    public var plans: [SavedWorkoutPlan] { items }

    /// Namen, die schon vergeben sind — Grundlage für `uniquePlanName`.
    public var takenNames: [String] { items.map(\.name) }

    @discardableResult
    public func save(name: String, slots: [ExerciseSlot]) -> Bool {
        guard !slots.isEmpty else { return false }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty
            ? PlanNames.uniquePlanName(taken: takenNames, seed: slots.map(\.exercise.name).joined())
            : trimmed

        guard add(SavedWorkoutPlan(name: finalName, slots: slots)) else {
            status = I18n.shared.t("saved.saveFailed")
            return false
        }
        status = I18n.shared.t("gen.savedAs", ["name": finalName])
        return true
    }

    public func clearStatus() { status = nil }
}
