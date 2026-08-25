import XCTest
@testable import Kraftwuerfel

/*
  Sätze und Wiederholungen direkt im fertigen Plan ändern.

  Die eine Regel, die zählt: Eine Änderung trifft genau eine Übung in genau
  einem Zyklus eines genau bezeichneten Tages. Alles andere bleibt.

  Das ist hier nicht selbstverständlich. Legt man einen `DayPlan` ohne zweiten
  Zyklus an, spiegelt er den ersten — und beide Arrays tragen dann DIESELBEN
  Slot-Kennungen. Wer nur nach der Kennung sucht, verstellt beim Ändern von
  Zyklus 1 stillschweigend auch Zyklus 2.
*/
final class PlanEditingTests: XCTestCase {

    private func slots(_ range: Range<Int>, sets: Int = 3, reps: String = "8-12") -> [ExerciseSlot] {
        ExerciseDatabase.bundled[range].map {
            ExerciseSlot(exercise: $0, sets: sets, reps: reps, restSeconds: 60)
        }
    }

    private func plan() -> TrainingPlan {
        TrainingPlan(
            title: "Test", summary: "", weeks: 4,
            days: [
                DayPlan(weekday: "Mo", name: "Titan", focus: "Push",
                        cycle1Slots: slots(0..<3), cycle2Slots: slots(3..<6, reps: "10-14")),
                DayPlan(weekday: "Mi", name: "Vulkan", focus: "Pull",
                        cycle1Slots: slots(6..<9), cycle2Slots: slots(9..<12)),
            ],
            language: "de"
        )
    }

    // MARK: - Die Kernregel

    func testAendernTrifftNurDenGewaehltenSlot() throws {
        var p = plan()
        let day = try XCTUnwrap(p.days.first)
        let target = try XCTUnwrap(day.cycle1Slots.first)
        let before = p

        p.updateSlot(dayID: day.id, cycle: 1, slotID: target.id, sets: 5, reps: "4-6")

        let after = try XCTUnwrap(p.days.first)
        XCTAssertEqual(after.cycle1Slots[0].sets, 5)
        XCTAssertEqual(after.cycle1Slots[0].reps, "4-6")
        XCTAssertEqual(after.cycle1Slots[0].exercise, target.exercise, "die Übung selbst bleibt")

        // Die übrigen Übungen desselben Tages und Zyklus rühren sich nicht.
        XCTAssertEqual(after.cycle1Slots.dropFirst().map(\.sets),
                       before.days[0].cycle1Slots.dropFirst().map(\.sets))
        XCTAssertEqual(after.cycle1Slots.dropFirst().map(\.reps),
                       before.days[0].cycle1Slots.dropFirst().map(\.reps))

        // Und der zweite Tag erst recht nicht.
        XCTAssertEqual(p.days[1], before.days[1])
    }

    /// Der eigentliche Stolperstein: gespiegelte Zyklen teilen sich die
    /// Kennungen.
    func testAendernInZyklus1LaesstZyklus2InRuhe() throws {
        // Ohne zweiten Zyklus spiegelt DayPlan den ersten — gleiche Slot-IDs.
        var p = TrainingPlan(
            title: "Test", summary: "",
            days: [DayPlan(weekday: "Mo", name: "Titan", focus: "", cycle1Slots: slots(0..<3))]
        )
        let day = try XCTUnwrap(p.days.first)
        XCTAssertEqual(day.cycle1Slots.map(\.id), day.cycle2Slots.map(\.id),
                       "Voraussetzung dieses Tests: die Kennungen sind dieselben")

        let target = try XCTUnwrap(day.cycle1Slots.first)
        p.updateSlot(dayID: day.id, cycle: 1, slotID: target.id, sets: 7)

        XCTAssertEqual(p.days[0].cycle1Slots[0].sets, 7)
        XCTAssertEqual(p.days[0].cycle2Slots[0].sets, 3, "Zyklus 2 wurde mitverstellt")
    }

    func testAendernInZyklus2LaesstZyklus1InRuhe() throws {
        var p = plan()
        let day = try XCTUnwrap(p.days.first)
        let target = try XCTUnwrap(day.cycle2Slots.first)

        p.updateSlot(dayID: day.id, cycle: 2, slotID: target.id, sets: 6)

        XCTAssertEqual(p.days[0].cycle2Slots[0].sets, 6)
        XCTAssertEqual(p.days[0].cycle1Slots[0].sets, 3)
    }

    // MARK: - Grenzen und Unsinn

