import XCTest
@testable import Kraftwuerfel

/*
  Was in UserDefaults wandert, muss unverändert zurückkommen.

  Jeder Store (SavedPlansStore, FavoritesStore, ActivePlanStore, AICoachSession)
  baut von Hand dieselbe Kette aus JSONEncoder und einem Schlüssel als
  Zeichenkette. Bricht das Round-Trip, verliert der Nutzer seine Pläne
  wortlos — `try?` beim Laden schluckt den Fehler.
*/
final class SerializationTests: XCTestCase {

    private func slots(_ n: Int) -> [ExerciseSlot] {
        ExerciseDatabase.bundled.prefix(n).map {
            ExerciseSlot(exercise: $0, sets: 4, reps: "6-10", restSeconds: 90, note: "Notiz")
        }
    }

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func testExerciseSlotUeberlebtRoundTrip() throws {
        let original = slots(1)[0]
        let restored = try roundTrip(original)

        XCTAssertEqual(restored.id, original.id, "die Identität muss erhalten bleiben")
        XCTAssertEqual(restored.exercise, original.exercise)
        XCTAssertEqual(restored.sets, 4)
        XCTAssertEqual(restored.reps, "6-10")
        XCTAssertEqual(restored.restSeconds, 90)
        XCTAssertEqual(restored.note, "Notiz")
    }

