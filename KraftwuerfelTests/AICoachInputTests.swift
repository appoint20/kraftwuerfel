import XCTest
@testable import Kraftwuerfel

/*
  Zielgewicht und Trainingsmethode.

  Beide fehlten im Assistenten. Die Methode war dabei der stillere Fehler: Die
  App kennt sechs Satzschemata, der KI-Coach rechnete aber fest mit „Standard“
  — wer 5x4x3 wollte, bekam es im Generator und im KI-Plan nicht.

  Beim Zielgewicht geht es um mehr als eine Zahl im Formular: Es entscheidet
  über die Richtung des Kalorienrahmens und schlägt dabei die Zielkategorie.
*/
final class AICoachInputTests: XCTestCase {

    private func input(
        weight: Double = 80,
        goalWeight: Double? = nil,
        goal: TrainingGoal = .muscle,
        method: TrainingMethod = .standard,
        days: [String] = ["Mo", "Mi", "Fr"]
    ) -> AICoachInput {
        AICoachInput(
            goal: goal,
            experience: .intermediate,
            biometrics: UserBiometrics(sex: "male", age: 30, heightCm: 180, weightKg: weight),
            selectedDays: days,
            sessionDurationMinutes: 60,
            weeks: 4,
            equipment: Set(EquipmentType.allCases),
            diet: .omnivore,
            includeWarmup: true,
            goalWeightKg: goalWeight,
            method: method
        )
    }

    private func calories(_ i: AICoachInput) -> Int {
        AICoachService.shared.generatePlan(input: i, language: "de").nutrition?.dailyCalories ?? 0
    }

    // MARK: - Zielgewicht

    func testAbstandZumZiel() {
        XCTAssertNil(input().weightDelta, "ohne Ziel gibt es keinen Abstand")
        XCTAssertEqual(input(weight: 90, goalWeight: 80).weightDelta, -10)
        XCTAssertEqual(input(weight: 70, goalWeight: 78).weightDelta, 8)
    }

    /// Wer abnehmen will, bekommt ein Defizit — auch wenn als Ziel
    /// „Muskelaufbau“ dasteht. Die konkrete Angabe schlägt die Kategorie.
    func testZielgewichtSchlaegtDieZielkategorie() {
        let ohneZiel = calories(input(weight: 90, goal: .muscle))
        let abnehmen = calories(input(weight: 90, goalWeight: 80, goal: .muscle))

        XCTAssertLessThan(abnehmen, ohneZiel,
                          "Zielgewicht 80 bei 90 kg muss ein Defizit ergeben")
    }

    func testZunehmenErgibtEinenUeberschuss() {
        let ohneZiel = calories(input(weight: 70, goal: .weightLoss))
        let zunehmen = calories(input(weight: 70, goalWeight: 78, goal: .weightLoss))

        XCTAssertGreaterThan(zunehmen, ohneZiel)
    }

    /// Ein Ziel dicht am heutigen Gewicht ist kein Ziel — dann zählt wieder
    /// die Kategorie.
    func testZielNaheAmGewichtVerhaeltSichWieKeinZiel() {
        XCTAssertEqual(
            calories(input(weight: 80, goalWeight: 80.4, goal: .muscle)),
            calories(input(weight: 80, goal: .muscle))
        )
    }

    /// Der Abstand steuert die Größe des Schritts, aber gedeckelt: eine App
    /// ohne ärztliche Begleitung schlägt kein aggressives Defizit vor.
    func testGrosserAbstandGehtNichtUeber500Kilokalorien() {
        let basis = calories(input(weight: 100, goalWeight: 99.9, goal: .fitness))
        let weitWeg = calories(input(weight: 100, goalWeight: 60, goal: .fitness))

        XCTAssertEqual(basis - weitWeg, 500, "höchstens 500 kcal Abstand")
    }

    func testKleinerAbstandErgibtEinenKleinerenSchritt() {
        let basis = calories(input(weight: 80, goalWeight: 79.9, goal: .fitness))
        let nah = calories(input(weight: 80, goalWeight: 77, goal: .fitness))

        XCTAssertEqual(basis - nah, 300)
    }

