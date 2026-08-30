import XCTest
@testable import Kraftwuerfel

/*
  Der laufende Plan lässt sich Tag für Tag anpassen.

  Bis dahin stand er ab dem Start fest: Wer eine Übung nicht machen konnte,
  musste den ganzen Plan beenden und neu würfeln — und verlor dabei seinen
  Fortschritt. Die Zusagen, die dabei nicht brechen dürfen, stehen hier.
*/
final class ActivePlanEditingTests: XCTestCase {

    private let store = ActivePlanStore.shared

    private func startPlan(cycles: Int = 2) {
        let brust = ExerciseDatabase.all.filter { $0.categories.contains(.chest) }.prefix(4)
        let ruecken = ExerciseDatabase.all.filter { $0.categories.contains(.back) }.prefix(4)

        var dayPlans: [String: [[ExerciseSlot]]] = [:]
        var cyclePlans: [[ExerciseSlot]] = []
        cyclePlans.append(brust.map { ExerciseSlot(exercise: $0, sets: 3, reps: "8-12", restSeconds: 60) })
        if cycles > 1 {
            cyclePlans.append(ruecken.map { ExerciseSlot(exercise: $0, sets: 4, reps: "6-10", restSeconds: 90) })
        }
        dayPlans["Mo"] = cyclePlans

        store.start(
            days: ["Mo"], duration: 4, split: "Ganzkörper", method: .standard,
            count: 4, restTime: 60, dayPlans: dayPlans
        )
    }

    override func setUp() {
        super.setUp()
        startPlan()
    }

    override func tearDown() {
        store.end()
        super.tearDown()
    }

    func testEineUebungLaesstSichTauschen() {
        let vorher = store.slots(day: "Mo", cycle: 0)
        XCTAssertFalse(vorher.isEmpty)

        let ersatz = ExerciseDatabase.all.first { neu in
            !vorher.contains { $0.exercise.name == neu.name }
        }
        let ersatzUebung = try! XCTUnwrap(ersatz)

        store.replaceSlot(day: "Mo", cycle: 0, at: 0, with: ersatzUebung)

        let nachher = store.slots(day: "Mo", cycle: 0)
        XCTAssertEqual(nachher[0].exercise.name, ersatzUebung.name)
        XCTAssertEqual(nachher.count, vorher.count, "Tauschen ändert die Anzahl nicht")
        // Die Belastung gehört zum Platz, nicht zur Übung.
        XCTAssertEqual(nachher[0].sets, vorher[0].sets)
        XCTAssertEqual(nachher[0].restSeconds, vorher[0].restSeconds)
    }

    func testNeuWuerfelnBehaeltSatzschemaUndPause() {
        let vorher = store.slots(day: "Mo", cycle: 0)
        store.rerollSlot(day: "Mo", cycle: 0, at: 0, method: .standard)
        let nachher = store.slots(day: "Mo", cycle: 0)

        XCTAssertEqual(nachher.count, vorher.count)
        XCTAssertEqual(nachher[0].sets, vorher[0].sets)
        XCTAssertEqual(nachher[0].reps, vorher[0].reps)
        XCTAssertEqual(nachher[0].restSeconds, vorher[0].restSeconds)
    }

    /*
      Ein Trainingstag ohne eine einzige Übung wäre keiner — die letzte lässt
      sich deshalb nicht entfernen.
    */
    func testDieLetzteUebungBleibtStehen() {
        while store.slots(day: "Mo", cycle: 0).count > 1 {
            store.removeSlot(day: "Mo", cycle: 0, at: 0)
        }
        XCTAssertEqual(store.slots(day: "Mo", cycle: 0).count, 1)

        store.removeSlot(day: "Mo", cycle: 0, at: 0)
        XCTAssertEqual(store.slots(day: "Mo", cycle: 0).count, 1, "die letzte Übung darf nicht verschwinden")
    }

    func testReihenfolgeLaesstSichAendern() {
        let vorher = store.slots(day: "Mo", cycle: 0)
        guard vorher.count >= 2 else { return XCTFail("zu wenige Übungen für den Test") }
        let ersterName = vorher[0].exercise.name

        store.moveSlot(day: "Mo", cycle: 0, from: 0, to: 1)

        let nachher = store.slots(day: "Mo", cycle: 0)
        XCTAssertEqual(nachher[1].exercise.name, ersterName)
        XCTAssertEqual(nachher.count, vorher.count)
    }