    func testGespeicherterPlanUeberlebtRoundTrip() throws {
        let original = SavedWorkoutPlan(name: "Titan", slots: slots(5))
        let restored = try roundTrip(original)

        XCTAssertEqual(restored.id, original.id)
        XCTAssertEqual(restored.name, "Titan")
        XCTAssertEqual(restored.slots.count, 5)
        XCTAssertEqual(restored.slots.map(\.exercise.name), original.slots.map(\.exercise.name))
        XCTAssertEqual(
            restored.savedAt.timeIntervalSince1970,
            original.savedAt.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testAktiverPlanUeberlebtRoundTripMitZyklen() throws {
        let original = ActivePlan(
            startDate: Date(),
            duration: 8,
            days: ["Mo", "Mi", "Fr"],
            split: SplitType.women.rawValue,
            method: .legsFocus,
            count: 6,
            restTime: 90,
            dayPlans: ["Mo": [slots(4), slots(3)]]
        )
        let restored = try roundTrip(original)

        XCTAssertEqual(restored.duration, 8)
        XCTAssertEqual(restored.days, ["Mo", "Mi", "Fr"])
        XCTAssertEqual(restored.method, .legsFocus)
        XCTAssertEqual(restored.dayPlans["Mo"]?.count, 2, "beide Zyklen müssen zurückkommen")
        XCTAssertEqual(restored.dayPlans["Mo"]?[0].count, 4)
        XCTAssertEqual(restored.dayPlans["Mo"]?[1].count, 3)
    }

    func testTrainingsplanUeberlebtRoundTrip() throws {
        let day = DayPlan(
            weekday: "Mo",
            name: "Titan",
            focus: "Brust & Trizeps",
            warmup: [WarmupExercise(name: "Rudergerät", duration: "5 min")],
            cycle1Slots: slots(4),
            cycle2Slots: slots(3)
        )
        let original = TrainingPlan(
            title: "Aufbau", summary: "8 Wochen", weeks: 8, days: [day], notes: ["A", "B"]
        )
        let restored = try roundTrip(original)

        XCTAssertEqual(restored.title, "Aufbau")
        XCTAssertEqual(restored.weeks, 8)
        XCTAssertEqual(restored.notes, ["A", "B"])
        XCTAssertEqual(restored.days.count, 1)
        XCTAssertEqual(restored.days[0].warmup.first?.name, "Rudergerät")
        XCTAssertEqual(restored.days[0].cycle1Slots.count, 4)
        XCTAssertEqual(restored.days[0].cycle2Slots.count, 3)
    }

    /// Ohne zweiten Zyklus spiegelt der Tag den ersten — sonst stünde in
    /// Zyklus 2 nichts.
    func testTagOhneZweitenZyklusSpiegeltDenErsten() {
        let day = DayPlan(weekday: "Mo", name: "Titan", focus: "", cycle1Slots: slots(3))
        XCTAssertEqual(day.cycle2Slots.map(\.exercise.name), day.cycle1Slots.map(\.exercise.name))
        XCTAssertEqual(day.slots(forCycle: 2).count, 3)
        XCTAssertEqual(day.slots(forCycle: 1).count, 3)
    }
}

/*
  Die Antwort des Servers in einen TrainingPlan übersetzen
  (entspricht normalizePlan aus dem Web).
*/
final class PlanMapperTests: XCTestCase {

    private var knownExercise: String { ExerciseDatabase.all[0].name }

    private func raw(days: [[String: Any]]) -> [String: Any] {
        ["title": "KI-Plan", "summary": "kurz", "weeks": 6, "days": days, "notes": ["hinweis"]]
    }

    func testUebersetztDieFeldnamenDerEdgeFunction() throws {
        let plan = try XCTUnwrap(PlanMapper.trainingPlan(
            from: raw(days: [[
                "weekday": "Mo",
                "name": "Titan",
                "focus": "Brust",
                "warmup": [["name": "Rudern", "duration": "5 min"]],
                "exercises": [[
                    "name": knownExercise, "sets": 4, "reps": "6-10", "rest": 90, "note": "langsam",
                ]],
            ]]),
            language: "de"
        ))

        XCTAssertEqual(plan.title, "KI-Plan")
        XCTAssertEqual(plan.weeks, 6)
        XCTAssertEqual(plan.notes, ["hinweis"])

        let day = try XCTUnwrap(plan.days.first)
        XCTAssertEqual(day.weekday, "Mo")
        XCTAssertEqual(day.name, "Titan")
        XCTAssertEqual(day.warmup.first?.duration, "5 min")

        let slot = try XCTUnwrap(day.slots.first)
        XCTAssertEqual(slot.exercise.name, knownExercise)
        XCTAssertEqual(slot.sets, 4)
        XCTAssertEqual(slot.reps, "6-10")
        XCTAssertEqual(slot.restSeconds, 90)
        XCTAssertEqual(slot.note, "langsam")
    }

    func testFehlendeFelderBekommenVorgabewerte() throws {
        let plan = try XCTUnwrap(PlanMapper.trainingPlan(
            from: raw(days: [["weekday": "Di", "exercises": [["name": knownExercise]]]]),
            language: "de"
        ))
        let slot = try XCTUnwrap(plan.days.first?.slots.first)
        XCTAssertEqual(slot.sets, 3)
        XCTAssertEqual(slot.reps, PlanGenerator.defaultReps)
        XCTAssertEqual(slot.restSeconds, 60)
    }

    /// Kennt die App eine Übung nicht (ältere Liste), fliegt sie raus — ein
    /// leerer Platzhalter wäre im Training wertlos.
    func testUnbekannteUebungenFliegenRaus() throws {
        let plan = try XCTUnwrap(PlanMapper.trainingPlan(
            from: raw(days: [["weekday": "Mo", "exercises": [
                ["name": knownExercise],
                ["name": "Übung die es nicht gibt"],
            ]]]),
            language: "de"
        ))
        XCTAssertEqual(plan.days.first?.slots.count, 1)
    }

    func testTageOhneUebungenFliegenRaus() throws {
        let plan = try XCTUnwrap(PlanMapper.trainingPlan(
            from: raw(days: [
                ["weekday": "Mo", "exercises": [["name": knownExercise]]],
                ["weekday": "Di", "exercises": []],
                ["weekday": "Mi", "exercises": [["name": "gibt es nicht"]]],
            ]),
            language: "de"
        ))
        XCTAssertEqual(plan.days.map(\.weekday), ["Mo"])
    }

    /// Vergisst das Modell den Rufnamen, springt die lokale Namensliste ein —
    /// die Karte darf nie namenlos bleiben.
    func testOhneNamenSpringtDieNamenslisteEin() throws {
        let plan = try XCTUnwrap(PlanMapper.trainingPlan(
            from: raw(days: [["weekday": "Mo", "name": "", "exercises": [["name": knownExercise]]]]),
            language: "de"
        ))
        let name = try XCTUnwrap(plan.days.first?.name)
        XCTAssertFalse(name.isEmpty)
        XCTAssertTrue(PlanNames.names.contains(name))
    }

    func testLeererPlanLiefertNil() {
        XCTAssertNil(PlanMapper.trainingPlan(from: raw(days: []), language: "de"))
        XCTAssertNil(PlanMapper.trainingPlan(from: [:], language: "de"))
        XCTAssertNil(PlanMapper.trainingPlan(
            from: raw(days: [["weekday": "Mo", "exercises": []]]), language: "de"
        ))
    }
}
