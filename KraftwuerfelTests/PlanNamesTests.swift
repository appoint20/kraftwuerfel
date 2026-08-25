import XCTest
@testable import Kraftwuerfel

/*
  Rufnamen (src/lib/planNames.js).

  Der Hash rechnet absichtlich wie JavaScript: 32-Bit-Überlauf über
  UTF-16-Einheiten. Läuft das auseinander, vergibt die App andere Namen als das
  Web für denselben Plan — und der Nutzer sieht seinen Plan plötzlich anders
  heißen.
*/
final class PlanNamesTests: XCTestCase {

    func testGleicherSeedGleicherName() {
        let seed = "Bankdrücken|Klimmzüge|Kniebeugen"
        let first = PlanNames.planName(for: seed)
        for _ in 0..<20 {
            XCTAssertEqual(PlanNames.planName(for: seed), first)
        }
    }

    func testNameIstImmerGenauEinWort() {
        for seed in ["", "Mo", "a", "Bankdrücken", "sehr langer Seed mit Leerzeichen", "🏋️"] {
            let name = PlanNames.planName(for: seed)
            XCTAssertEqual(
                name.split(separator: " ").count, 1,
                "\(seed) -> \(name)"
            )
        }
    }

    func testNameKommtImmerAusDerListe() {
        for i in 0..<300 {
            XCTAssertTrue(PlanNames.names.contains(PlanNames.planName(for: "seed-\(i)")))
        }
    }

    /// Der Hash muss den 32-Bit-Überlauf aushalten, ohne abzustürzen — genau
    /// deshalb steht dort `&*` und `&+` statt `*` und `+`.
    func testHashLaeuftUeberOhneAbsturz() {
        let long = String(repeating: "Kraftwürfel", count: 500)
        XCTAssertNoThrow(PlanNames.hash(long))
        XCTAssertTrue(PlanNames.names.contains(PlanNames.planName(for: long)))
    }

    // MARK: - Eindeutigkeit

    func testUniquePlanNameMeidetVergebeneNamen() {
        let taken = Array(PlanNames.names.prefix(10))
        let name = PlanNames.uniquePlanName(taken: taken, seed: "irgendwas")
        XCTAssertFalse(taken.map { $0.lowercased() }.contains(name.lowercased()))
    }

    /// Groß-/Kleinschreibung darf keinen zweiten "titan" durchlassen.
    func testUniquePlanNameIgnoriertGrossKleinschreibung() {
        let taken = PlanNames.names.map { $0.uppercased() }
        let name = PlanNames.uniquePlanName(taken: taken, seed: "x")
        XCTAssertFalse(
            PlanNames.names.map { $0.lowercased() }.contains(name.lowercased()),
            "\(name) war schon vergeben"
        )
    }

    /// Sind alle Wörter belegt, wird nummeriert statt doppelt vergeben.
    func testUniquePlanNameNummeriertWennAllesBelegtIst() {
        let taken = PlanNames.names
        let name = PlanNames.uniquePlanName(taken: taken, seed: "x")
        XCTAssertFalse(taken.contains(name))
        XCTAssertTrue(name.contains(" "), "erwartet einen nummerierten Namen, bekam \(name)")
    }

    func testKeineDoppeltenNamenInnerhalbEinesPlans() {
        for salt in ["a", "b", "plan-2026", ""] {
            let names = PlanNames.planNamesForDays(Weekdays.all, salt: salt)
            XCTAssertEqual(names.count, 7)
            XCTAssertEqual(
                Set(names.values).count, 7,
                "salt \(salt): \(names.values.sorted())"
            )
        }
    }

    func testJederTagBekommtEinenNamen() {
        let days = ["Mo", "Mi", "Fr"]
        let names = PlanNames.planNamesForDays(days, salt: "seed")
        for day in days {
            XCTAssertNotNil(names[day])
            XCTAssertFalse(names[day]?.isEmpty ?? true)
        }
    }
}