    /// Untergrenze: Ein Zielgewicht weit unter dem heutigen darf nicht in eine
    /// Empfehlung laufen, die niemand essen sollte.
    func testKalorienFallenNieUnter1200() {
        let extrem = AICoachInput(
            goal: .weightLoss,
            experience: .beginner,
            biometrics: UserBiometrics(sex: "female", age: 60, heightCm: 150, weightKg: 45),
            selectedDays: ["Mo"],
            sessionDurationMinutes: 30,
            weeks: 2,
            equipment: Set(EquipmentType.allCases),
            diet: .vegan,
            goalWeightKg: 38
        )
        XCTAssertGreaterThanOrEqual(calories(extrem), 1200)
    }

    func testZielgewichtStehtInDenHinweisen() throws {
        let plan = AICoachService.shared.generatePlan(
            input: input(weight: 90, goalWeight: 80), language: "de"
        )
        let notes = try XCTUnwrap(plan.nutrition?.notes)
        XCTAssertTrue(notes.contains { $0.contains("80 kg") }, "\(notes)")

        let ohne = AICoachService.shared.generatePlan(input: input(), language: "de")
        let plainNotes = try XCTUnwrap(ohne.nutrition?.notes)
        XCTAssertFalse(plainNotes.contains { $0.contains("kg") })
    }

    // MARK: - Trainingsmethode

    /// 5x4x3 verteilt einen 5er- und einen 4er-Satz je Tag — vorher stand im
    /// KI-Plan überall dieselbe Satzzahl.
    func testFuenfVierDreiKommtImPlanAn() throws {
        for _ in 0..<20 {
            let plan = AICoachService.shared.generatePlan(
                input: input(method: .fiveFourThree), language: "de"
            )
            for day in plan.days {
                XCTAssertEqual(day.cycle1Slots.filter { $0.sets == 5 }.count, 1, day.weekday)
                XCTAssertEqual(day.cycle1Slots.filter { $0.sets == 4 }.count, 1, day.weekday)
            }
        }
    }

    func testVierVierDreiKommtImPlanAn() {
        for _ in 0..<20 {
            let plan = AICoachService.shared.generatePlan(
                input: input(method: .fourFourThree), language: "de"
            )
            for day in plan.days {
                XCTAssertEqual(day.cycle1Slots.filter { $0.sets == 4 }.count, 2, day.weekday)
            }
        }
    }

    /// Bei „Standard“ gilt weiter die Erfahrungsregel.
    func testStandardBehaeltDieErfahrungsregel() {
        var advanced = input(method: .standard)
        advanced.experience = .advanced
        let plan = AICoachService.shared.generatePlan(input: advanced, language: "de")
        XCTAssertTrue(plan.days.allSatisfy { $0.cycle1Slots.allSatisfy { $0.sets == 4 } })

        let beginner = AICoachService.shared.generatePlan(input: input(), language: "de")
        XCTAssertTrue(beginner.days.allSatisfy { $0.cycle1Slots.allSatisfy { $0.sets == 3 } })
    }

    func testFokusMethodeZiehtDieFokusGruppeInDenPlan() {
        for _ in 0..<10 {
            let plan = AICoachService.shared.generatePlan(
                input: input(method: .legsFocus, days: ["Mo", "Mi", "Fr"]), language: "de"
            )
            let legs = plan.days[0].cycle1Slots
                .filter { $0.exercise.categories.contains(.legs) }
            XCTAssertGreaterThanOrEqual(legs.count, PlanGenerator.focusMinCount)
        }
    }

    // MARK: - Beides überlebt Speichern und Sprachwechsel

    func testEingabenUeberlebenDenRoundTrip() throws {
        let original = input(weight: 92, goalWeight: 84, method: .fourFourThree)
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(AICoachInput.self, from: data)

        XCTAssertEqual(restored.goalWeightKg, 84)
        XCTAssertEqual(restored.method, .fourFourThree)
        XCTAssertEqual(restored.weightDelta, -8)
    }

