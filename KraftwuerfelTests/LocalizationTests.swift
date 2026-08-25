import XCTest
@testable import Kraftwuerfel

/*
  Die Sprache muss durchgehen.

  Gemeldet war: Oberfläche auf Englisch, Übungen weiter auf Deutsch. Dahinter
  standen zwei verschiedene Ursachen, und beide sind hier festgenagelt:

  1. Ansichten holten `titleDe` statt der übersetzten Fassung. Das betraf Ziel,
     Erfahrungsgrad und Ernährungsform — und weil diese Werte in den fertigen
     Plan wandern, blieben sie auch dort deutsch.
  2. Ein fertiger Plan trägt seine Texte in sich. Wer nach dem Erzeugen die
     Sprache wechselte, behielt die alten. `relocalize` zieht sie nach, ohne
     die Übungen anzufassen.
*/
final class LocalizationTests: XCTestCase {

    // MARK: - Vollständigkeit der Tabellen

    /// Ein Schlüssel, der nur in einer Sprache steht, fällt sonst erst dem
    /// Nutzer auf — `t()` gibt dann den Schlüssel selbst zurück.
    func testBeideTabellenTragenDieselbenSchluessel() {
        let de = Set(I18n.de.keys)
        let en = Set(I18n.en.keys)

        XCTAssertTrue(de.subtracting(en).isEmpty,
                      "nur auf Deutsch: \(de.subtracting(en).sorted())")
        XCTAssertTrue(en.subtracting(de).isEmpty,
                      "nur auf Englisch: \(en.subtracting(de).sorted())")
    }

    func testKeineLeerenUebersetzungen() {
        for (key, value) in I18n.de {
            XCTAssertFalse(value.isEmpty, "de/\(key) ist leer")
        }
        for (key, value) in I18n.en {
            XCTAssertFalse(value.isEmpty, "en/\(key) ist leer")
        }
    }

    /// Platzhalter müssen in beiden Sprachen dieselben sein, sonst bleibt in
    /// einer Sprache ein `{n}` stehen.
    func testPlatzhalterStimmenUeberein() {
        func placeholders(_ text: String) -> Set<String> {
            var found: Set<String> = []
            var current: String?
            for character in text {
                if character == "{" { current = "" }
                else if character == "}", let c = current { found.insert(c); current = nil }
                else if current != nil { current?.append(character) }
            }
            return found
        }

        for (key, german) in I18n.de {
            guard let english = I18n.en[key] else { continue }
            XCTAssertEqual(placeholders(german), placeholders(english),
                           "\(key): \(placeholders(german)) vs \(placeholders(english))")
        }
    }

    // MARK: - Aufzählungen

    func testZielErfahrungUndErnaehrungSindZweisprachig() {
        for goal in TrainingGoal.allCases {
            XCTAssertEqual(goal.localized("de"), goal.titleDe)
            XCTAssertEqual(goal.localized("en"), goal.titleEn)
        }
        /*
          Nicht jedes Ziel MUSS sich unterscheiden — „Definition“ heißt in
          beiden Sprachen gleich. Die Mehrheit muss es aber, sonst ist die
          englische Tabelle in Wahrheit eine Kopie der deutschen.
        */
        let differing = TrainingGoal.allCases.filter { $0.titleDe != $0.titleEn }
        XCTAssertGreaterThanOrEqual(differing.count, TrainingGoal.allCases.count - 1)

        for level in ExperienceLevel.allCases {
            XCTAssertEqual(level.localized("de"), level.titleDe)
            XCTAssertEqual(level.localized("en"), level.titleEn)
        }

        for diet in DietType.allCases {
            XCTAssertEqual(diet.localized("de"), diet.titleDe)
            XCTAssertEqual(diet.localized("en"), diet.titleEn)
            XCTAssertFalse(diet.descriptionEn.isEmpty, "\(diet.rawValue) ohne englische Beschreibung")
            XCTAssertNotEqual(diet.localizedDescription("de"), diet.localizedDescription("en"))
        }
    }

    /// Die geforderten Bezeichnungen des Fortschrittsgrads.
    func testFortschrittsgradHeisstWieVerlangt() {
        XCTAssertEqual(ExperienceLevel.beginner.localizedShort("de"), "Anfänger")
        XCTAssertEqual(ExperienceLevel.intermediate.localizedShort("de"), "Fortgeschritten")
        XCTAssertEqual(ExperienceLevel.advanced.localizedShort("de"), "Experte")

        XCTAssertEqual(ExperienceLevel.beginner.localizedShort("en"), "Beginner")
        XCTAssertEqual(ExperienceLevel.intermediate.localizedShort("en"), "Intermediate")
        XCTAssertEqual(ExperienceLevel.advanced.localizedShort("en"), "Advanced")

        // Auch die lange Fassung darf nicht mehr "Profi" heißen.
        XCTAssertTrue(ExperienceLevel.advanced.titleDe.hasPrefix("Experte"))
    }

