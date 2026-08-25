import XCTest
@testable import Kraftwuerfel

/*
  Zielgewicht und Trainingsmethode.

  Beide fehlten im Assistenten. Die Methode war dabei der stillere Fehler: Die
  App kennt sechs Satzschemata, der KI-Coach rechnete aber fest mit „Standard“
  — wer 5x4x3 wollte, bekam es im Generator und im KI-Plan nicht.

  Beim Zielgewicht geht es um mehr als eine Zahl im Formular: Es entscheidet
  über die Richtung des Kalorienrahmens und schlägt dabei die Zielkategorie.
*/
final class AICoachInputTests: XCTestCase {

    private func input(
        weight: Double = 80,
        goalWeight: Double? = nil,
        goal: TrainingGoal = .muscle,
        method: TrainingMethod = .standard,
        days: [String] = ["Mo", "Mi", "Fr"]
    ) -> AICoachInput {
        AICoachInput(
            goal: goal,
            experience: .intermediate,
            biometrics: UserBiometrics(sex: "male", age: 30, heightCm: 180, weightKg: weight),
            selectedDays: days,
            sessionDurationMinutes: 60,
            weeks: 4,
            equipment: Set(EquipmentType.allCases),
            diet: .omnivore,
            includeWarmup: true,
            goalWeightKg: goalWeight,
            method: method
        )
    }

    private func calories(_ i: AICoachInput) -> Int {
        AICoachService.shared.generatePlan(input: i, language: "de").nutrition?.dailyCalories ?? 0
    }

    // MARK: - Zielgewicht

    func testAbstandZumZiel() {
        XCTAssertNil(input().weightDelta, "ohne Ziel gibt es keinen Abstand")
        XCTAssertEqual(input(weight: 90, goalWeight: 80).weightDelta, -10)
        XCTAssertEqual(input(weight: 70, goalWeight: 78).weightDelta, 8)
    }

    /// Wer abnehmen will, bekommt ein Defizit — auch wenn als Ziel
    /// „Muskelaufbau“ dasteht. Die konkrete Angabe schlägt die Kategorie.
    func testZielgewichtSchlaegtDieZielkategorie() {
        let ohneZiel = calories(input(weight: 90, goal: .muscle))
        let abnehmen = calories(input(weight: 90, goalWeight: 80, goal: .muscle))

        XCTAssertLessThan(abnehmen, ohneZiel,
                          "Zielgewicht 80 bei 90 kg muss ein Defizit ergeben")
    }

    func testZunehmenErgibtEinenUeberschuss() {
        let ohneZiel = calories(input(weight: 70, goal: .weightLoss))
        let zunehmen = calories(input(weight: 70, goalWeight: 78, goal: .weightLoss))

        XCTAssertGreaterThan(zunehmen, ohneZiel)
    }

    /// Ein Ziel dicht am heutigen Gewicht ist kein Ziel — dann zählt wieder
    /// die Kategorie.
    func testZielNaheAmGewichtVerhaeltSichWieKeinZiel() {
        XCTAssertEqual(
            calories(input(weight: 80, goalWeight: 80.4, goal: .muscle)),
            calories(input(weight: 80, goal: .muscle))
        )
    }

    /// Der Abstand steuert die Größe des Schritts, aber gedeckelt: eine App
    /// ohne ärztliche Begleitung schlägt kein aggressives Defizit vor.
    func testGrosserAbstandGehtNichtUeber500Kilokalorien() {
        let basis = calories(input(weight: 100, goalWeight: 99.9, goal: .fitness))
        let weitWeg = calories(input(weight: 100, goalWeight: 60, goal: .fitness))

        XCTAssertEqual(basis - weitWeg, 500, "höchstens 500 kcal Abstand")
    }

    func testKleinerAbstandErgibtEinenKleinerenSchritt() {
        let basis = calories(input(weight: 80, goalWeight: 79.9, goal: .fitness))
        let nah = calories(input(weight: 80, goalWeight: 77, goal: .fitness))

        XCTAssertEqual(basis - nah, 300)
    }

