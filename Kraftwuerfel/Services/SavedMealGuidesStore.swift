import Foundation

/*
  Gespeicherte Meal Guides.

  Vorher gab es das gar nicht: MealGuideView setzte `showSavedAlert = true` und
  rief danach einen Rückruf auf, den niemand gesetzt hatte. Die Liste in
  SavedPlansView war ein lokales `@State` mit leerem Array, das nie befüllt
  wurde — und weil es `@State` war, wäre es beim Tabwechsel ohnehin weg gewesen.
*/
public final class SavedMealGuidesStore: CodableListStore<SavedMealGuide> {
    public static let shared = SavedMealGuidesStore()

    private init() { super.init(storageKey: "kraftwuerfel:savedMealGuides") }

    /// Speichert und meldet ehrlich, ob es geklappt hat.
    public func save(nutrition: NutritionPlan, name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty
            ? PlanNames.uniquePlanName(taken: items.map(\.name), seed: nutrition.diet.rawValue)
            : trimmed
        return add(SavedMealGuide(name: finalName, nutrition: nutrition))
    }

    /*
      Derselbe Guide soll nicht zweimal in der Liste landen.

      Verglichen wird der Inhalt ohne die Kennungen der einzelnen Mahlzeiten:
      Ein Sprachwechsel baut den Guide neu auf, die Mahlzeiten bekommen dabei
      frische UUIDs — als ganzer Wert wäre er dann jedes Mal „neu“.
    */
    public func contains(_ nutrition: NutritionPlan) -> Bool {
        items.contains { $0.nutrition.isSameGuide(as: nutrition) }
    }
}
