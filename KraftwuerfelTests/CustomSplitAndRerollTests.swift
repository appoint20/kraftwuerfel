import XCTest
@testable import Kraftwuerfel

/*
  Zwei gemeldete Punkte am Studio-Generator.

  1. Der Split „Eigene" ließ nur Muskelgruppen ankreuzen; welche Übungen
     herauskamen, entschied weiter der Zufall. Jetzt wird die Auswahl selbst
     zusammengestellt, begrenzt auf „Anzahl Übungen".

  2. Beim Neuwürfeln einer einzelnen Übung sah es aus, als ändere sich der
     ganze Plan. Die Daten stimmten schon vorher — der Fehler saß in der
     Animation, die alle Karten durchlaufen ließ.
*/
final class CustomSplitTests: XCTestCase {

    private var settings: GeneratorSettings { GeneratorSettings.shared }

    override func setUp() {
        super.setUp()
        settings.customExercises = []
        settings.count = 6
    }

    override func tearDown() {
        settings.customExercises = []
        settings.count = 6
        super.tearDown()
    }

    private func exercise(_ name: String) -> Exercise {
        ExerciseDatabase.all.first { $0.name == name } ?? ExerciseDatabase.all[0]
    }

    // MARK: - Auswählen

    func testUebungenLassenSichFreiAnUndAbwaehlen() {
        let bank = exercise("Bankdrücken")

        XCTAssertTrue(settings.toggleCustomExercise(bank))
        XCTAssertEqual(settings.customExercises.count, 1)
        XCTAssertTrue(settings.customExerciseNames.contains("Bankdrücken"))

        XCTAssertTrue(settings.toggleCustomExercise(bank))
        XCTAssertTrue(settings.customExercises.isEmpty)
    }

    func testDieReihenfolgeDerAuswahlBleibtErhalten() {
        let namen = ["Bankdrücken", "Klimmzüge", "Kniebeugen"]
        namen.forEach { settings.toggleCustomExercise(exercise($0)) }

        XCTAssertEqual(settings.customExercises.map(\.name), namen)
    }

    // MARK: - Obergrenze aus „Anzahl Übungen"

    func testDieObergrenzeIstDieAnzahlUebungen() {
        settings.count = 4
        XCTAssertEqual(settings.customExerciseLimit, 4)

        settings.count = 9
        XCTAssertEqual(settings.customExerciseLimit, 9)
    }

    func testUeberDerObergrenzeLaesstSichNichtsMehrWaehlen() {
        settings.count = 3

        let auswahl = ["Bankdrücken", "Klimmzüge", "Kniebeugen"]
        for name in auswahl {
            XCTAssertTrue(settings.toggleCustomExercise(exercise(name)))
        }
        XCTAssertTrue(settings.isCustomSelectionFull)

        // Die vierte muss abgelehnt werden.
        let abgelehnt = settings.toggleCustomExercise(exercise("Butterfly"))
        XCTAssertFalse(abgelehnt)
        XCTAssertEqual(settings.customExercises.count, 3)
        XCTAssertFalse(settings.customExerciseNames.contains("Butterfly"))
    }

    func testBeiErreichterGrenzeIstAbwaehlenWeiterMoeglich() {
        settings.count = 2
        settings.toggleCustomExercise(exercise("Bankdrücken"))
        settings.toggleCustomExercise(exercise("Klimmzüge"))
        XCTAssertTrue(settings.isCustomSelectionFull)

        // Abwählen muss trotz voller Auswahl gehen, sonst sitzt man fest.
        XCTAssertTrue(settings.toggleCustomExercise(exercise("Bankdrücken")))
        XCTAssertEqual(settings.customExercises.count, 1)
        XCTAssertFalse(settings.isCustomSelectionFull)
    }

    /*
      Wer die Anzahl nachträglich verkleinert, hätte sonst eine Auswahl, die
      größer ist als das erlaubte Maximum — die Anzeige „7 / 5" wäre falsch
      und der Plan länger als bestellt.
    */
    func testVerkleinernDerAnzahlKuerztDieAuswahl() {
        settings.count = 6
        ["Bankdrücken", "Klimmzüge", "Kniebeugen", "Butterfly", "Crunches"]
            .forEach { settings.toggleCustomExercise(exercise($0)) }
        XCTAssertEqual(settings.customExercises.count, 5)

        settings.count = 3

        XCTAssertEqual(settings.customExercises.count, 3)
        XCTAssertEqual(
            settings.customExercises.map(\.name),
            ["Bankdrücken", "Klimmzüge", "Kniebeugen"],
            "gekürzt wird hinten, die zuerst gewählten bleiben"
        )
    }

