import XCTest
@testable import Kraftwuerfel

/*
  Der Kontowechsel darf nichts vom vorigen Nutzer stehen lassen.

  Der Fehler dahinter: `signOut()` räumte genau zwei Speicher ab (KI-Pläne
  und Meal Guides). Trainingsarchiv, aktiver Plan, Favoriten, Challenge und
  vor allem das Profil mit Geschlecht, Alter, Größe und Gewicht blieben
  liegen. Wer sich danach mit einem anderen Konto anmeldete, sah die letzte
  Einheit und die Gesundheitsdaten des Vorgängers.

  Auf einem geteilten Gerät ist das kein Anzeigefehler, sondern die Offenlegung
  von Gesundheitsdaten nach Art. 9 DSGVO an eine fremde Person.
*/
@MainActor
final class AccountSwitchTests: XCTestCase {

    private let auth = AuthService.shared
    private static let lastAccountKey = "kraftwuerfel:lastAccountId"

    private func seedAllStores() {
        let exercise = ExerciseDatabase.bundled[0]
        let slot = ExerciseSlot(exercise: exercise)

        _ = WorkoutHistoryStore.shared.logSession(
            planTitle: "Vorgänger-Einheit",
            durationSeconds: 1800,
            peakHeartRate: nil,
            estimatedCalories: nil,
            exercises: [
                LoggedExercise(
                    exerciseId: exercise.id,
                    exerciseName: exercise.name,
                    category: exercise.category,
                    sets: [LoggedSet(setIndex: 0, weight: 80, reps: 8)]
                )
            ],
            motivationalQuote: ""
        )

        _ = FavoritesStore.shared.toggle(
            day: "monday",
            cycles: [[slot]],
            split: "push",
            method: .standard,
            isPro: true
        )

        SavedPlansStore.shared.add(SavedWorkoutPlan(name: "Gespeichert", slots: [slot]))

        UserProfileStore.shared.update {
            $0.weightKg = 88
            $0.heightCm = 186
            $0.isComplete = true
        }
    }

    private func storesAreEmpty() -> Bool {
        WorkoutHistoryStore.shared.logs.isEmpty
            && FavoritesStore.shared.favorites.isEmpty
            && SavedPlansStore.shared.items.isEmpty
            && !UserProfileStore.shared.profile.isComplete
    }

    override func setUp() {
        super.setUp()
        auth.wipeContentStores()
    }

    override func tearDown() {
        auth.wipeContentStores()
        UserDefaults.standard.removeObject(forKey: Self.lastAccountKey)
        super.tearDown()
    }

    /// Der eigentliche Fehlerfall: anderes Konto, alles muss weg.
    func testAnderesKontoLoeschtAlleLokalenDaten() {
        auth.wipeIfDifferentAccount(newAccountId: "nutzer-A")
        seedAllStores()

        XCTAssertFalse(storesAreEmpty(), "Vorbedingung: die Speicher sind gefüllt")

        auth.wipeIfDifferentAccount(newAccountId: "nutzer-B")

        XCTAssertTrue(
            storesAreEmpty(),
            "nach einem Kontowechsel darf nichts vom vorigen Nutzer übrig sein"
        )
    }

    /*
      Die Gegenprobe, und der Grund, warum nicht einfach beim Abmelden gelöscht
      wird: Diese Daten liegen NUR auf dem Gerät. Sie bei jedem Abmelden zu
      verwerfen hieße, sie endgültig zu verlieren — für den häufigsten Fall
      überhaupt, nämlich denselben Nutzer, der sich neu anmeldet.
    */
    func testGleichesKontoBehaeltAlleDaten() {
        auth.wipeIfDifferentAccount(newAccountId: "nutzer-A")
        seedAllStores()

        auth.wipeIfDifferentAccount(newAccountId: "nutzer-A")

        XCTAssertFalse(
            storesAreEmpty(),
            "wer sich mit demselben Konto neu anmeldet, darf nichts verlieren"
        )
        XCTAssertEqual(UserProfileStore.shared.profile.weightKg, 88)
    }

    /*
      Erste Anmeldung nach dem Update: Es ist noch keine Kennung vermerkt.
      Dann wird nur vermerkt und nichts gelöscht — die vorhandenen Daten
      stammen mit hoher Wahrscheinlichkeit von genau diesem Nutzer, und sie
      ungefragt zu verwerfen wäre schlimmer als der Fehler selbst.
    */
    func testErsteAnmeldungOhneVermerkLoeschtNichts() {
        UserDefaults.standard.removeObject(forKey: Self.lastAccountKey)
        seedAllStores()

        auth.wipeIfDifferentAccount(newAccountId: "nutzer-A")

        XCTAssertFalse(
            storesAreEmpty(),
            "ohne vorherige Kennung darf nicht ungefragt gelöscht werden"
        )
    }

    /// Jeder Speicher, den die App führt, muss im Abräumen vorkommen. Der
    /// Fehler war, dass genau das nicht galt.
    func testAbraeumenErfasstAlleSpeicher() {
        seedAllStores()
        ChallengeStore.shared.completedDays = [1, 2]

        auth.wipeContentStores()

        XCTAssertTrue(WorkoutHistoryStore.shared.logs.isEmpty, "Trainingsarchiv")
        XCTAssertTrue(FavoritesStore.shared.favorites.isEmpty, "Favoriten")
        XCTAssertTrue(SavedPlansStore.shared.items.isEmpty, "gespeicherte Pläne")
        XCTAssertTrue(SavedAIPlansStore.shared.items.isEmpty, "KI-Pläne")
        XCTAssertTrue(SavedMealGuidesStore.shared.items.isEmpty, "Meal Guides")
        XCTAssertFalse(UserProfileStore.shared.profile.isComplete, "Profil (Art. 9)")
        XCTAssertTrue(ChallengeStore.shared.completedDays.isEmpty, "Challenge-Fortschritt")
    }
}
