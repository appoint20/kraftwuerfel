import XCTest
@testable import Kraftwuerfel

/*
  Die Zusagen der Home-Challenge auf der App-Seite.

  Der Server prüft seine Seite selbst (ChallengeTests im API-Projekt). Hier
  geht es um das, was die App daraus macht: dass die Wochentage zu der Zahl
  passen, die der Nutzer antippt, dass der Fragebogen dieselben Werte anbietet,
  die der Server akzeptiert, und dass ein Plan mit zu wenigen Übungen auf
  mindestens fünf aufgefüllt wird statt halb leer anzukommen.
*/
final class HomeChallengeTests: XCTestCase {

    // MARK: - Wochentage

    func testTageProWocheErgebenDieGleicheVerteilungWieDerServer() {
        let session = ChallengeSession.shared
        let erwartet: [Int: [String]] = [
            3: ["Mo", "Mi", "Fr"],
            4: ["Mo", "Di", "Do", "Fr"],
            5: ["Mo", "Di", "Mi", "Do", "Fr"],
            6: ["Mo", "Di", "Mi", "Do", "Fr", "Sa"],
            7: ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"],
        ]

        for (anzahl, tage) in erwartet {
            session.daysPerWeek = anzahl
            XCTAssertEqual(session.selectedDays, tage, "bei \(anzahl) Tagen pro Woche")
            XCTAssertEqual(session.selectedDays.count, anzahl)
        }
    }

    func testDieTageStehenInWochenreihenfolge() {
        let session = ChallengeSession.shared
        for anzahl in ChallengeSession.daysPerWeekOptions {
            session.daysPerWeek = anzahl
            let indizes = session.selectedDays.compactMap { Weekdays.all.firstIndex(of: $0) }
            XCTAssertEqual(indizes, indizes.sorted(), "Reihenfolge bei \(anzahl) Tagen")
        }
    }

    // MARK: - Auswahlmöglichkeiten
    /*
      Weicht die App von den Werten des Servers ab, rundet der still auf den
      nächsten — der Nutzer bekäme eine andere Challenge, als er angetippt hat.
    */

    func testAngeboteneEinheitsdauernSindDieDesServers() {
        XCTAssertEqual(ChallengeSession.minuteOptions, [10, 15, 20, 30, 45, 60])
    }

    func testDieVomNutzerGeforderten10Bis45MinutenStehenZurWahl() {
        for minuten in [10, 15, 30, 45] {
            XCTAssertTrue(
                ChallengeSession.minuteOptions.contains(minuten),
                "\(minuten) Minuten fehlt im Fragebogen"
            )
        }
    }

    func testChallengeLaengenSindEineTeilmengeDerServerwerte() {
        // ChallengeAnswers.DurationDayOptions im Server
        let serverwerte: Set<Int> = [7, 10, 14, 20, 30, 45, 60, 90, 100]
        for tage in ChallengeSession.durationOptions {
            XCTAssertTrue(serverwerte.contains(tage), "\(tage) Tage rundet der Server um")
        }
    }

    func testZuhauseGibtEsKeinStudioEquipment() {
        let verboten: Set<EquipmentType> = [.barbell, .machine, .cable, .smithMachine]
        for eq in ChallengeSession.homeEquipment {
            XCTAssertFalse(verboten.contains(eq), "\(eq.rawValue) gehört nicht in eine Home-Challenge")
        }
    }

    // MARK: - Equipment-Auswahl

    func testKoerpergewichtLaesstSichNichtAbwaehlen() {
        let session = ChallengeSession.shared
        session.equipment = [.bodyweight]
        session.toggleEquipment(.bodyweight)
        XCTAssertTrue(session.equipment.contains(.bodyweight))
    }

    func testKurzhantelLaesstSichZuUndAbwaehlen() {
        let session = ChallengeSession.shared
        session.equipment = [.bodyweight]

        session.toggleEquipment(.dumbbell)
        XCTAssertTrue(session.equipment.contains(.dumbbell))
        XCTAssertTrue(session.equipment.contains(.bodyweight))

        session.toggleEquipment(.dumbbell)
        XCTAssertFalse(session.equipment.contains(.dumbbell))
        XCTAssertTrue(session.equipment.contains(.bodyweight))
    }

