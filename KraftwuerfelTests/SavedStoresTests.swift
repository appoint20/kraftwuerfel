import XCTest
@testable import Kraftwuerfel

/*
  Speichern muss speichern — und Misserfolg muss Misserfolg melden.

  Die gemeldeten Fehler waren beide von dieser Sorte: Der Meal Guide zeigte
  „erfolgreich gesichert“, ohne dass irgendwo etwas lag, und die Liste unter
  GESPEICHERT war ein leeres `@State`, das nie befüllt wurde. Ein Rückgabewert,
  der immer `true` ist, fällt niemandem auf — ein Test dagegen schon.

  Alle Tests laufen auf einer eigenen UserDefaults-Suite, damit sie die Daten
  des Simulators nicht anfassen.
*/
final class SavedStoresTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "kraftwuerfel.tests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Hilfsmittel

    private func slots(_ n: Int) -> [ExerciseSlot] {
        ExerciseDatabase.bundled.prefix(n).map { ExerciseSlot(exercise: $0) }
    }

    private func mealGuide(_ name: String) -> SavedMealGuide {
        SavedMealGuide(
            name: name,
            nutrition: NutritionPlan(
                diet: .vegan, dailyCalories: 2400, protein: 160, carbs: 250, fat: 70,
                meals: [MealItem(time: "08:00", name: "Porridge", calories: 500, items: ["Hafer"])],
                shakes: [ShakeItem(when: "nach dem Training", what: "Erbsenprotein")],
                notes: ["viel trinken"], disclaimer: "Richtwerte"
            )
        )
    }

    private func store<T: Codable & Identifiable>(_ type: T.Type) -> CodableListStore<T>
    where T.ID == UUID {
        CodableListStore<T>(storageKey: "items", defaults: defaults)
    }

    // MARK: - Grundmechanik

    func testHinzufuegenMeldetErfolgUndLegtDenEintragVornAn() {
        let store = self.store(SavedMealGuide.self)
        XCTAssertTrue(store.add(mealGuide("A")))
        XCTAssertTrue(store.add(mealGuide("B")))

        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items.first?.name, "B", "Neues gehört nach oben")
    }

    /// Der Kern des gemeldeten Fehlers: Was gespeichert gemeldet wird, muss ein
    /// frisch geladener Speicher auch wiederfinden.
    func testGespeichertesUeberlebtEinenNeustart() throws {
        let first = store(SavedMealGuide.self)
        XCTAssertTrue(first.add(mealGuide("Vegan 2400")))

        // Zweiter Speicher auf denselben Daten — wie nach einem App-Start.
        let second = store(SavedMealGuide.self)
        XCTAssertEqual(second.items.count, 1)
        XCTAssertEqual(second.items.first?.name, "Vegan 2400")
        XCTAssertEqual(second.items.first?.nutrition.dailyCalories, 2400)
        XCTAssertEqual(second.items.first?.nutrition.meals.first?.name, "Porridge")
    }

    func testLoeschenEntferntDauerhaft() throws {
        let store = self.store(SavedMealGuide.self)
        let entry = mealGuide("A")
        XCTAssertTrue(store.add(entry))
        XCTAssertTrue(store.delete(entry))
        XCTAssertTrue(store.items.isEmpty)

        XCTAssertTrue(self.store(SavedMealGuide.self).items.isEmpty)
    }

    func testLoeschenEinesUnbekanntenEintragsAendertNichts() {
        let store = self.store(SavedMealGuide.self)
        XCTAssertTrue(store.add(mealGuide("A")))
        XCTAssertTrue(store.delete(mealGuide("gibt es nicht")))
        XCTAssertEqual(store.items.count, 1)
    }

    /// Kaputte Daten dürfen die Liste des Nutzers nicht stillschweigend
    /// löschen — sie bleiben liegen und der Fehler wird gemeldet.
    func testUnlesbareDatenWerdenGemeldetUndNichtVerworfen() throws {
        defaults.set(Data("kein JSON".utf8), forKey: "items")

        let store = self.store(SavedMealGuide.self)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNotNil(store.lastError, "der Ladefehler muss sichtbar sein")
        XCTAssertNotNil(defaults.data(forKey: "items"), "die Rohdaten bleiben liegen")
    }

    // MARK: - KI-Pläne

    func testKiPlanUeberlebtMitAllenZyklenUndEingaben() throws {
        let plan = TrainingPlan(
            title: "KI Plan", summary: "kurz", weeks: 4,
            days: [DayPlan(weekday: "Mo", name: "Titan", focus: "Push",
                           cycle1Slots: slots(4), cycle2Slots: slots(3))],
            language: "de"
        )
        let input = AICoachInput(goal: .strength, experience: .advanced, weeks: 4)

        let first = store(SavedAIPlan.self)
        XCTAssertTrue(first.add(SavedAIPlan(name: "KI Plan", plan: plan, input: input)))

        let restored = try XCTUnwrap(store(SavedAIPlan.self).items.first)
        XCTAssertEqual(restored.name, "KI Plan")
        XCTAssertEqual(restored.plan.days.count, 1)
        XCTAssertEqual(restored.plan.days[0].cycle1Slots.count, 4)
        XCTAssertEqual(restored.plan.days[0].cycle2Slots.count, 3)
        XCTAssertEqual(restored.plan.language, "de")
        XCTAssertEqual(restored.input?.goal, .strength)
        XCTAssertEqual(restored.input?.experience, .advanced)
        XCTAssertEqual(restored.exerciseCount, 4)
    }

    /// Ältere Einträge ohne Eingaben müssen weiter lesbar sein.
    func testEintragOhneEingabenBleibtLesbar() throws {
        let plan = TrainingPlan(title: "Alt", summary: "", days: [])
        let store = self.store(SavedAIPlan.self)
        XCTAssertTrue(store.add(SavedAIPlan(name: "Alt", plan: plan, input: nil)))

        let restored = try XCTUnwrap(self.store(SavedAIPlan.self).items.first)
        XCTAssertNil(restored.input)
        XCTAssertEqual(restored.localizedPlan(in: "en").title, "Alt",
                       "ohne Eingaben bleibt der Plan, wie er ist")
    }
}
