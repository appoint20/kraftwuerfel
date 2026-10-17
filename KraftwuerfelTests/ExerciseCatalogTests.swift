import XCTest
@testable import Kraftwuerfel

/*
  Der Katalog und die Splits.

  Diese Zusicherungen prüfen `bundled`, nicht `all`: `refreshFromAPI()` darf den
  Katalog zur Laufzeit austauschen, und der Testrechner soll nicht davon
  abhängen, ob der Dienst gerade wach ist.
*/
final class ExerciseCatalogTests: XCTestCase {

    /// 137 aus dem Web-Katalog plus 15 echte Home-Übungen (wie im API-Katalog).
    func testKatalogEnthaelt152Uebungen() {
        XCTAssertEqual(ExerciseDatabase.bundled.count, 152)
    }

    /// Die Bundled-Liste muss mit dem Server übereinstimmen, sonst verwirft
    /// `refreshFromAPI()` den Serverkatalog oder kennt Namen aus Plänen nicht.
    func testHomeUebungenSindKoerpergewichtUndOhneGeraet() {
        let home = ["Kniebeugen ohne Gewicht", "Ausfallschritte ohne Gewicht", "Hampelmann (Jumping Jacks)",
                    "Knie-Liegestütze", "Seitstütz (Side Plank)", "Wandsitzen (Wall Sit)"]
        for name in home {
            let exercise = ExerciseDatabase.bundled.first { $0.name == name }
            XCTAssertEqual(exercise?.equipment, .bodyweight, name)
            XCTAssertEqual(exercise?.needsApparatus, false, name)
        }
        XCTAssertTrue(ExerciseDatabase.bundled.first { $0.name == "Klimmzüge" }?.needsApparatus == true)
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

    /*
      Neu-Würfeln in einem Home-Plan: vorher zählte nur die Muskelgruppe, und
      aus „Kniebeugen ohne Gewicht" wurde eine Beinpresse oder Hackenschmidt.
    */
    func testNeuWuerfelnImHomePlanBleibtOhneGeraet() throws {
        let names = ["Liegestütze", "Kniebeugen ohne Gewicht", "Plank (Unterarmstütz)", "Hampelmann (Jumping Jacks)"]
        let plan = try names.map { name in
            ExerciseSlot(exercise: try XCTUnwrap(ExerciseDatabase.bundled.first { $0.name == name }, name))
        }
        for index in plan.indices {
            for _ in 0..<40 {
                guard let fresh = PlanGenerator.rerollSlot(plan: plan, at: index, method: .standard) else { continue }
                XCTAssertEqual(fresh.exercise.equipment, .bodyweight, fresh.exercise.name)
                XCTAssertFalse(fresh.exercise.needsApparatus, fresh.exercise.name)
            }
        }
    }

    func testStudioPlanWirdBeimNeuWuerfelnNichtEingeschraenkt() throws {
        let bench = try XCTUnwrap(ExerciseDatabase.bundled.first { $0.name == "Bankdrücken" })
        XCTAssertNil(HomeTraining.inferredEquipment(for: [bench]))
    }
}
