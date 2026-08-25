import XCTest
@testable import Kraftwuerfel

/*
  Die Zusicherungen aus src/lib/planLogic.test.js, portiert.

  `buildPlan` würfelt. Jede Zusicherung läuft deshalb mehrfach — ein einzelner
  Durchlauf könnte einen Fehler zufällig verfehlen.
*/
final class PlanGeneratorTests: XCTestCase {

    private let runs = 40

    private var fullBody: [MuscleCategory] {
        SplitType.fullBody.categories ?? ExerciseDatabase.categories
    }

    // MARK: - Umfang

    func testLiefertGewuenschteAnzahlOhneDoppelungen() {
        for _ in 0..<runs {
            let plan = PlanGenerator.buildPlan(categories: fullBody, count: 6)
            XCTAssertEqual(plan.count, 6)

            let names = plan.map(\.exercise.name)
            XCTAssertEqual(Set(names).count, names.count, "Übung doppelt im Plan")
        }
    }

    func testOhneKategorienLeererPlan() {
        XCTAssertTrue(PlanGenerator.buildPlan(categories: [], count: 6).isEmpty)
    }

    /// Ist der Pool kleiner als die Wunschzahl, muss die Schleife abbrechen —
    /// nicht hängen. `.core` hat deutlich weniger als 99 Übungen.
    func testBrichtAbWennDerPoolKleinerIstAlsDieWunschzahl() {
        let plan = PlanGenerator.buildPlan(categories: [.core], count: 99)
        XCTAssertFalse(plan.isEmpty)
        XCTAssertLessThan(plan.count, 99)
    }

    // MARK: - Satzschema

    func testStandardBleibtBeiDreiSaetzen() {
        for _ in 0..<runs {
            let plan = PlanGenerator.buildPlan(categories: fullBody, count: 6, method: .standard)
            XCTAssertTrue(plan.allSatisfy { $0.sets == 3 })
        }
    }

    /// 5x4x3 vergibt genau einen 5er- und genau einen 4er-Slot, Rest bleibt 3.
    func testFuenfVierDreiVergibtGenauEinenFuenferUndEinenVierer() {
        for _ in 0..<runs {
            let plan = PlanGenerator.applySetScheme(
                Array(ExerciseDatabase.bundled.prefix(6)),
                method: .fiveFourThree,
                restTime: 60
            )
            XCTAssertEqual(plan.filter { $0.sets == 5 }.count, 1)
            XCTAssertEqual(plan.filter { $0.sets == 4 }.count, 1)
            XCTAssertEqual(plan.filter { $0.sets == 3 }.count, 4)
        }
    }

    func testVierVierDreiVergibtGenauZweiVierer() {
        for _ in 0..<runs {
            let plan = PlanGenerator.applySetScheme(
                Array(ExerciseDatabase.bundled.prefix(6)),
                method: .fourFourThree,
                restTime: 60
            )
            XCTAssertEqual(plan.filter { $0.sets == 4 }.count, 2)
            XCTAssertEqual(plan.filter { $0.sets == 5 }.count, 0)
            XCTAssertEqual(plan.filter { $0.sets == 3 }.count, 4)
        }
    }

    func testPausenzeitLandetInJedemSlot() {
        let plan = PlanGenerator.buildPlan(categories: fullBody, count: 5, restTime: 90)
        XCTAssertTrue(plan.allSatisfy { $0.restSeconds == 90 })
    }

    // MARK: - Fokus-Methoden

    func testFokusErzwingtMindestensDreiUebungenDerFokusKategorie() {
        let cases: [(TrainingMethod, MuscleCategory)] = [
            (.chestFocus, .chest), (.backFocus, .back), (.legsFocus, .legs),
        ]
        for (method, category) in cases {
            for _ in 0..<runs {
                let plan = PlanGenerator.buildPlan(
                    categories: fullBody, count: 6, method: method
                )
                let hits = plan.filter { $0.exercise.categories.contains(category) }.count
                XCTAssertGreaterThanOrEqual(
                    hits, PlanGenerator.focusMinCount,
                    "\(method.rawValue): nur \(hits) Übungen für \(category.rawValue)"
                )
            }
        }
    }

