import XCTest
@testable import Kraftwuerfel

/*
  Echte Aufrufe gegen kraftwuerfel-api.onrender.com.

  Standardmäßig übersprungen — ein Test, der ohne Netz oder bei einem
  schlafenden Dienst rot wird, sagt nichts über den Code aus und macht die
  Suite unbrauchbar. Zum Prüfen der Anbindung gezielt einschalten:

      TEST_RUNNER_KRAFT_LIVE_API=1 xcodebuild test -scheme Kraftwuerfel …

  Das Präfix `TEST_RUNNER_` ist nötig: xcodebuild reicht die Umgebung der Shell
  nicht an den Testträger durch, nur Variablen mit diesem Präfix.

  Geprüft wird der Weg, den die App wirklich geht: KraftAPI, nicht curl.
*/
final class LiveBackendTests: XCTestCase {

    private var isEnabled: Bool {
        ProcessInfo.processInfo.environment["KRAFT_LIVE_API"] == "1"
    }

    override func setUpWithError() throws {
        try XCTSkipUnless(isEnabled, "KRAFT_LIVE_API=1 setzen, um gegen den echten Dienst zu prüfen")
    }

    func testHealthAntwortet() async throws {
        let count = try await KraftAPI.shared.health()
        XCTAssertGreaterThan(count, 0, "der Dienst meldet keine Übungen")
    }

    /// Der Katalog muss sich in `Exercise` übersetzen lassen — Kategorien und
    /// Geräte kommen als deutsche Klartextwerte und müssen die Aufzählungen
    /// treffen. Läuft das auseinander, fällt die App still auf die eingebaute
    /// Liste zurück.
    func testKatalogLaesstSichVollstaendigUebersetzen() async throws {
        let remote = try await KraftAPI.shared.exercises()
        XCTAssertGreaterThanOrEqual(remote.count, ExerciseDatabase.bundled.count)

        var unknownCategories: Set<String> = []
        var unknownEquipment: Set<String> = []
        for entry in remote {
            if MuscleCategory(rawValue: entry.category) == nil {
                unknownCategories.insert(entry.category)
            }
            if EquipmentType(rawValue: entry.equipment) == nil {
                unknownEquipment.insert(entry.equipment)
            }
            XCTAssertFalse(entry.name.isEmpty)
            XCTAssertFalse(entry.nameEn.isEmpty, "\(entry.name) ohne englischen Namen")
        }

        XCTAssertTrue(unknownCategories.isEmpty, "unbekannte Kategorien: \(unknownCategories.sorted())")
        XCTAssertTrue(unknownEquipment.isEmpty, "unbekannte Geräte: \(unknownEquipment.sorted())")
    }

    func testFilterWirktServerseitig() async throws {
        let chest = try await KraftAPI.shared.exercises(category: MuscleCategory.chest.rawValue)
        XCTAssertFalse(chest.isEmpty)
        XCTAssertTrue(chest.allSatisfy { $0.category == MuscleCategory.chest.rawValue })
    }

    @MainActor
    func testRefreshUebernimmtDenServerkatalog() async throws {
        await ExerciseDatabase.refreshFromAPI()

        switch BackendStatus.shared.catalogSource {
        case .server(let count):
            XCTAssertEqual(count, ExerciseDatabase.all.count)
        case .bundled:
            XCTFail("Katalog blieb bei der eingebauten Liste")
        }
    }

    /// Ohne Anmeldung antwortet der Dienst mit 401. Das ist kein Fehler,
    /// sondern der erwartete Zustand — und der Grund, warum der KI-Coach ohne
    /// Konto lokal rechnet.
    func testGeneratePlanVerlangtEinToken() async {
        let previous = KraftAPI.shared.accessToken
        KraftAPI.shared.accessToken = nil
        defer { KraftAPI.shared.accessToken = previous }

        do {
            _ = try await KraftAPI.shared.generatePlan(samplePlanRequest)
            XCTFail("ohne Token darf kein Plan zurückkommen")
        } catch KraftAPI.APIError.unauthorized {
            // genau so soll es sein
        } catch {
            XCTFail("erwartet .unauthorized, bekam \(error)")
        }
    }

    private var samplePlanRequest: KraftAPI.PlanRequest {
        KraftAPI.PlanRequest(
            goal: TrainingGoal.muscle.rawValue,
            experience: ExperienceLevel.intermediate.rawValue,
            sex: "male",
            age: 30,
            height: 180,
            weight: 82,
            goalWeight: 78,
            method: TrainingMethod.fiveFourThree.rawValue,
            days: ["Mo", "Mi", "Fr"],
            sessionMinutes: 60,
            weeks: 4,
            equipment: [EquipmentType.barbell.rawValue],
            focus: [],
            limitations: "",
            warmup: "auto",
            diet: DietType.omnivore.rawValue,
            language: "de"
        )
    }
}
