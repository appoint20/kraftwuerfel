import XCTest
@testable import Kraftwuerfel

/*
  Pläne bearbeiten und bewerten.

  Zwei Dinge, die die Tests festhalten sollen:

  1. Ein Eingriff trifft genau das, was gemeint war. „Montag neu mischen“ darf
     Mittwoch und Freitag nicht anfassen — das war der Grund, warum es die
     Funktion überhaupt gibt.
  2. Die Bewertung ist deterministisch. Bei gleichem Plan kommt derselbe Wert
     heraus, sonst wäre eine Note, die bei jedem Blick anders ausfällt,
     schlimmer als keine.
*/
final class PlanEditingTests2: XCTestCase {

    // MARK: - Hilfsaufbau

    private func exercise(_ name: String) -> Exercise {
        ExerciseDatabase.all.first { $0.name == name }
            ?? ExerciseDatabase.all[0]
    }

    private func makeDay(_ weekday: String, names: [String], sets: Int = 3) -> DayPlan {
        DayPlan(
            weekday: weekday,
            name: "Tag\(weekday)",
            focus: "",
            slots: names.map { ExerciseSlot(exercise: exercise($0), sets: sets, reps: "8-12", restSeconds: 60) }
        )
    }

    private func makePlan(days: [DayPlan]) -> TrainingPlan {
        TrainingPlan(
            title: "Test", summary: "", weeks: 2,
            days: days, nutrition: nil, notes: [], language: "de"
        )
    }

    // MARK: - Einzelnen Tag neu mischen

    func testNeuMischenTrifftNurDenGemeintenTag() {
        var plan = makePlan(days: [
            makeDay("Mo", names: ["Bankdrücken", "Liegestütze", "Butterfly"]),
            makeDay("Mi", names: ["Klimmzüge", "Latzug breit", "Kabelrudern sitzend"]),
            makeDay("Fr", names: ["Kniebeugen", "Beinpresse", "Beinstrecker"]),
        ])

        let mittwochVorher = plan.days[1].cycle1Slots.map(\.exercise.name)
        let freitagVorher = plan.days[2].cycle1Slots.map(\.exercise.name)

        let ok = plan.reshuffleDay(dayID: plan.days[0].id, cycle: 1)

        XCTAssertTrue(ok)
        XCTAssertEqual(plan.days[1].cycle1Slots.map(\.exercise.name), mittwochVorher)
        XCTAssertEqual(plan.days[2].cycle1Slots.map(\.exercise.name), freitagVorher)
    }

    func testNeuMischenBehaeltAnzahlUndSatzschema() {
        var plan = makePlan(days: [makeDay("Mo", names: ["Bankdrücken", "Butterfly", "Liegestütze"], sets: 4)])
        plan.days[0].cycle1Slots[0].reps = "5"
        plan.days[0].cycle1Slots[0].restSeconds = 90

        let anzahlVorher = plan.days[0].cycle1Slots.count

        XCTAssertTrue(plan.reshuffleDay(dayID: plan.days[0].id, cycle: 1))

        XCTAssertEqual(plan.days[0].cycle1Slots.count, anzahlVorher)
        XCTAssertEqual(plan.days[0].cycle1Slots[0].sets, 4)
        XCTAssertEqual(plan.days[0].cycle1Slots[0].reps, "5")
        XCTAssertEqual(plan.days[0].cycle1Slots[0].restSeconds, 90)
    }

    /*
      Ein Brust-Tag muss ein Brust-Tag bleiben. Gemischt wird innerhalb der
      Muskelgruppen, die der Tag ohnehin trifft — sonst wäre es kein Mischen,
      sondern ein neuer Plan.
    */
    func testNeuMischenBleibtInDenMuskelgruppenDesTages() {
        var plan = makePlan(days: [makeDay("Mo", names: ["Bankdrücken", "Butterfly", "Liegestütze"])])
        let erlaubt = Set(plan.days[0].categories(forCycle: 1))

        XCTAssertTrue(plan.reshuffleDay(dayID: plan.days[0].id, cycle: 1))

        for slot in plan.days[0].cycle1Slots {
            XCTAssertFalse(
                erlaubt.isDisjoint(with: Set(slot.exercise.categories)),
                "\(slot.exercise.name) gehört nicht zu den Muskelgruppen des Tages"
            )
        }
    }