    // MARK: - Ziele

    func testDieDreiZieleBildenAufDieTrainingszieleAb() {
        XCTAssertEqual(ChallengeGoal.buildMuscle.trainingGoal, .muscle)
        XCTAssertEqual(ChallengeGoal.loseWeight.trainingGoal, .weightLoss)
        XCTAssertEqual(ChallengeGoal.getFit.trainingGoal, .fitness)
    }

    /*
      TrainingGoal.weightLoss heißt "weight_loss". Der Server kannte lange nur
      "abnehmen" und antwortete auf alles andere mit 400 — das Ziel Abnehmen
      war über die App nicht erreichbar. Der Rohwert darf sich deshalb nicht
      unbemerkt ändern.
    */
    func testDieRohwerteDerZieleBleibenStabil() {
        XCTAssertEqual(ChallengeGoal.buildMuscle.rawValue, "muscle")
        XCTAssertEqual(ChallengeGoal.loseWeight.rawValue, "weight_loss")
        XCTAssertEqual(ChallengeGoal.getFit.rawValue, "fitness")
    }

    // MARK: - Ableitungen für die KI-Eingabe

    func testDerTrainingsortIstImmerZuhause() {
        XCTAssertEqual(ChallengeSession.shared.asCoachInput.trainingLocation, .homeBodyweight)
    }

    func testDieChallengeLaengeWirdInWochenUmgerechnet() {
        let session = ChallengeSession.shared

        session.durationDays = 10
        XCTAssertEqual(session.asCoachInput.weeks, 2)

        session.durationDays = 30
        XCTAssertEqual(session.asCoachInput.weeks, 5)

        session.durationDays = 90
        XCTAssertEqual(session.asCoachInput.weeks, 13)
    }

    func testHaeufigeresTrainingHebtDenAktivitaetsgrad() {
        let session = ChallengeSession.shared

        session.daysPerWeek = 3
        let wenig = session.biometrics.tdee

        session.daysPerWeek = 7
        let viel = session.biometrics.tdee

        XCTAssertGreaterThan(viel, wenig)
    }

    // MARK: - Übungsanzahl

    func testEinTagUnterFuenfUebungenWirdAufgefuellt() {
        let wenige = Array(PlanGenerator.buildPlan(
            categories: [.chest], count: 2, method: .standard, restTime: 60
        ).prefix(2))
        XCTAssertEqual(wenige.count, 2)

        let ergaenzt = PlanMapper.ensureExerciseCount(wenige, in: PlanMapper.challengeExerciseRange)
        XCTAssertGreaterThanOrEqual(ergaenzt.count, 5)
    }

    func testDieChallengeDeckeltErstBeiZwoelfUebungen() {
        let viele = PlanGenerator.buildPlan(
            categories: ExerciseDatabase.categories, count: 12, method: .standard, restTime: 60
        )
        let ergebnis = PlanMapper.ensureExerciseCount(viele, in: PlanMapper.challengeExerciseRange)
        XCTAssertLessThanOrEqual(ergebnis.count, 12)
        XCTAssertGreaterThan(ergebnis.count, 8, "die Challenge ist nach oben offener als der Coach")
    }

    func testDerCoachBleibtBeiSechsBisAcht() {
        let viele = PlanGenerator.buildPlan(
            categories: ExerciseDatabase.categories, count: 12, method: .standard, restTime: 60
        )
        let ergebnis = PlanMapper.ensureExerciseCount(viele, in: PlanMapper.coachExerciseRange)
        XCTAssertEqual(ergebnis.count, 8)
    }