    func testSaetzeBleibenInEinemSinnvollenBereich() throws {
        var p = plan()
        let day = try XCTUnwrap(p.days.first)
        let target = try XCTUnwrap(day.cycle1Slots.first)

        p.updateSlot(dayID: day.id, cycle: 1, slotID: target.id, sets: 0)
        XCTAssertEqual(p.days[0].cycle1Slots[0].sets, 1, "unter 1 ergibt keinen Satz")

        p.updateSlot(dayID: day.id, cycle: 1, slotID: target.id, sets: 999)
        XCTAssertEqual(p.days[0].cycle1Slots[0].sets, 20)
    }

    /// Ein leeres Feld darf die Wiederholungen nicht löschen — der Nutzer ist
    /// beim Tippen kurzzeitig immer bei "".
    func testLeereWiederholungenWerdenIgnoriert() throws {
        var p = plan()
        let day = try XCTUnwrap(p.days.first)
        let target = try XCTUnwrap(day.cycle1Slots.first)

        p.updateSlot(dayID: day.id, cycle: 1, slotID: target.id, reps: "")
        XCTAssertEqual(p.days[0].cycle1Slots[0].reps, "8-12")

        p.updateSlot(dayID: day.id, cycle: 1, slotID: target.id, reps: "   ")
        XCTAssertEqual(p.days[0].cycle1Slots[0].reps, "8-12")

        p.updateSlot(dayID: day.id, cycle: 1, slotID: target.id, reps: "  6-8 ")
        XCTAssertEqual(p.days[0].cycle1Slots[0].reps, "6-8", "Leerzeichen werden abgeschnitten")
    }

    func testUnbekannteKennungenAendernNichts() throws {
        var p = plan()
        let before = p
        let day = try XCTUnwrap(p.days.first)

        p.updateSlot(dayID: UUID(), cycle: 1, slotID: day.cycle1Slots[0].id, sets: 9)
        p.updateSlot(dayID: day.id, cycle: 1, slotID: UUID(), sets: 9)

        XCTAssertEqual(p.days, before.days)
    }

    /// Nur `sets` mitgeben darf die Wiederholungen nicht anfassen — und
    /// umgekehrt.
    func testTeilaenderungLaesstDasAndereFeldStehen() throws {
        var p = plan()
        let day = try XCTUnwrap(p.days.first)
        let target = try XCTUnwrap(day.cycle1Slots.first)

        p.updateSlot(dayID: day.id, cycle: 1, slotID: target.id, sets: 4)
        XCTAssertEqual(p.days[0].cycle1Slots[0].reps, "8-12")

        p.updateSlot(dayID: day.id, cycle: 1, slotID: target.id, reps: "12-15")
        XCTAssertEqual(p.days[0].cycle1Slots[0].sets, 4)
    }

    // MARK: - Speichern

    /// „Wenn der Benutzer den angepassten Plan speichert, sollen die
    /// angepassten Werte gespeichert werden.“
    func testAngepassteWerteUeberlebenDasSpeichern() throws {
        var p = plan()
        let day = try XCTUnwrap(p.days.first)
        let target = try XCTUnwrap(day.cycle1Slots.first)
        p.updateSlot(dayID: day.id, cycle: 1, slotID: target.id, sets: 4, reps: "8")

        let suite = "kraftwuerfel.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = CodableListStore<SavedAIPlan>(storageKey: "plans", defaults: defaults)
        XCTAssertTrue(store.add(SavedAIPlan(name: "Angepasst", plan: p)))

        let reloaded = CodableListStore<SavedAIPlan>(storageKey: "plans", defaults: defaults)
        let restored = try XCTUnwrap(reloaded.items.first).plan
        XCTAssertEqual(restored.days[0].cycle1Slots[0].sets, 4)
        XCTAssertEqual(restored.days[0].cycle1Slots[0].reps, "8")
        XCTAssertEqual(restored.days[0].cycle1Slots[1].sets, 3, "der Nachbar blieb unberührt")
    }

    /// Ein Sprachwechsel darf die Anpassungen nicht zurücksetzen.
    func testAnpassungenUeberlebenDenSprachwechsel() throws {
        let input = AICoachInput(selectedDays: ["Mo", "Mi"], weeks: 4)
        var german = AICoachService.shared.generatePlan(input: input, language: "de")

        let day = try XCTUnwrap(german.days.first)
        let target = try XCTUnwrap(day.cycle1Slots.first)
        german.updateSlot(dayID: day.id, cycle: 1, slotID: target.id, sets: 5, reps: "3-5")

        let english = AICoachService.shared.relocalize(german, input: input, language: "en")
        XCTAssertEqual(english.days[0].cycle1Slots[0].sets, 5)
        XCTAssertEqual(english.days[0].cycle1Slots[0].reps, "3-5")
    }
}