    func testNeuMischenAufUnbekanntenTagAendertNichts() {
        var plan = makePlan(days: [makeDay("Mo", names: ["Bankdrücken"])])
        let vorher = plan.days[0].cycle1Slots.map(\.exercise.name)

        XCTAssertFalse(plan.reshuffleDay(dayID: UUID(), cycle: 1))
        XCTAssertEqual(plan.days[0].cycle1Slots.map(\.exercise.name), vorher)
    }

    // MARK: - Einzelne Übung tauschen

    func testTauschenBehaeltSaetzeUndWiederholungen() {
        var plan = makePlan(days: [makeDay("Mo", names: ["Bankdrücken", "Butterfly"], sets: 5)])
        plan.days[0].cycle1Slots[0].reps = "6-8"
        let slotID = plan.days[0].cycle1Slots[0].id
        let neu = exercise("Klimmzüge")

        XCTAssertTrue(plan.replaceSlot(dayID: plan.days[0].id, cycle: 1, slotID: slotID, with: neu))

        let getauscht = plan.days[0].cycle1Slots[0]
        XCTAssertEqual(getauscht.exercise.name, "Klimmzüge")
        XCTAssertEqual(getauscht.sets, 5)
        XCTAssertEqual(getauscht.reps, "6-8")
        XCTAssertEqual(plan.days[0].cycle1Slots.count, 2, "die andere Übung bleibt stehen")
    }

    func testWuerfelnErgibtEineAndereUebung() {
        var plan = makePlan(days: [makeDay("Mo", names: ["Bankdrücken", "Butterfly", "Liegestütze"])])
        let slotID = plan.days[0].cycle1Slots[0].id
        let vorher = plan.days[0].cycle1Slots[0].exercise.name

        XCTAssertTrue(plan.rerollSlot(dayID: plan.days[0].id, cycle: 1, slotID: slotID))
        XCTAssertNotEqual(plan.days[0].cycle1Slots[0].exercise.name, vorher)
    }

    func testEntfernenLaesstDenLetztenEintragStehen() {
        var plan = makePlan(days: [makeDay("Mo", names: ["Bankdrücken", "Butterfly"])])

        XCTAssertTrue(plan.removeSlot(dayID: plan.days[0].id, cycle: 1, slotID: plan.days[0].cycle1Slots[0].id))
        XCTAssertEqual(plan.days[0].cycle1Slots.count, 1)

        // Der letzte darf nicht weg — ein Trainingstag ohne Übung wäre keiner.
        XCTAssertFalse(plan.removeSlot(dayID: plan.days[0].id, cycle: 1, slotID: plan.days[0].cycle1Slots[0].id))
        XCTAssertEqual(plan.days[0].cycle1Slots.count, 1)
    }

    func testHinzufuegenHaengtAn() {
        var plan = makePlan(days: [makeDay("Mo", names: ["Bankdrücken"])])

        XCTAssertTrue(plan.addSlot(dayID: plan.days[0].id, cycle: 1, exercise: exercise("Klimmzüge")))
        XCTAssertEqual(plan.days[0].cycle1Slots.count, 2)
        XCTAssertEqual(plan.days[0].cycle1Slots.last?.exercise.name, "Klimmzüge")
    }

    func testVerschiebenAendertDieReihenfolge() {
        var plan = makePlan(days: [makeDay("Mo", names: ["Bankdrücken", "Butterfly", "Liegestütze"])])

        XCTAssertTrue(plan.moveSlot(dayID: plan.days[0].id, cycle: 1, from: 0, to: 2))
        XCTAssertEqual(plan.days[0].cycle1Slots.map(\.exercise.name), ["Butterfly", "Liegestütze", "Bankdrücken"])
    }

    // MARK: - Zweiter Zyklus

    func testZweiterZyklusLaesstSichEinschalten() {
        var plan = makePlan(days: [makeDay("Mo", names: ["Bankdrücken", "Butterfly", "Liegestütze"])])
        XCTAssertFalse(plan.canOfferTwoCycles, "frisch gebaut sind beide Zyklen gleich")

        plan.setTwoCycles(true)

        XCTAssertTrue(plan.hasTwoCycles)
        XCTAssertNotEqual(
            plan.days[0].cycle1Slots.map(\.exercise.name),
            plan.days[0].cycle2Slots.map(\.exercise.name)
        )
    }