    /*
      Aufgefüllt wird aus derselben Equipment-Klasse. Sonst bekäme ein
      Home-Plan eine Beinpresse, bloß weil eine Übung aus der Antwort des
      Servers hier keinen Treffer im Katalog fand.
    */
    func testAufgefuelltWirdMitPassendemEquipment() {
        guard let liegestuetze = ExerciseDatabase.all.first(where: { $0.name == "Liegestütze" }) else {
            return XCTFail("Liegestütze fehlen im Katalog")
        }
        let start = [ExerciseSlot(exercise: liegestuetze, sets: 3, reps: "15")]

        let ergaenzt = PlanMapper.ensureExerciseCount(start, in: PlanMapper.challengeExerciseRange)

        XCTAssertGreaterThanOrEqual(ergaenzt.count, 5)
        let ersteFuenf = ergaenzt.prefix(5)
        XCTAssertTrue(
            ersteFuenf.allSatisfy { $0.exercise.equipment == .bodyweight },
            "aufgefüllt wurde mit: " + ersteFuenf.map { "\($0.exercise.name) (\($0.exercise.equipment.rawValue))" }.joined(separator: ", ")
        )
    }

    // MARK: - Plan übernehmen

    func testEinNeuerPlanSetztDenFragebogenNichtZurueck() {
        let session = ChallengeSession.shared
        session.durationDays = 45
        session.sessionMinutes = 30
        session.goal = .loseWeight

        let plan = TrainingPlan(
            title: "Test", summary: "", weeks: 2,
            days: [], nutrition: nil, notes: [], language: "de"
        )
        session.apply(plan: plan, input: session.asCoachInput, language: "de")

        XCTAssertEqual(session.durationDays, 45)
        XCTAssertEqual(session.sessionMinutes, 30)
        XCTAssertEqual(session.goal, .loseWeight)
        XCTAssertNotNil(session.generatedPlan)

        session.resetPlan()
        XCTAssertNil(session.generatedPlan)
        XCTAssertEqual(session.durationDays, 45, "die Antworten bleiben für den zweiten Anlauf stehen")
    }

    /*
      Gesundheitsdaten (Art. 9 DSGVO) dürfen eine Kontolöschung nicht
      überleben, bloß weil sie im Fragebogen der Challenge liegen statt im
      Coach.
    */
    func testWipeLoeschtAuchDieKoerperdaten() {
        let session = ChallengeSession.shared
        session.age = 44
        session.heightCm = 191
        session.weightKg = 96
        session.goalWeightKg = 88
        session.sex = "female"

        /*
          Die Körperdaten liegen seit der Zusammenlegung der beiden Fragebögen
          im Profil, nicht mehr in der Sitzung. Gelöscht werden muss deshalb
          beides — genau das tut AuthService.wipeAllLocalData().
        */
        UserProfileStore.shared.wipe()
        session.wipe()

        let defaults = UserProfile()
        XCTAssertEqual(session.age, defaults.age)
        XCTAssertEqual(session.heightCm, defaults.heightCm)
        XCTAssertEqual(session.weightKg, defaults.weightKg)
        XCTAssertNil(session.goalWeightKg)
        XCTAssertEqual(session.sex, defaults.sex)
        XCTAssertNil(session.generatedPlan)
        XCTAssertNil(UserDefaults.standard.data(forKey: "kraftwuerfel:challengeSession"))
        XCTAssertNil(UserDefaults.standard.data(forKey: "kraftwuerfel:userProfile"))
    }
}

/*
  Die Kontolöschung muss beide Fragebögen erwischen, nicht nur den des
  KI-Coaches. Der Test steht bewusst getrennt: Er greift auf den globalen
  Zustand zu und darf die Fragebogen-Tests oben nicht stören.
*/
final class ChallengeDeletionTests: XCTestCase {

    func testDerChallengeSpeicherKenntEineLoeschung() {
        let store = ChallengeStore.shared
        store.durationDays = 60
        store.markTodayCompleted()
        XCTAssertGreaterThan(store.streak, 0)

        store.wipe()

        XCTAssertEqual(store.streak, 0)
        XCTAssertEqual(store.durationDays, 30)
        XCTAssertNil(UserDefaults.standard.data(forKey: "kraftwuerfel:challenge_progress"))
        XCTAssertNil(UserDefaults.standard.data(forKey: "kraftwuerfel:challenge_settings"))
    }
}