    /*
      Gemischt wird der Tag, nicht der Plan: Anzahl und Belastung bleiben,
      und der andere Zyklus bleibt unberührt.
    */
    func testTagMischenLaesstDenAnderenZyklusInRuhe() {
        let vorherZyklus1 = store.slots(day: "Mo", cycle: 0)
        let vorherZyklus2 = store.slots(day: "Mo", cycle: 1)

        store.reshuffleDay(day: "Mo", cycle: 0)

        let nachherZyklus1 = store.slots(day: "Mo", cycle: 0)
        let nachherZyklus2 = store.slots(day: "Mo", cycle: 1)

        XCTAssertEqual(nachherZyklus1.count, vorherZyklus1.count)
        XCTAssertEqual(nachherZyklus1[0].sets, vorherZyklus1[0].sets)
        XCTAssertEqual(
            nachherZyklus2.map(\.exercise.name),
            vorherZyklus2.map(\.exercise.name),
            "Zyklus 2 darf sich nicht ändern, wenn Zyklus 1 gemischt wird"
        )
    }

    func testSaetzeLassenSichAendernUndBleibenInGrenzen() {
        store.updateSlot(day: "Mo", cycle: 0, at: 0, sets: 5)
        XCTAssertEqual(store.slots(day: "Mo", cycle: 0)[0].sets, 5)

        // Ausreißer werden begrenzt, nicht übernommen.
        store.updateSlot(day: "Mo", cycle: 0, at: 0, sets: 99)
        XCTAssertEqual(store.slots(day: "Mo", cycle: 0)[0].sets, 6)

        store.updateSlot(day: "Mo", cycle: 0, at: 0, sets: 0)
        XCTAssertEqual(store.slots(day: "Mo", cycle: 0)[0].sets, 1)
    }

    /// Änderungen müssen den Neustart überleben — sonst stünde am nächsten
    /// Morgen wieder die Übung da, die man gestern getauscht hat.
    func testAenderungenWerdenGespeichert() {
        store.updateSlot(day: "Mo", cycle: 0, at: 0, sets: 5)

        let data = UserDefaults.standard.data(forKey: "kraftwuerfel:activePlan")
        let gespeichert = try? JSONDecoder().decode(ActivePlan.self, from: XCTUnwrap(data))
        XCTAssertEqual(gespeichert?.dayPlans["Mo"]?[0][0].sets, 5)
    }
}

/*
  Die Zyklus-Wahl. „Automatisch" bleibt das bisherige Verhalten — die beiden
  anderen sind die Antwort auf Wünsche, die vorher nicht ausdrückbar waren.
*/
final class CycleModeTests: XCTestCase {

    func testAutomatischRechnetWieBisher() {
        for wochen in [1, 2, 4, 8, 12] {
            XCTAssertEqual(
                CycleMode.auto.cycles(forDuration: wochen),
                PlanGenerator.cyclesForDuration(wochen),
                "Automatisch darf sich gegenüber vorher nicht ändern"
            )
        }
    }

    func testEinZyklusBleibtEinerUnabhaengigVonDerPlanlaenge() {
        for wochen in [1, 4, 12] {
            XCTAssertEqual(CycleMode.single.cycles(forDuration: wochen), 1)
        }
    }

    func testZweiZyklenBleibenZweiUnabhaengigVonDerPlanlaenge() {
        for wochen in [1, 4, 12] {
            XCTAssertEqual(CycleMode.dual.cycles(forDuration: wochen), 2)
        }
    }
}

/*
  Jeden Plan aktiv setzen können — nicht nur einen frisch gewürfelten.

  Vorher führte genau ein Weg zum laufenden Plan: im Trainingsplan-Tab
  würfeln und starten. Ein KI-Plan oder ein selbst gebauter ließ sich zwar
  ansehen und als Live-Session starten, aber nie über Wochen verfolgen.
*/
final class ActivatePlanTests: XCTestCase {

    private let store = ActivePlanStore.shared

    override func tearDown() {
        store.end()
        super.tearDown()
    }

    private func trainingPlan(days: [String], withSecondCycle: Bool) -> TrainingPlan {
        let brust = Array(ExerciseDatabase.all.filter { $0.categories.contains(.chest) }.prefix(5))
        let ruecken = Array(ExerciseDatabase.all.filter { $0.categories.contains(.back) }.prefix(5))

        let dayPlans = days.map { weekday in
            DayPlan(
                weekday: weekday,
                name: "Titan",
                focus: "Brust",
                warmup: [],
                cycle1Slots: brust.map { ExerciseSlot(exercise: $0, sets: 3, reps: "8-12", restSeconds: 75) },
                cycle2Slots: withSecondCycle
                    ? ruecken.map { ExerciseSlot(exercise: $0, sets: 4, reps: "6-10", restSeconds: 90) }
                    : []
            )
        }

        return TrainingPlan(title: "KI Plan", summary: "", weeks: 6, days: dayPlans, nutrition: nil, notes: [])
    }