    /*
      Ausschalten darf den zweiten Zyklus nicht wegwerfen. Wer es sich anders
      überlegt, soll seinen alten zweiten Zyklus zurückbekommen und keinen neu
      gewürfelten.
    */
    func testAusschaltenBehaeltDenZweitenZyklus() {
        var plan = makePlan(days: [makeDay("Mo", names: ["Bankdrücken", "Butterfly", "Liegestütze"])])
        plan.setTwoCycles(true)
        let zweiterVorher = plan.days[0].cycle2Slots.map(\.exercise.name)

        plan.setTwoCycles(false)
        XCTAssertFalse(plan.hasTwoCycles, "der Nutzer sieht nur noch einen Zyklus")

        plan.setTwoCycles(true)
        XCTAssertEqual(plan.days[0].cycle2Slots.map(\.exercise.name), zweiterVorher)
    }

    func testOhneSchalterVerhaeltSichEinAlterPlanWieBisher() {
        var plan = makePlan(days: [makeDay("Mo", names: ["Bankdrücken", "Butterfly"])])
        plan.days[0].cycle2Slots = [ExerciseSlot(exercise: exercise("Klimmzüge"), sets: 3, reps: "8")]

        XCTAssertNil(plan.twoCyclesEnabled)
        XCTAssertTrue(plan.hasTwoCycles, "ohne Angabe gilt weiter die alte Ableitung")
    }
}

// MARK: - Bewertung

final class PlanQualityScoreTests: XCTestCase {

    private func exercise(_ name: String) -> Exercise {
        ExerciseDatabase.all.first { $0.name == name } ?? ExerciseDatabase.all[0]
    }

    private func day(_ weekday: String, _ names: [String], sets: Int = 3, reps: String = "8-12", rest: Int = 60) -> DayPlan {
        DayPlan(
            weekday: weekday, name: "T", focus: "",
            slots: names.map { ExerciseSlot(exercise: exercise($0), sets: sets, reps: reps, restSeconds: rest) }
        )
    }

    private func plan(_ days: [DayPlan]) -> TrainingPlan {
        TrainingPlan(title: "T", summary: "", weeks: 2, days: days, nutrition: nil, notes: [], language: "de")
    }

    func testGleicherPlanErgibtGleicheNote() {
        let p = plan([day("Mo", ["Bankdrücken", "Klimmzüge", "Kniebeugen"])])
        let a = PlanQualityScore.evaluate(plan: p, goal: .muscle)
        let b = PlanQualityScore.evaluate(plan: p, goal: .muscle)

        XCTAssertEqual(a.overall, b.overall)
        XCTAssertEqual(a.dimensions.map(\.score), b.dimensions.map(\.score))
    }

    func testLeererPlanErgibtNull() {
        let score = PlanQualityScore.evaluate(plan: plan([]))
        XCTAssertEqual(score.overall, 0)
        XCTAssertTrue(score.dimensions.isEmpty)
    }

    func testNoteBleibtImBereichNullBisHundert() {
        for sets in [1, 3, 6, 10] {
            let score = PlanQualityScore.evaluate(
                plan: plan([
                    day("Mo", ["Bankdrücken", "Butterfly", "Liegestütze"], sets: sets),
                    day("Di", ["Klimmzüge", "Latzug breit"], sets: sets),
                ])
            )
            XCTAssertTrue((0...100).contains(score.overall), "Note \(score.overall) bei \(sets) Sätzen")
            for dimension in score.dimensions {
                XCTAssertTrue((0...100).contains(dimension.score), "\(dimension.id) = \(dimension.score)")
            }
        }
    }

    /*
      Der häufigste Fehler in selbstgebauten Plänen: viel Drücken, kaum
      Ziehen. Das muss die Bewertung sehen.
    */
    func testDrueckLastigerPlanVerliertBeiDerBalance() {
        let pushOnly = plan([day("Mo", ["Bankdrücken", "Schrägbankdrücken", "Butterfly", "Liegestütze"], sets: 4)])
        let ausgewogen = plan([day("Mo", ["Bankdrücken", "Klimmzüge", "Butterfly", "Latzug breit"], sets: 4)])

        let a = PlanQualityScore.evaluate(plan: pushOnly).dimensions.first { $0.id == "balance" }!
        let b = PlanQualityScore.evaluate(plan: ausgewogen).dimensions.first { $0.id == "balance" }!

        XCTAssertLessThan(a.score, b.score)
    }