    /// Untergrenze: Ein Zielgewicht weit unter dem heutigen darf nicht in eine
    /// Empfehlung laufen, die niemand essen sollte.
    func testKalorienFallenNieUnter1200() {
        let extrem = AICoachInput(
            goal: .weightLoss,
            experience: .beginner,
            biometrics: UserBiometrics(sex: "female", age: 60, heightCm: 150, weightKg: 45),
            selectedDays: ["Mo"],
            sessionDurationMinutes: 30,
            weeks: 2,
            equipment: Set(EquipmentType.allCases),
            diet: .vegan,
            goalWeightKg: 38
        )
        XCTAssertGreaterThanOrEqual(calories(extrem), 1200)
    }

    func testZielgewichtStehtInDenHinweisen() throws {
        let plan = AICoachService.shared.generatePlan(
            input: input(weight: 90, goalWeight: 80), language: "de"
        )
        let notes = try XCTUnwrap(plan.nutrition?.notes)
        XCTAssertTrue(notes.contains { $0.contains("80 kg") }, "\(notes)")

        let ohne = AICoachService.shared.generatePlan(input: input(), language: "de")
        let plainNotes = try XCTUnwrap(ohne.nutrition?.notes)
        XCTAssertFalse(plainNotes.contains { $0.contains("kg") })
    }

    // MARK: - Trainingsmethode

    /// 5x4x3 verteilt einen 5er- und einen 4er-Satz je Tag — vorher stand im
    /// KI-Plan überall dieselbe Satzzahl.
    func testFuenfVierDreiKommtImPlanAn() throws {
        for _ in 0..<20 {
            let plan = AICoachService.shared.generatePlan(
                input: input(method: .fiveFourThree), language: "de"
            )
            for day in plan.days {
                XCTAssertEqual(day.cycle1Slots.filter { $0.sets == 5 }.count, 1, day.weekday)
                XCTAssertEqual(day.cycle1Slots.filter { $0.sets == 4 }.count, 1, day.weekday)
            }
        }
    }

    func testVierVierDreiKommtImPlanAn() {
        for _ in 0..<20 {
            let plan = AICoachService.shared.generatePlan(
                input: input(method: .fourFourThree), language: "de"
            )
            for day in plan.days {
                XCTAssertEqual(day.cycle1Slots.filter { $0.sets == 4 }.count, 2, day.weekday)
            }
        }
    }

    /// Bei „Standard“ gilt weiter die Erfahrungsregel.
    func testStandardBehaeltDieErfahrungsregel() {
        var advanced = input(method: .standard)
        advanced.experience = .advanced
        let plan = AICoachService.shared.generatePlan(input: advanced, language: "de")
        XCTAssertTrue(plan.days.allSatisfy { $0.cycle1Slots.allSatisfy { $0.sets == 4 } })

        let beginner = AICoachService.shared.generatePlan(input: input(), language: "de")
        XCTAssertTrue(beginner.days.allSatisfy { $0.cycle1Slots.allSatisfy { $0.sets == 3 } })
    }

    func testFokusMethodeZiehtDieFokusGruppeInDenPlan() {
        for _ in 0..<10 {
            let plan = AICoachService.shared.generatePlan(
                input: input(method: .legsFocus, days: ["Mo"]), language: "de"
            )
            let legs = plan.days[0].cycle1Slots
                .filter { $0.exercise.categories.contains(.legs) }
            XCTAssertGreaterThanOrEqual(legs.count, PlanGenerator.focusMinCount)
        }
    }

    // MARK: - Beides überlebt Speichern und Sprachwechsel

    func testEingabenUeberlebenDenRoundTrip() throws {
        let original = input(weight: 92, goalWeight: 84, method: .fourFourThree)
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(AICoachInput.self, from: data)

        XCTAssertEqual(restored.goalWeightKg, 84)
        XCTAssertEqual(restored.method, .fourFourThree)
        XCTAssertEqual(restored.weightDelta, -8)
    }

    func testSprachwechselBehaeltDasSatzschema() throws {
        let i = input(method: .fiveFourThree)
        let german = AICoachService.shared.generatePlan(input: i, language: "de")
        let english = AICoachService.shared.relocalize(german, input: i, language: "en")

        for (before, after) in zip(german.days, english.days) {
            XCTAssertEqual(after.cycle1Slots.map(\.sets), before.cycle1Slots.map(\.sets))
        }
    }
}