    /// „Zyklus“ und „Cycle“ kommen aus demselben Schlüssel — sowohl der
    /// KI-Coach als auch der Trainingsplan benutzen ihn.
    func testZyklusHeisstAufEnglischCycle() {
        XCTAssertEqual(I18n.de["tp.cycleLabel"], "Zyklus {n}")
        XCTAssertEqual(I18n.en["tp.cycleLabel"], "Cycle {n}")
        XCTAssertTrue(I18n.de["tp.cycle"]?.hasPrefix("Zyklus") ?? false)
        XCTAssertTrue(I18n.en["tp.cycle"]?.hasPrefix("Cycle") ?? false)
    }

    /// Equipment und Muskelgruppe stehen an jeder Übungszeile — beide müssen
    /// der Sprache folgen.
    func testEquipmentUndKategorienSindZweisprachig() {
        let expected: [(EquipmentType, String, String)] = [
            (.barbell, "Langhantel", "Barbell"),
            (.dumbbell, "Kurzhantel", "Dumbbell"),
            (.bodyweight, "Körpergewicht", "Bodyweight"),
        ]
        for (equipment, german, english) in expected {
            XCTAssertEqual(equipment.localized("de"), german)
            XCTAssertEqual(equipment.localized("en"), english)
        }

        for equipment in EquipmentType.allCases {
            XCTAssertFalse(equipment.localizedEn.isEmpty, "\(equipment.rawValue) ohne Übersetzung")
            XCTAssertEqual(equipment.localized("de"), equipment.rawValue)
        }

        for category in MuscleCategory.allCases {
            XCTAssertFalse(category.localizedEn.isEmpty, "\(category.rawValue) ohne Übersetzung")
            XCTAssertEqual(category.localized("de"), category.rawValue)
            XCTAssertNotEqual(category.localized("de"), category.localized("en"))
        }
    }

    // MARK: - Übungsnamen

    func testUebungsnamenFolgenDerSprache() {
        for exercise in ExerciseDatabase.bundled {
            XCTAssertEqual(exercise.localizedName(language: "de"), exercise.name)
            XCTAssertEqual(exercise.localizedName(language: "en"), exercise.nameEn)
            XCTAssertFalse(exercise.nameEn.isEmpty, "\(exercise.name) ohne englischen Namen")
        }
    }

    // MARK: - Fertige Pläne

    private var input: AICoachInput {
        AICoachInput(
            goal: .muscle, experience: .intermediate,
            selectedDays: ["Mo", "Mi", "Fr"], sessionDurationMinutes: 60, weeks: 4,
            equipment: Set(EquipmentType.allCases), diet: .vegan, includeWarmup: true
        )
    }

    func testErzeugterPlanTraegtSeineSprache() {
        XCTAssertEqual(AICoachService.shared.generatePlan(input: input, language: "de").language, "de")
        XCTAssertEqual(AICoachService.shared.generatePlan(input: input, language: "en").language, "en")
    }

    func testDeutscherUndEnglischerPlanUnterscheidenSichImText() {
        let de = AICoachService.shared.generatePlan(input: input, language: "de")
        let en = AICoachService.shared.generatePlan(input: input, language: "en")

        XCTAssertNotEqual(de.title, en.title)
        XCTAssertNotEqual(de.days.first?.focus, en.days.first?.focus)
        XCTAssertNotEqual(de.notes, en.notes)
        XCTAssertNotEqual(de.nutrition?.disclaimer, en.nutrition?.disclaimer)
        XCTAssertNotEqual(de.days.first?.warmup.first?.name, en.days.first?.warmup.first?.name)
    }

    /// Der wichtigste Test dieser Datei: Sprache wechseln darf das Training
    /// nicht neu würfeln.
    func testUmschaltenAendertDenTextAberNichtDieUebungen() throws {
        let german = AICoachService.shared.generatePlan(input: input, language: "de")
        let english = AICoachService.shared.relocalize(german, input: input, language: "en")

        XCTAssertEqual(english.language, "en")
        XCTAssertEqual(english.id, german.id, "es ist derselbe Plan")
        XCTAssertNotEqual(english.title, german.title)
        XCTAssertEqual(english.days.count, german.days.count)

        for (before, after) in zip(german.days, english.days) {
            XCTAssertEqual(after.weekday, before.weekday)
            XCTAssertEqual(
                after.cycle1Slots.map(\.exercise.name),
                before.cycle1Slots.map(\.exercise.name),
                "Zyklus 1 wurde neu gewürfelt"
            )
            XCTAssertEqual(
                after.cycle2Slots.map(\.exercise.name),
                before.cycle2Slots.map(\.exercise.name),
                "Zyklus 2 wurde neu gewürfelt"
            )
            XCTAssertNotEqual(after.focus, before.focus, "der Fokus blieb deutsch")
        }
    }

    func testUmschaltenInDieselbeSpracheAendertNichts() {
        let german = AICoachService.shared.generatePlan(input: input, language: "de")
        XCTAssertEqual(AICoachService.shared.relocalize(german, input: input, language: "de"), german)
    }

    func testGespeicherterPlanFolgtDerSprache() throws {
        let german = AICoachService.shared.generatePlan(input: input, language: "de")
        let entry = SavedAIPlan(name: "Test", plan: german, input: input)

        let english = entry.localizedPlan(in: "en")
        XCTAssertEqual(english.language, "en")
        XCTAssertEqual(
            english.days.first?.cycle1Slots.map(\.exercise.name),
            german.days.first?.cycle1Slots.map(\.exercise.name)
        )
    }
}