    func testZuWenigVolumenWirdBenannt() {
        let duenn = plan([day("Mo", ["Bankdrücken"], sets: 1)])
        let score = PlanQualityScore.evaluate(plan: duenn)

        let volumen = score.dimensions.first { $0.id == "volume" }!
        XCTAssertLessThan(volumen.score, 80)
        XCTAssertTrue(
            score.findings.contains { !$0.isPositive },
            "zu wenig Volumen muss als Hinweis auftauchen"
        )
    }

    func testWochensaetzeZaehlenAlleKategorienEinerUebung() {
        // Hip Thrust liegt auf Gesäß, Beine und Rücken.
        let p = plan([day("Mo", ["Hip Thrust"], sets: 4)])
        let sets = PlanQualityScore.weeklySetsPerCategory(days: p.days, cycle: 1)

        XCTAssertEqual(sets[.glutes], 4)
        XCTAssertEqual(sets[.legs], 4)
        XCTAssertEqual(sets[.back], 4)
    }

    func testDauerSchaetzungWaechstMitSaetzenUndPause() {
        let kurz = plan([day("Mo", ["Bankdrücken", "Klimmzüge"], sets: 2, rest: 45)])
        let lang = plan([day("Mo", ["Bankdrücken", "Klimmzüge"], sets: 5, rest: 120)])

        let a = PlanQualityScore.evaluate(plan: kurz).estimatedMinutes
        let b = PlanQualityScore.evaluate(plan: lang).estimatedMinutes

        XCTAssertGreaterThan(b, a)
        XCTAssertGreaterThan(a, 0)
    }

    func testZeitrahmenNurWennEinZielVorliegt() {
        let p = plan([day("Mo", ["Bankdrücken", "Klimmzüge"])])

        let ohne = PlanQualityScore.evaluate(plan: p, goal: .muscle, targetMinutes: nil)
        let mit = PlanQualityScore.evaluate(plan: p, goal: .muscle, targetMinutes: 60)

        XCTAssertNil(ohne.dimensions.first { $0.id == "time" })
        XCTAssertNotNil(mit.dimensions.first { $0.id == "time" })
    }

    func testWiederholungsmitteWirdRichtigGelesen() {
        XCTAssertEqual(PlanQualityScore.midpointReps("8-12"), 10)
        XCTAssertEqual(PlanQualityScore.midpointReps("10"), 10)
        XCTAssertEqual(PlanQualityScore.midpointReps("12 Wdh"), 12)
        // Haltezeiten sind keine Wiederholungen und dürfen den Schnitt nicht verzerren.
        XCTAssertNil(PlanQualityScore.midpointReps("30 Sek"))
        XCTAssertNil(PlanQualityScore.midpointReps("2 min"))
    }

    func testZielausrichtungUnterscheidetKraftVonAbnehmen() {
        let schwer = plan([day("Mo", ["Bankdrücken", "Kniebeugen"], sets: 5, reps: "3-5", rest: 180)])

        let alsKraft = PlanQualityScore.evaluate(plan: schwer, goal: .strength)
            .dimensions.first { $0.id == "goal" }!
        let alsAbnehmen = PlanQualityScore.evaluate(plan: schwer, goal: .weightLoss)
            .dimensions.first { $0.id == "goal" }!

        XCTAssertGreaterThan(alsKraft.score, alsAbnehmen.score)
    }

    /*
      Regeneration wird über echte Wochentagsabstände gemessen, nicht über die
      Reihenfolge im Array: Mo und Mi stehen nebeneinander in der Liste, aber
      nicht im Kalender.
    */
    func testRegenerationZaehltNurEchteFolgetage() {
        let getrennt = plan([
            day("Mo", ["Bankdrücken", "Butterfly", "Liegestütze"]),
            day("Mi", ["Bankdrücken", "Butterfly", "Liegestütze"]),
        ])
        let hintereinander = plan([
            day("Mo", ["Bankdrücken", "Butterfly", "Liegestütze"]),
            day("Di", ["Bankdrücken", "Butterfly", "Liegestütze"]),
        ])

        let a = PlanQualityScore.evaluate(plan: getrennt).dimensions.first { $0.id == "recovery" }!
        let b = PlanQualityScore.evaluate(plan: hintereinander).dimensions.first { $0.id == "recovery" }!

        XCTAssertGreaterThan(a.score, b.score)
    }
}