    /// Wer zwei Übungen bei Brust-Fokus verlangt, bekommt drei — sonst passt
    /// der Fokus nicht hinein.
    func testFokusHebtDieUebungszahlAn() {
        for _ in 0..<runs {
            let plan = PlanGenerator.buildPlan(categories: fullBody, count: 2, method: .chestFocus)
            XCTAssertGreaterThanOrEqual(plan.count, PlanGenerator.focusMinCount)
        }
    }

    /// Fokus und 5x4x3 nähmen sich gegenseitig die schweren Übungen weg,
    /// deshalb läuft das Satzschema bei Fokus als "standard".
    func testFokusLaeuftMitStandardSatzschema() {
        for _ in 0..<runs {
            let plan = PlanGenerator.buildPlan(categories: fullBody, count: 6, method: .legsFocus)
            XCTAssertTrue(plan.allSatisfy { $0.sets == 3 })
        }
    }

    // MARK: - Ausschlüsse

    func testRespektiertExtraExclude() {
        for _ in 0..<runs {
            let first = PlanGenerator.buildPlan(categories: fullBody, count: 5)
            let excluded = Set(first.map(\.exercise.name))

            let second = PlanGenerator.buildPlan(
                categories: fullBody, count: 5, extraExclude: excluded
            )
            XCTAssertEqual(second.count, 5)
            for slot in second {
                XCTAssertFalse(
                    excluded.contains(slot.exercise.name),
                    "\(slot.exercise.name) trotz Ausschluss gewählt"
                )
            }
        }
    }

    /// Der Geräte-Filter darf den Plan nicht verkürzen: bleibt zu wenig übrig,
    /// fällt er weg.
    func testGeraeteFilterVerkuerztDenPlanNicht() {
        for _ in 0..<runs {
            let plan = PlanGenerator.buildPlan(
                categories: fullBody, count: 6, equipment: [.kettlebell]
            )
            XCTAssertEqual(plan.count, 6)
        }
    }

    // MARK: - Neu würfeln

    func testRerollTauschtDieUebungUndBehaeltDenSlot() throws {
        for _ in 0..<runs {
            let plan = PlanGenerator.buildPlan(categories: fullBody, count: 5, restTime: 90)
            let original = plan[2]
            let rerolled = try XCTUnwrap(
                PlanGenerator.rerollSlot(plan: plan, at: 2, method: .standard)
            )

            XCTAssertNotEqual(rerolled.exercise.name, original.exercise.name)
            XCTAssertEqual(rerolled.sets, original.sets)
            XCTAssertEqual(rerolled.reps, original.reps)
            XCTAssertEqual(rerolled.restSeconds, original.restSeconds)
        }
    }

    func testRerollAusserhalbDesPlansLiefertNil() {
        let plan = PlanGenerator.buildPlan(categories: fullBody, count: 3)
        XCTAssertNil(PlanGenerator.rerollSlot(plan: plan, at: 99, method: .standard))
    }

    // MARK: - Mehrwochenplan

    func testZyklenAusDerDauer() {
        XCTAssertEqual(PlanGenerator.cyclesForDuration(1), 1)
        XCTAssertEqual(PlanGenerator.cyclesForDuration(2), 1)
        XCTAssertEqual(PlanGenerator.cyclesForDuration(4), 2)
        XCTAssertEqual(PlanGenerator.cyclesForDuration(8), 4)
        XCTAssertEqual(PlanGenerator.cyclesForDuration(12), 6)
        XCTAssertGreaterThanOrEqual(PlanGenerator.cyclesForDuration(0), 1)
    }

    /// Zyklus 1 und Zyklus 2 desselben Tages sollen sich nicht überschneiden —
    /// das ist der ganze Sinn der Alternierung.
    func testZyklenEinesTagesUeberschneidenSichNicht() {
        for _ in 0..<10 {
            let plans = PlanGenerator.buildDayPlans(
                days: ["Mo", "Mi", "Fr"],
                cycles: 2,
                categories: fullBody,
                count: 6,
                method: .standard,
                restTime: 60
            )
            XCTAssertEqual(plans.count, 3)

            for (day, cycles) in plans {
                XCTAssertEqual(cycles.count, 2, "\(day): falsche Zyklenzahl")
                let first = Set(cycles[0].map(\.exercise.name))
                let second = Set(cycles[1].map(\.exercise.name))
                XCTAssertTrue(
                    first.isDisjoint(with: second),
                    "\(day): \(first.intersection(second)) in beiden Zyklen"
                )
            }
        }
    }
}
