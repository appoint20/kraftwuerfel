import XCTest
@testable import Kraftwuerfel

@MainActor
final class LiveWorkoutAndMusicTests: XCTestCase {

    func testMusicPlayerShuffle() {
        let player = MusicLibraryPlayer.shared
        XCTAssertFalse(player.isShuffleEnabled)
        player.toggleShuffle()
        XCTAssertTrue(player.isShuffleEnabled)
        player.toggleShuffle()
        XCTAssertFalse(player.isShuffleEnabled)
    }

    func testEditingSetData() {
        var data = EditingSetData(
            exerciseIndex: 0,
            setIndex: 1,
            exerciseName: "Bankdrücken",
            weight: 75.0,
            reps: 8,
            done: true
        )
        XCTAssertEqual(data.id, 1)
        XCTAssertEqual(data.exerciseName, "Bankdrücken")
        XCTAssertEqual(data.weight, 75.0)

        // Increment by 2.5 kg
        data.weight += 2.5
        XCTAssertEqual(data.weight, 77.5)

        // Adjust reps
        data.reps = 10
        XCTAssertEqual(data.reps, 10)
    }

    func testWatchSyncManagerSetWithDataAndSkipRest() {
        let sync = WatchSyncManager.shared
        var completedWeight: Double?
        var completedReps: Int?
        var skipRestCalled = false

        sync.onSetCompletedWithDataRemotely = { weight, reps in
            completedWeight = weight
            completedReps = reps
        }

        sync.onSkipRestRequestedRemotely = {
            skipRestCalled = true
        }

        sync.onSetCompletedWithDataRemotely?(85.0, 10)
        XCTAssertEqual(completedWeight, 85.0)
        XCTAssertEqual(completedReps, 10)

        sync.onSkipRestRequestedRemotely?()
        XCTAssertTrue(skipRestCalled)

        sync.sendWorkoutUpdate(
            exercise: "Bankdrücken",
            set: 2,
            totalSets: 4,
            weight: 85.0,
            reps: 10,
            targetReps: "8-10",
            isRest: false,
            restEndsAt: nil,
            restDurationSeconds: 90,
            isPaused: false,
            sessionStartedAt: Date()
        )

        XCTAssertEqual(sync.currentExercise, "Bankdrücken")
        XCTAssertEqual(sync.currentSet, 2)
        XCTAssertEqual(sync.totalSets, 4)
        XCTAssertEqual(sync.currentWeight, 85.0)
        XCTAssertEqual(sync.currentReps, 10)
        XCTAssertEqual(sync.targetReps, "8-10")
        XCTAssertEqual(sync.restDurationSeconds, 90)
    }

    func testFitnessFactsProviderHas20PlusFacts() {
        let facts = FitnessFactsProvider.facts
        XCTAssertGreaterThanOrEqual(facts.count, 20)

        for fact in facts {
            XCTAssertFalse(fact.titleDe.isEmpty)
            XCTAssertFalse(fact.factDe.isEmpty)
            XCTAssertFalse(fact.titleEn.isEmpty)
            XCTAssertFalse(fact.factEn.isEmpty)
            XCTAssertFalse(fact.icon.isEmpty)
        }
    }

    func testTrainingMethod3x3x3AndSplitCleanups() {
        XCTAssertEqual(TrainingMethod.standard.titleDe, "3x3x3")
        XCTAssertEqual(TrainingMethod.standard.titleEn, "3×3×3")

        let methods = TrainingMethod.allCases
        XCTAssertFalse(methods.map(\.rawValue).contains("ganzkoerper"))

        let splits = SplitType.allCases
        XCTAssertFalse(splits.map(\.rawValue).contains("Frauen"))
    }

    func testMusicPlayerPersistence() {
        let player = MusicLibraryPlayer.shared
        player.clearPlaylist()
        XCTAssertTrue(player.tracks.isEmpty)
        XCTAssertNil(UserDefaults.standard.stringArray(forKey: "kraftwuerfel:saved_playlist_ids"))
    }

