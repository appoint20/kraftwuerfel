import XCTest
@testable import Kraftwuerfel

/*
  Der Katalog und die Splits.

  Diese Zusicherungen prüfen `bundled`, nicht `all`: `refreshFromAPI()` darf den
  Katalog zur Laufzeit austauschen, und der Testrechner soll nicht davon
  abhängen, ob der Dienst gerade wach ist.
*/
final class ExerciseCatalogTests: XCTestCase {

    func testKatalogEnthaelt137Uebungen() {
        XCTAssertEqual(ExerciseDatabase.bundled.count, 137)
    }

    func testUebungsnamenSindEindeutig() {
        let names = ExerciseDatabase.bundled.map(\.name)
        XCTAssertEqual(Set(names).count, names.count, "doppelte Übungsnamen im Katalog")
    }

    /// Hip Thrust muss in Gesäß-, Bein- und Rücken-Splits auftauchen können.
    /// Genau dafür gibt es `categories` neben `category`.
    func testHipThrustHatDreiKategorien() throws {
        let hipThrust = try XCTUnwrap(
            ExerciseDatabase.bundled.first { $0.name == "Hip Thrust" }
        )
        XCTAssertEqual(Set(hipThrust.categories), [.glutes, .legs, .back])
    }

    /// Die Anzeige-Kategorie muss auch für die Auswahl gelten, sonst zeigt eine
    /// Übung eine Kategorie an, unter der sie nie gewürfelt wird.
    func testAnzeigeKategorieStecktImmerInCategories() {
        for exercise in ExerciseDatabase.bundled {
            XCTAssertTrue(
                exercise.categories.contains(exercise.category),
                "\(exercise.name): category \(exercise.category) fehlt in categories"
            )
        }
    }

    /// `custom` bekommt seine Kategorien aus der Auswahl des Nutzers und darf
    /// deshalb als einziger Split `nil` liefern.
    func testNurEigenerSplitOhneKategorien() {
        for split in SplitType.allCases where split != .custom {
            XCTAssertNotNil(split.categories, "\(split.rawValue) ohne Kategorien")
            XCTAssertFalse(split.categories?.isEmpty ?? true, "\(split.rawValue) leer")
        }
        XCTAssertNil(SplitType.custom.categories)
    }
}