    func testVergroessernDerAnzahlLaesstDieAuswahlStehen() {
        settings.count = 3
        ["Bankdrücken", "Klimmzüge"].forEach { settings.toggleCustomExercise(exercise($0)) }

        settings.count = 8

        XCTAssertEqual(settings.customExercises.count, 2)
        XCTAssertFalse(settings.isCustomSelectionFull)
    }

    // MARK: - Umsortieren und Entfernen

    func testVerschiebenAendertDieReihenfolge() {
        ["Bankdrücken", "Klimmzüge", "Kniebeugen"].forEach { settings.toggleCustomExercise(exercise($0)) }

        settings.moveCustomExercise(from: 0, to: 2)

        XCTAssertEqual(settings.customExercises.map(\.name), ["Klimmzüge", "Kniebeugen", "Bankdrücken"])
    }

    func testEntfernenUeberEinenUngueltigenIndexTutNichts() {
        settings.toggleCustomExercise(exercise("Bankdrücken"))

        settings.removeCustomExercise(at: 7)

        XCTAssertEqual(settings.customExercises.count, 1)
    }

    // MARK: - Zusammenspiel mit dem Rest der App

    /*
      `customCats` steuert weiterhin den Trainingsplan-Tab. Damit beide
      dasselbe meinen, folgen die Kategorien der Übungsauswahl.
    */
    func testDieKategorienFolgenDerUebungsauswahl() {
        settings.customExercises = []
        settings.toggleCustomExercise(exercise("Bankdrücken"))   // Brust
        settings.toggleCustomExercise(exercise("Klimmzüge"))     // Rücken

        XCTAssertTrue(settings.customCats.contains(.chest))
        XCTAssertTrue(settings.customCats.contains(.back))
    }

    func testLeereAuswahlLaesstDieKategorienStehen() {
        settings.customExercises = []
        settings.toggleCustomExercise(exercise("Bankdrücken"))
        let nachher = settings.customCats

        settings.customExercises = []

        XCTAssertEqual(settings.customCats, nachher, "alle Übungen abwählen löscht nicht die Kategorien")
    }

    /*
      Aus der Auswahl entsteht der Plan: dieselben Übungen, in derselben
      Reihenfolge. Gewürfelt wird nur noch das Satzschema.
    */
    func testAusDerAuswahlEntstehtGenauDieserPlan() {
        let namen = ["Bankdrücken", "Klimmzüge", "Kniebeugen"]
        namen.forEach { settings.toggleCustomExercise(exercise($0)) }

        let slots = PlanGenerator.applySetScheme(
            settings.customExercises,
            method: .standard,
            restTime: 60
        )

        XCTAssertEqual(slots.map(\.exercise.name), namen)
        XCTAssertEqual(slots.count, namen.count)
        XCTAssertTrue(slots.allSatisfy { $0.restSeconds == 60 })
    }

    func testDasSatzschemaWirdAngewendetOhneDieUebungenZuTauschen() {
        ["Bankdrücken", "Kniebeugen", "Butterfly", "Crunches"]
            .forEach { settings.toggleCustomExercise(exercise($0)) }
        let vorher = settings.customExercises.map(\.name)

        for _ in 0..<10 {
            let slots = PlanGenerator.applySetScheme(
                settings.customExercises,
                method: .fiveFourThree,
                restTime: 90
            )
            XCTAssertEqual(slots.map(\.exercise.name), vorher, "das Satzschema darf keine Übung austauschen")
        }
    }

    func testAuswahlUeberlebtDenNeustart() {
        ["Bankdrücken", "Klimmzüge"].forEach { settings.toggleCustomExercise(exercise($0)) }

        let daten = UserDefaults.standard.data(forKey: "kraftwuerfel:generator")
        XCTAssertNotNil(daten)

        let roh = (try? JSONSerialization.jsonObject(with: daten ?? Data())) as? [String: Any]
        let gespeichert = roh?["customExercises"] as? [[String: Any]]
        XCTAssertEqual(gespeichert?.count, 2)
        XCTAssertEqual(gespeichert?.first?["name"] as? String, "Bankdrücken")
    }
}