    func testWatchSyncManagerReceivesMeasurements() {
        let sync = WatchSyncManager.shared
        let payload: [String: Any] = [
            "type": "measurements",
            "bpm": 145,
            "kcal": 210.5,
            "timestamp": Date().timeIntervalSince1970
        ]
        sync.apply(payload)
        XCTAssertEqual(sync.freshWatchHeartRate, 145)
        XCTAssertEqual(sync.freshWatchActiveCalories, 210.5)
        XCTAssertEqual(WatchSyncManager.sampleValidity, 30)
    }

    func testChallengeStoreDefaultsAndProgression() {
        let store = ChallengeStore.shared
        store.durationDays = 30
        store.category = .squats
        XCTAssertEqual(store.durationDays, 30)
        XCTAssertEqual(store.category, .squats)

        let taskDay1 = store.taskForDay(1, category: .squats)
        XCTAssertEqual(taskDay1.dayNumber, 1)
        XCTAssertEqual(taskDay1.targetRepsOrTimeDe, "25 Air Squats")

        let taskDay10 = store.taskForDay(10, category: .squats)
        XCTAssertEqual(taskDay10.targetRepsOrTimeDe, "70 Air Squats")

        let calisthenicsTask = store.taskForDay(5, category: .calisthenics)
        XCTAssertFalse(calisthenicsTask.titleDe.isEmpty)
        XCTAssertFalse(calisthenicsTask.targetRepsOrTimeDe.isEmpty)
    }

    func testChallengeStoreCompletionAndReset() {
        let store = ChallengeStore.shared
        store.resetChallenge()
        XCTAssertTrue(store.completedDays.isEmpty)
        XCTAssertEqual(store.progressPercent, 0.0)

        store.markTodayCompleted()
        XCTAssertTrue(store.isCompletedToday)
        XCTAssertEqual(store.streak, 1)

        store.resetChallenge()
        XCTAssertFalse(store.isCompletedToday)
        XCTAssertEqual(store.streak, 0)
    }

    /*
      GeneratorMode lag als verschachtelter Typ in GeneratorView und die Wahl
      als @State — beim Tabwechsel war sie weg. Jetzt steht der Typ für sich
      und der Wert in GeneratorSettings.
    */
    func testGeneratorModes() {
        let modes = GeneratorMode.allCases
        XCTAssertEqual(modes.count, 3)
        XCTAssertTrue(modes.contains(.generator))
        XCTAssertTrue(modes.contains(.challenge))
        // Selbst zusammenstellen — fehlte bis dahin ganz.
        XCTAssertTrue(modes.contains(.builder))
    }

    func testJederGeneratorTabHatBeschriftungUndSymbol() {
        for mode in GeneratorMode.allCases {
            XCTAssertFalse(mode.title("de").isEmpty)
            XCTAssertFalse(mode.title("en").isEmpty)
            XCTAssertFalse(mode.icon.isEmpty)
        }
    }

    func testDerGewaehlteGeneratorTabUeberlebtDenTabwechsel() {
        let settings = GeneratorSettings.shared
        let vorher = settings.mode
        defer { settings.mode = vorher }

        settings.mode = .challenge
        XCTAssertEqual(settings.mode, .challenge)

        // So, wie GeneratorSettings beim Start wieder einliest.
        let daten = UserDefaults.standard.data(forKey: "kraftwuerfel:generator")
        XCTAssertNotNil(daten)
        let roh = (try? JSONSerialization.jsonObject(with: daten ?? Data())) as? [String: Any]
        XCTAssertEqual(roh?["mode"] as? String, "challenge")
    }

    func testWipeSetztDenGeneratorTabZurueck() {
        let settings = GeneratorSettings.shared
        settings.mode = .challenge
        settings.wipe()
        XCTAssertEqual(settings.mode, .generator)
    }
}