    func testSprachwechselBehaeltDasSatzschema() throws {
        let i = input(method: .fiveFourThree)
        let german = AICoachService.shared.generatePlan(input: i, language: "de")
        let english = AICoachService.shared.relocalize(german, input: i, language: "en")

        for (before, after) in zip(german.days, english.days) {
            XCTAssertEqual(after.cycle1Slots.map(\.sets), before.cycle1Slots.map(\.sets))
        }
    }

    // MARK: - Neue Biometrie, BMI, BMR & Calisthenics Metriken

    func testBMICalculationAndCategories() {
        let bioNormal = UserBiometrics(sex: "male", age: 34, heightCm: 174, weightKg: 59)
        // 59 / (1.74 * 1.74) = 19.487...
        XCTAssertEqual(bioNormal.bmi, 59.0 / (1.74 * 1.74), accuracy: 0.01)
        XCTAssertEqual(bioNormal.bmiCategory, .normal)

        let bioUnder = UserBiometrics(sex: "female", age: 22, heightCm: 175, weightKg: 50)
        XCTAssertEqual(bioUnder.bmiCategory, .underweight)

        let bioOver = UserBiometrics(sex: "male", age: 40, heightCm: 175, weightKg: 85)
        XCTAssertEqual(bioOver.bmiCategory, .overweight)

        let bioObese = UserBiometrics(sex: "male", age: 45, heightCm: 170, weightKg: 100)
        XCTAssertEqual(bioObese.bmiCategory, .obese)
    }

    func testBMRAndTDEEMetabolismCalculations() {
        // Mifflin-St Jeor: (10 * 80) + (6.25 * 180) - (5 * 30) + 5 = 800 + 1125 - 150 + 5 = 1780
        let bio = UserBiometrics(
            sex: "male", age: 30, heightCm: 180, weightKg: 80,
            somatotype: .mesomorph, activityLevel: .moderatelyActive
        )
        XCTAssertEqual(bio.bmr, 1780)
        // TDEE: 1780 * 1.55 = 2759
        XCTAssertEqual(bio.tdee, Int((1780.0 * 1.55).rounded()))

        // Ziel-Kalorien für Muskelaufbau
        let targetCals = bio.targetCalories(for: .muscle)
        XCTAssertGreaterThan(targetCals, bio.tdee)
    }

    func testSomatotypeAndCalisthenicsRoundtrip() throws {
        let input = AICoachInput(
            goal: .muscle,
            experience: .intermediate,
            biometrics: UserBiometrics(
                sex: "male", age: 28, heightCm: 180, weightKg: 78,
                somatotype: .ectomorph, activityLevel: .veryActive
            ),
            pushupLevel: .advanced,
            pullupLevel: .advanced,
            plankLevel: .under120s,
            trainingLocation: .outdoorPark
        )

        let data = try JSONEncoder().encode(input)
        let decoded = try JSONDecoder().decode(AICoachInput.self, from: data)

        XCTAssertEqual(decoded.biometrics.somatotype, .ectomorph)
        XCTAssertEqual(decoded.biometrics.activityLevel, .veryActive)
        XCTAssertEqual(decoded.pushupLevel, .advanced)
        XCTAssertEqual(decoded.pullupLevel, .advanced)
        XCTAssertEqual(decoded.plankLevel, .under120s)
        XCTAssertEqual(decoded.trainingLocation, .outdoorPark)
    }