    func testKIPlanWirdZumLaufendenPlan() {
        store.activate(trainingPlan: trainingPlan(days: ["Mo", "Do"], withSecondCycle: true), title: "Mein KI-Plan")

        let laufend = try! XCTUnwrap(store.plan)
        XCTAssertEqual(laufend.days, ["Mo", "Do"])
        XCTAssertEqual(laufend.duration, 6, "die Planlänge kommt aus dem Plan")
        XCTAssertEqual(laufend.title, "Mein KI-Plan")
        XCTAssertEqual(laufend.dayPlans["Mo"]?.count, 2, "beide Zyklen kommen mit")
        XCTAssertEqual(laufend.restTime, 75)
    }

    /// Ein leerer zweiter Zyklus wäre ein Reiter, hinter dem nichts steht.
    func testOhneZweitenZyklusEntstehtKeinLeererReiter() {
        store.activate(trainingPlan: trainingPlan(days: ["Mo"], withSecondCycle: false))

        let laufend = try! XCTUnwrap(store.plan)
        XCTAssertEqual(laufend.dayPlans["Mo"]?.count, 1)
    }

    /*
      Ein gespeichertes oder selbst gebautes Workout ist EINE Einheit. Damit
      daraus ein verfolgbarer Plan wird, läuft dieselbe Einheit an den
      gewählten Tagen.
    */
    func testEigenesWorkoutLaeuftAnAllenGewaehltenTagen() {
        let slots = ExerciseDatabase.all.prefix(6).map {
            ExerciseSlot(exercise: $0, sets: 3, reps: "10", restSeconds: 60)
        }

        store.activate(slots: Array(slots), name: "Mein Workout", days: ["Di", "Fr", "So"], durationWeeks: 8)

        let laufend = try! XCTUnwrap(store.plan)
        XCTAssertEqual(laufend.days, ["Di", "Fr", "So"])
        XCTAssertEqual(laufend.duration, 8)
        XCTAssertEqual(laufend.title, "Mein Workout")
        for tag in ["Di", "Fr", "So"] {
            XCTAssertEqual(laufend.dayPlans[tag]?.first?.count, 6, "\(tag) trägt dieselbe Einheit")
        }
    }

    func testOhneTageFaelltEsAufDieStandardtageZurueck() {
        let slots = ExerciseDatabase.all.prefix(4).map {
            ExerciseSlot(exercise: $0, sets: 3, reps: "10", restSeconds: 60)
        }
        store.activate(slots: Array(slots), name: "X", days: [])

        XCTAssertEqual(store.plan?.days, ["Mo", "Mi", "Fr"])
    }

    /// Ohne Übungen entsteht kein Plan — sonst stünde im Trainingsplan eine
    /// leere Woche, die sich nicht abhaken lässt.
    func testEinLeeresWorkoutWirdNichtAktiv() {
        store.activate(slots: [], name: "Leer", days: ["Mo"])
        XCTAssertNil(store.plan)
    }

    /// Für die Bewertung im Trainingsplan.
    func testLaufenderPlanLaesstSichBewerten() {
        store.activate(trainingPlan: trainingPlan(days: ["Mo", "Do"], withSecondCycle: true))

        let laufend = try! XCTUnwrap(store.plan)
        let alsPlan = laufend.asTrainingPlan()

        XCTAssertEqual(alsPlan.days.count, 2)
        XCTAssertEqual(alsPlan.weeks, 6)
        XCTAssertFalse(alsPlan.days[0].cycle2Slots.isEmpty)

        let score = PlanQualityScore.evaluate(plan: alsPlan, goal: .muscle, targetMinutes: 60)
        XCTAssertGreaterThan(score.overall, 0, "ein laufender Plan muss bewertbar sein")
    }
}

/*
  Eine 10-Minuten-Einheit muss in 10 Minuten zu schaffen sein. Die Spanne
  hier muss zu der des Servers passen (PlanValidator.ExerciseCountFor) —
  sonst kürzt der Server und diese Seite füllt wieder auf.
*/
final class ChallengeExerciseRangeTests: XCTestCase {

    func testKurzeEinheitenBekommenWenigeUebungen() {
        XCTAssertEqual(PlanMapper.challengeExerciseRange(forMinutes: 10), 3...3)
        XCTAssertEqual(PlanMapper.challengeExerciseRange(forMinutes: 15), 4...5)
        XCTAssertEqual(PlanMapper.challengeExerciseRange(forMinutes: 20), 5...6)
    }

    func testDieSpanneWaechstMitDerDauer() {
        let kurz = PlanMapper.challengeExerciseRange(forMinutes: 10)
        let mittel = PlanMapper.challengeExerciseRange(forMinutes: 30)
        let lang = PlanMapper.challengeExerciseRange(forMinutes: 60)

        XCTAssertLessThan(kurz.upperBound, mittel.upperBound)
        XCTAssertLessThanOrEqual(mittel.upperBound, lang.upperBound)
    }