// MARK: - Einzelne Übung neu würfeln

final class SingleRerollTests: XCTestCase {

    private func slots(_ names: [String]) -> [ExerciseSlot] {
        names.map { name in
            let ex = ExerciseDatabase.all.first { $0.name == name } ?? ExerciseDatabase.all[0]
            return ExerciseSlot(exercise: ex, sets: 3, reps: "8-12", restSeconds: 60)
        }
    }

    /*
      Der Kern der Meldung: Beim Würfeln einer Übung blieben alle anderen
      unverändert — in den Daten war das immer so, sichtbar war es nicht.
    */
    func testNurDerGewuerfelteEintragAendertSich() {
        var plan = slots(["Bankdrücken", "Klimmzüge", "Kniebeugen", "Butterfly"])
        let vorher = plan.map(\.exercise.name)

        guard let neu = PlanGenerator.rerollSlot(plan: plan, at: 1, method: .standard) else {
            return XCTFail("keine Alternative gefunden")
        }
        plan[1] = neu

        XCTAssertNotEqual(plan[1].exercise.name, vorher[1])
        XCTAssertEqual(plan[0].exercise.name, vorher[0])
        XCTAssertEqual(plan[2].exercise.name, vorher[2])
        XCTAssertEqual(plan[3].exercise.name, vorher[3])
    }

    func testDasNeuGewuerfelteBehaeltSaetzeUndPause() {
        var plan = slots(["Bankdrücken", "Klimmzüge"])
        plan[0].sets = 5
        plan[0].reps = "5"
        plan[0].restSeconds = 90

        guard let neu = PlanGenerator.rerollSlot(plan: plan, at: 0, method: .standard) else {
            return XCTFail("keine Alternative gefunden")
        }

        XCTAssertEqual(neu.sets, 5)
        XCTAssertEqual(neu.reps, "5")
        XCTAssertEqual(neu.restSeconds, 90)
    }

    func testDasNeuGewuerfelteBleibtInDerKategorie() {
        let plan = slots(["Bankdrücken", "Klimmzüge"])
        let kategorie = plan[0].exercise.category

        for _ in 0..<15 {
            guard let neu = PlanGenerator.rerollSlot(plan: plan, at: 0, method: .standard) else { continue }
            XCTAssertTrue(
                neu.exercise.categories.contains(kategorie),
                "\(neu.exercise.name) gehört nicht zu \(kategorie.rawValue)"
            )
        }
    }

    func testEinUngueltigerIndexErgibtNichts() {
        let plan = slots(["Bankdrücken"])
        XCTAssertNil(PlanGenerator.rerollSlot(plan: plan, at: 5, method: .standard))
        XCTAssertNil(PlanGenerator.rerollSlot(plan: [], at: 0, method: .standard))
    }

    /*
      Die Animation gehört zum Fehlerbild: `runReel(count:)` ließ jede Karte
      Zufallsnamen durchlaufen. `runReel(only:)` markiert genau einen Index
      als laufend — die übrigen Karten zeigen weiter ihre echten Namen.
    */
    @MainActor
    func testDieAnimationLaeuftNurAufEinerKarte() {
        let reel = ReelController()

        reel.runReel(only: 2)

        XCTAssertEqual(reel.rollingIdx, [2])
        XCTAssertEqual(reel.scramble.keys.count, 1)
        XCTAssertNotNil(reel.scramble[2])
        XCTAssertNil(reel.scramble[0], "Karte 0 darf keinen Zufallsnamen zeigen")
        XCTAssertNil(reel.scramble[1], "Karte 1 darf keinen Zufallsnamen zeigen")

        reel.stopEverything()
    }

    @MainActor
    func testDerVolleDurchlaufMarkiertWeiterhinAlleKarten() {
        let reel = ReelController()

        // Beim kompletten Neuwürfeln ist genau das richtig.
        reel.runReel(count: 4)

        XCTAssertEqual(reel.rollingIdx, [0, 1, 2, 3])
        reel.stopEverything()
        XCTAssertTrue(reel.rollingIdx.isEmpty)
    }
}