    func testInterviewAnswersReachTheCoachRequest() throws {
        var profile = UserProfile()
        profile.sex = "female"
        profile.experience = .beginner
        profile.selectedDays = ["Sa"]
        profile.durationMinutes = 30
        profile.restSeconds = 45
        profile.trainingLocation = .homeBodyweight
        profile.equipment = [.bodyweight]
        profile.pushupLevel = .beginner
        profile.pullupLevel = .none
        profile.plankLevel = .under30s
        profile.limitations = "Empfindliche Knie, keine Sprünge"

        let request = profile.coachPlanRequest(language: "de")
        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["limitations"] as? String, profile.limitations)
        XCTAssertEqual(json["sex"] as? String, "female")
        XCTAssertEqual(json["experience"] as? String, "beginner")
        XCTAssertEqual(json["days"] as? [String], ["Sa"])
        XCTAssertEqual(json["sessionMinutes"] as? Int, 30)
        XCTAssertEqual(json["equipment"] as? [String], [EquipmentType.bodyweight.rawValue])
        XCTAssertEqual(json["pushupLevel"] as? String, "0-5")
        XCTAssertEqual(json["pullupLevel"] as? String, "0")
        XCTAssertEqual(json["plankLevel"] as? String, "<30s")
        XCTAssertEqual(profile.coachInput.limitations, profile.limitations)
        XCTAssertEqual(profile.coachInput.selectedDays, request.days)
    }

    func testCoachRequestCannotSendGymEquipmentForThePark() {
        var profile = UserProfile()
        profile.trainingLocation = .outdoorPark
        profile.equipment = [.machine]
        XCTAssertEqual(profile.coachPlanRequest(language: "de").equipment, [EquipmentType.bodyweight.rawValue])
        XCTAssertEqual(profile.coachInput.equipment, [.bodyweight])
    }

    func testOldSavedCoachInputsRemainReadableWithoutLimitations() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(input())) as? [String: Any])
        json.removeValue(forKey: "limitations")
        let data = try JSONSerialization.data(withJSONObject: json)
        let restored = try JSONDecoder().decode(AICoachInput.self, from: data)
        XCTAssertNil(restored.limitations)
        XCTAssertEqual(restored.selectedDays, ["Mo", "Mi", "Fr"])
    }

    func testOneDayBeginnerLocalPlanHonorsCapacityWithoutUsingSexAsDifficulty() {
        for sex in ["female", "male"] {
            var profile = UserProfile()
            profile.sex = sex
            profile.experience = .beginner
            profile.selectedDays = ["Sa"]
            profile.durationMinutes = 30
            profile.restSeconds = 45
            profile.pushupLevel = .beginner
            profile.pullupLevel = .none
            profile.plankLevel = .under30s
            profile.method = .fiveFourThree
            for _ in 0..<20 {
                let plan = AICoachService.shared.generatePlan(input: profile.coachInput)
                XCTAssertEqual(plan.days.map(\.weekday), ["Sa"])
                for day in plan.days {
                    for slots in [day.cycle1Slots, day.cycle2Slots] {
                        XCTAssertFalse(slots.isEmpty)
                        XCTAssertLessThanOrEqual(slots.count, 5)
                        XCTAssertTrue(slots.allSatisfy { !$0.exercise.isHeavy && $0.sets == 2 && $0.restSeconds <= 45 })
                        XCTAssertFalse(slots.contains { ["Liegestütze", "Klimmzüge", "Dips (Brustfokus)", "Ab Wheel Rollout"].contains($0.exercise.name) })
                    }
                }
            }
        }
    }

    func testSparseLocalEquipmentNeverExpandsToUnavailableMachines() {
        var profile = UserProfile()
        profile.experience = .beginner
        profile.selectedDays = ["Mo"]
        profile.trainingLocation = .homeBodyweight
        profile.equipment = [.weightPlate]
        let plan = AICoachService.shared.generatePlan(input: profile.coachInput)
        for day in plan.days {
            XCTAssertTrue((day.cycle1Slots + day.cycle2Slots).allSatisfy { $0.exercise.equipment == .weightPlate })
        }
    }

    func testCoachErrorMessagesDistinguishServerFailureFromOfflineAndHideDiagnostics() {
        let failure = KraftAPI.APIError.upstream("HTTP 502: secret-key-123 <html>provider stack trace</html>").coachMessage(language: "de")
        XCTAssertTrue(failure.contains("Server"))
        XCTAssertFalse(failure.contains("Verbindung"))
        XCTAssertFalse(failure.contains("secret-key-123"))
        XCTAssertFalse(failure.contains("<html>"))
        let configuration = KraftAPI.APIError.upstream("API-Schlüssel ist nicht konfiguriert.").coachMessage(language: "de")
        XCTAssertTrue(configuration.contains("eingerichtet"))
        let transport = KraftAPI.APIError.transport("network dropped").coachMessage(language: "de")
        XCTAssertTrue(transport.contains("Verbindung"))
        let providerQuota = KraftAPI.APIError.upstream("OpenRouter antwortete 429").coachMessage(language: "de")
        XCTAssertTrue(providerQuota.contains("ausgelastet"))
        XCTAssertFalse(providerQuota.contains("Planlimit"))
    }

    func testShortLocalSessionsFitIncludingWarmupWorkRestAndSetup() {
        for minutes in [10, 15] {
            var profile = UserProfile()
            profile.experience = .beginner
            profile.selectedDays = ["Mo"]
            profile.durationMinutes = minutes
            profile.restSeconds = 120
            profile.trainingLocation = .homeBodyweight
            profile.equipment = [.bodyweight]
            for _ in 0..<20 {
                let plan = AICoachService.shared.generatePlan(input: profile.coachInput)
                for day in plan.days {
                    XCTAssertEqual(day.warmup.map(\.duration), ["2 min"])
                    XCTAssertFalse(day.warmup.contains { $0.name.contains("Laufband") || $0.name.contains("Rudergerät") || $0.name.contains("Band") })
                    for slots in [day.cycle1Slots, day.cycle2Slots] {
                        XCTAssertFalse(slots.isEmpty)
                        // Every exercise allows at most 12 repetitions or 30s
                        // of holding, so 48 seconds per set is an upper bound.
                        let seconds = 120 + slots.reduce(0) {
                            $0 + $1.sets * 48 + max(0, $1.sets - 1) * $1.restSeconds + 60
                        }
                        XCTAssertLessThanOrEqual(seconds, minutes * 60)
                        XCTAssertTrue(slots.allSatisfy { $0.sets == 2 && $0.exercise.equipment == .bodyweight })
                    }
                }
            }
        }
    }

    func testOnceWeeklyIntermediateAlsoStartsConservatively() {
        var profile = UserProfile()
        profile.experience = .intermediate
        profile.selectedDays = ["Sa"]
        profile.durationMinutes = 30
        profile.method = .fiveFourThree
        for _ in 0..<20 {
            let plan = AICoachService.shared.generatePlan(input: profile.coachInput)
            XCTAssertEqual(plan.days.map(\.weekday), ["Sa"])
            for day in plan.days {
                XCTAssertEqual(day.warmup.map(\.duration), ["3 min"])
                XCTAssertTrue((day.cycle1Slots + day.cycle2Slots).allSatisfy {
                    !$0.exercise.isHeavy && $0.sets == 2 && ($0.reps == "8-12" || $0.exercise.name.contains("Plank"))
                })
            }
        }
    }

    func testRecognizedRestrictionsReduceLocalSelectionAndLoad() {
        let cases: [(String, [String])] = [
            ("Knieprobleme", ["squat", "kniebeugen", "ausfallschritt", "step-up", "beinpresse", "mountain climbers"]),
            ("Rückenbeschwerden", ["kreuzheben", "good mornings", "vorgebeugt", "t-bar", "hyperextensions", "russian twists", "sit-ups"]),
            ("Shoulder pain", ["drücken", "press", "dips", "liegestütze", "frontheben", "pullover"]),
            ("Bitte vorsichtig beginnen", []),
        ]
        for (limitation, excluded) in cases {
            var profile = UserProfile()
            profile.experience = .advanced
            profile.selectedDays = ["Mo", "Mi", "Fr"]
            profile.limitations = limitation
            for _ in 0..<20 {
                let plan = AICoachService.shared.generatePlan(input: profile.coachInput)
                XCTAssertTrue(plan.notes.contains { $0.contains("keine Verletzung") })
                for day in plan.days {
                    for slot in day.cycle1Slots + day.cycle2Slots {
                        XCTAssertFalse(slot.exercise.isHeavy)
                        XCTAssertEqual(slot.sets, 2)
                        let name = (slot.exercise.name + " " + slot.exercise.nameEn).lowercased()
                        XCTAssertFalse(excluded.contains { name.contains($0) }, "\(limitation): \(slot.exercise.name)")
                    }
                }
            }
        }
    }
}