    /// Grobe Zeitrechnung: 3 Sätze à 30 s Arbeit plus 45 s Pause je Übung.
    func testDieObergrenzePasstInDieAngekuendigteZeit() {
        for minuten in [10, 15, 20, 30, 45, 60] {
            let range = PlanMapper.challengeExerciseRange(forMinutes: minuten)
            let minutenProUebung = 3.0 * (30 + 45) / 60.0
            let schlimmsterFall = Double(range.upperBound) * minutenProUebung
            XCTAssertLessThanOrEqual(
                schlimmsterFall, Double(minuten) * 1.35,
                "\(range.upperBound) Übungen sind rund \(Int(schlimmsterFall)) Minuten, angekündigt waren \(minuten)"
            )
        }
    }
}

/*
  Überspringen heißt später, nicht weg.

  Vorher sprang der Zeiger eine Übung weiter und die übersprungene war für
  die Sitzung verloren. Im Studio ist „die Bank ist besetzt, ich komme
  gleich zurück" aber der Normalfall.
*/
final class LiveQueueTests: XCTestCase {

    func testUebersprungeneUebungWandertAnsEndeUndDerRestRueckAuf() {
        let order = [0, 1, 2, 3]
        let nachher = LiveQueue.deferring(order, at: 1)

        XCTAssertEqual(nachher, [0, 2, 3, 1], "die 1 wartet am Ende")
        XCTAssertEqual(nachher[1], 2, "an der Stelle steht jetzt die nächste Übung")
    }

    func testDerZeigerBleibtStehenAlsoKommtDieNaechsteUebungDran() {
        var order = [0, 1, 2]
        let position = 0
        order = LiveQueue.deferring(order, at: position)

        // Derselbe Zeiger, andere Übung — genau das ist der Sinn.
        XCTAssertEqual(order[position], 1)
        XCTAssertEqual(order.last, 0)
    }

    /*
      Die letzte offene Übung lässt sich nicht wegschieben: Sie stünde sofort
      wieder an derselben Stelle, und der Knopf täte sichtbar nichts.
    */
    func testDieLetzteOffeneUebungLaesstSichNichtWegschieben() {
        XCTAssertFalse(LiveQueue.canDefer([0, 1, 2], at: 2))
        XCTAssertEqual(LiveQueue.deferring([0, 1, 2], at: 2), [0, 1, 2])

        XCTAssertFalse(LiveQueue.canDefer([5], at: 0), "eine einzige Übung geht auch nicht")
    }

    func testMehrmalsUeberspringenDrehtDieWarteschlangeDurch() {
        var order = [0, 1, 2]
        order = LiveQueue.deferring(order, at: 0)   // [1, 2, 0]
        order = LiveQueue.deferring(order, at: 0)   // [2, 0, 1]

        XCTAssertEqual(order, [2, 0, 1])
        XCTAssertEqual(Set(order), [0, 1, 2], "es geht keine Übung verloren")
    }

    /// Wer eine angefangene Übung wegschiebt, macht später dort weiter, wo er
    /// aufgehört hat — nicht wieder bei Satz 1.
    func testEineAngefangeneUebungMachtBeimOffenenSatzWeiter() {
        let erledigt: Set<Int> = [0, 1]
        let offen = LiveQueue.firstOpenSet(totalSets: 4) { erledigt.contains($0) }
        XCTAssertEqual(offen, 2)
    }

    func testEineUnberuehrteUebungFaengtVorneAn() {
        XCTAssertEqual(LiveQueue.firstOpenSet(totalSets: 3) { _ in false }, 0)
    }

    func testEineVollstaendigErledigteUebungFaengtWiederVorneAn() {
        // Sie steht nur dann noch in der Schlange, wenn man sie erneut machen will.
        XCTAssertEqual(LiveQueue.firstOpenSet(totalSets: 3) { _ in true }, 0)
    }

    /*
      Was noch aussteht, folgt der Warteschlange. Vorher hieß es „alle Plätze
      nach dem aktuellen" — eine weggeschobene Übung wäre damit aus der Liste
      verschwunden, obwohl sie noch drankommt.
    */
    func testAlsNaechstesZeigtAuchDieWeggeschobeneUebung() {
        let order = LiveQueue.deferring([0, 1, 2], at: 0)   // [1, 2, 0]
        let rest = LiveQueue.upcoming(order, after: 0)

        XCTAssertEqual(rest, [2, 0])
        XCTAssertTrue(rest.contains(0), "die weggeschobene Übung steht weiter in der Liste")
    }

    func testAmEndeStehtNichtsMehrAus() {
        XCTAssertTrue(LiveQueue.upcoming([0, 1, 2], after: 2).isEmpty)
    }
}
