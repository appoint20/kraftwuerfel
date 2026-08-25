import Foundation

/*
  Gespeicherte KI-Pläne — die neue Sektion unter GESPEICHERT.

  Der KI-Coach rief bisher `onSavePlan?(plan)` direkt nach dem Erzeugen auf,
  und MainTabView reichte diesen Rückruf gar nicht erst durch. Der Plan war
  damit weder gespeichert noch speicherbar: Ein Tabwechsel warf ihn weg.

  Speichern ist jetzt eine Entscheidung des Nutzers, kein Nebeneffekt des
  Erzeugens — er sieht den Plan erst, prüft ihn und legt ihn dann ab.
*/
public final class SavedAIPlansStore: CodableListStore<SavedAIPlan> {
    public static let shared = SavedAIPlansStore()

    private init() { super.init(storageKey: "kraftwuerfel:savedAIPlans") }

    public func save(plan: TrainingPlan, input: AICoachInput? = nil, name: String = "") -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? fallbackName(for: plan) : trimmed
        return add(SavedAIPlan(name: finalName, plan: plan, input: input))
    }

    /// Ohne eigenen Namen nimmt der Plan seinen Titel — und wenn auch der
    /// fehlt, einen Rufnamen aus der Liste.
    private func fallbackName(for plan: TrainingPlan) -> String {
        let title = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty else { return title }
        return PlanNames.uniquePlanName(
            taken: items.map(\.name),
            seed: plan.days.map(\.weekday).joined()
        )
    }

    /*
      Über die Kennung, nicht über den Inhalt. `relocalize` gibt denselben Plan
      mit anderen Texten zurück — verglichen man den ganzen Wert, hielte die App
      ihn nach einem Sprachwechsel für einen neuen und böte ihn nochmal zum
      Speichern an.
    */
    public func contains(_ plan: TrainingPlan) -> Bool {
        items.contains { $0.plan.id == plan.id }
    }
}
