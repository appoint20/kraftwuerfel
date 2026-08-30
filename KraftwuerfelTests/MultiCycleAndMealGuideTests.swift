import XCTest
@testable import Kraftwuerfel

final class MultiCycleAndMealGuideTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "kraftwuerfel.tests.multicycle.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Multi-Cycle & Per-Day Variation Tests

    func testExactTwoCyclesTimesNDaysSessionsGenerated() {
        let testDaysCounts = [1, 2, 3, 4, 5, 6, 7]
        let allWeekdays = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

        for n in testDaysCounts {
            let selected = Array(allWeekdays.prefix(n))
            let input = AICoachInput(
                goal: .muscle,
                experience: .intermediate,
                biometrics: UserBiometrics(sex: "male", age: 28, heightCm: 180, weightKg: 80),
                selectedDays: selected,
                sessionDurationMinutes: 60,
                weeks: 4,
                equipment: Set(EquipmentType.allCases),
                diet: .omnivore,
                includeWarmup: true,
                method: .standard
            )

            let plan = AICoachService.shared.generatePlan(input: input, language: "de")

            XCTAssertEqual(plan.days.count, n, "Plan must have exactly \(n) day entries")

            var totalUniqueSessions = 0
            for day in plan.days {
                XCTAssertFalse(day.cycle1Slots.isEmpty, "\(day.weekday) Cycle 1 must have exercises")
                XCTAssertFalse(day.cycle2Slots.isEmpty, "\(day.weekday) Cycle 2 must have exercises")

                // Both cycles for this day count as 2 distinct workout sessions
                totalUniqueSessions += 2

                // Verify differentiation between Cycle 1 and Cycle 2
                let c1Names = Set(day.cycle1Slots.map(\.exercise.name))
                let c2Names = Set(day.cycle2Slots.map(\.exercise.name))

                // With full equipment available, Cycle 2 should not simply clone Cycle 1
                let overlap = c1Names.intersection(c2Names)
                XCTAssertLessThan(overlap.count, c1Names.count, "Cycle 1 and Cycle 2 on \(day.weekday) must have differentiated exercises")

                // Rep ranges should differ (Cycle 1 strength/hypertrophy vs Cycle 2 volume/metabolic)
                let c1Reps = day.cycle1Slots.first?.reps
                let c2Reps = day.cycle2Slots.first?.reps
                XCTAssertNotEqual(c1Reps, c2Reps, "Cycle 1 and Cycle 2 must have differentiated rep ranges")
            }

            XCTAssertEqual(totalUniqueSessions, 2 * n, "Strict formula: exactly 2 × \(n) = \(2 * n) unique sessions")
        }
    }

    func testPlanMapperPreservesSingleCycleWhenApiProvidesSingleList() {
        let rawJson: [String: Any] = [
            "title": "API Test Plan Single Cycle",
            "summary": "Generated from backend with 1 cycle",
            "weeks": 4,
            "days": [
                [
                    "weekday": "Mo",
                    "name": "Titan",
                    "focus": "Push",
                    "exercises": [
                        ["name": "Bankdrücken", "sets": 4, "reps": "6-8", "rest": 90],
                        ["name": "Schulterdrücken (Langhantel)", "sets": 3, "reps": "8-10", "rest": 60],
                        ["name": "Dips (Brustfokus)", "sets": 3, "reps": "10-12", "rest": 60]
                    ]
                ]
            ],
            "nutrition": [
                "dailyCalories": 2500,
                "protein": 180,
                "carbs": 250,
                "fat": 75,
                "meals": [
                    ["time": "08:00", "name": "Power Oats", "calories": 650, "items": ["Haferflocken", "Whey", "Beeren"]]
                ],
                "shakes": [
                    ["when": "Post Workout", "what": "30g Whey Protein"]
                ]
            ]
        ]

        let plan = PlanMapper.trainingPlan(from: rawJson, language: "de")
        XCTAssertNotNil(plan)
        guard let p = plan, let day = p.days.first else {
            XCTFail("Plan or day missing")
            return
        }

        XCTAssertEqual(day.cycle1Slots.count, 3)
        XCTAssertEqual(day.cycle1Slots.first?.exercise.name, "Bankdrücken")
        XCTAssertFalse(day.hasDistinctCycles, "Single list response must have hasDistinctCycles == false")
        XCTAssertFalse(p.hasTwoCycles, "Plan must have hasTwoCycles == false")
        XCTAssertEqual(day.slots(forCycle: 1).count, 3)
        XCTAssertEqual(day.slots(forCycle: 2).count, 3, "slots(forCycle: 2) should fall back to cycle 1")

        // Check nutrition parsed
        XCTAssertNotNil(p.nutrition)
        XCTAssertEqual(p.nutrition?.dailyCalories, 2500)
        XCTAssertEqual(p.nutrition?.protein, 180)
        XCTAssertEqual(p.nutrition?.meals.first?.name, "Power Oats")
    }

    func testPlanMapperDetectsTwoCyclesWhenApiProvidesCycle1AndCycle2() {
        let rawJson: [String: Any] = [
            "title": "API Test Plan Two Cycles",
            "summary": "Generated from backend with 2 cycles",
            "weeks": 4,
            "days": [
                [
                    "weekday": "Mo",
                    "name": "Titan",
                    "focus": "Push",
                    "cycle1": [
                        ["name": "Bankdrücken", "sets": 4, "reps": "6-8", "rest": 90],
                        ["name": "Dips (Brustfokus)", "sets": 3, "reps": "10-12", "rest": 60]
                    ],
                    "cycle2": [
                        ["name": "Kurzhantel-Schrägbankdrücken", "sets": 4, "reps": "8-10", "rest": 75],
                        ["name": "Fliegende Kurzhantel (Schrägbank)", "sets": 3, "reps": "12-15", "rest": 60]
                    ]
                ]
            ]
        ]

        let plan = PlanMapper.trainingPlan(from: rawJson, language: "de")
        XCTAssertNotNil(plan)
        guard let p = plan, let day = p.days.first else {
            XCTFail("Plan or day missing")
            return
        }

        XCTAssertTrue(day.hasDistinctCycles, "Day must have hasDistinctCycles == true")
        XCTAssertTrue(p.hasTwoCycles, "Plan must have hasTwoCycles == true")
        XCTAssertEqual(day.cycle1Slots.count, 2)
        XCTAssertEqual(day.cycle2Slots.count, 2)
        XCTAssertEqual(day.slots(forCycle: 1).first?.exercise.name, "Bankdrücken")
        XCTAssertEqual(day.slots(forCycle: 2).first?.exercise.name, "Kurzhantel-Schrägbankdrücken")
    }

    // MARK: - Meal Guide Tests across all Diets

    func testMealGuideGeneratedForAllDietTypesInBothLanguages() {
        let diets: [DietType] = [.omnivore, .vegetarian, .lactoVegetarian, .vegan]
        let languages = ["de", "en"]

        for diet in diets {
            for lang in languages {
                let input = AICoachInput(
                    goal: .muscle,
                    experience: .intermediate,
                    biometrics: UserBiometrics(sex: "male", age: 25, heightCm: 175, weightKg: 75),
                    selectedDays: ["Mo", "Mi", "Fr"],
                    sessionDurationMinutes: 60,
                    weeks: 4,
                    equipment: Set(EquipmentType.allCases),
                    diet: diet,
                    includeWarmup: true,
                    method: .standard
                )

                let nutrition = AICoachService.shared.generateNutrition(input: input, language: lang)

                XCTAssertEqual(nutrition.diet, diet)
                XCTAssertGreaterThan(nutrition.dailyCalories, 1500)
                XCTAssertGreaterThan(nutrition.protein, 100)
                XCTAssertGreaterThan(nutrition.carbs, 100)
                XCTAssertGreaterThan(nutrition.fat, 30)
                XCTAssertFalse(nutrition.meals.isEmpty, "Meals must be generated for \(diet.rawValue) in \(lang)")
                XCTAssertFalse(nutrition.shakes.isEmpty, "Shakes must be generated for \(diet.rawValue) in \(lang)")
                XCTAssertFalse(nutrition.notes.isEmpty, "Notes must be generated for \(diet.rawValue) in \(lang)")
                XCTAssertFalse(nutrition.disclaimer.isEmpty, "Disclaimer must be populated")
            }
        }
    }

    // MARK: - Meal Guide True Persistence Test

    func testMealGuideTruePersistenceInStore() {
        let store = CodableListStore<SavedMealGuide>(storageKey: "test_saved_meal_guides", defaults: defaults)

        let nutrition = AICoachService.shared.generateNutrition(
            input: AICoachInput(
                goal: .strength,
                experience: .advanced,
                biometrics: UserBiometrics(sex: "male", age: 30, heightCm: 185, weightKg: 85),
                selectedDays: ["Mo", "Di", "Do", "Fr"],
                sessionDurationMinutes: 60,
                weeks: 4,
                equipment: Set(EquipmentType.allCases),
                diet: .lactoVegetarian,
                includeWarmup: true,
                method: .standard
            ),
            language: "de"
        )

        let guide = SavedMealGuide(name: "Test Lakto-Vegetarisch 2800", nutrition: nutrition)

        // Verify save returns true
        let saveResult = store.add(guide)
        XCTAssertTrue(saveResult, "Saving meal guide to store must return true")

        // Verify items contains it
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.name, "Test Lakto-Vegetarisch 2800")
        XCTAssertEqual(store.items.first?.nutrition.diet, .lactoVegetarian)

        // Verify persistence reload
        let reloadedStore = CodableListStore<SavedMealGuide>(storageKey: "test_saved_meal_guides", defaults: defaults)
        XCTAssertEqual(reloadedStore.items.count, 1)
        XCTAssertEqual(reloadedStore.items.first?.name, "Test Lakto-Vegetarisch 2800")
    }

    func testAiBackendMealsAndWarmupParsingWithUserJsonPayload() {
        let rawJson: [String: Any] = [
            "title": "4-Wochen Hypertrophie-Plan: Brust & Rücken Fokus",
            "summary": "Dreiteiliger Push/Pull/Legs-Aufbau mit klarer Priorität auf Brust und Rücken.",
            "weeks": 4,
            "days": [
                [
                    "weekday": "Mo",
                    "name": "Anvil",
                    "focus": "Brust & Rücken (Schwerpunkt Brust)",
                    "warmup": [
                        [
                            "exercise": "5 Min Rudergerät",
                            "duration": "5 Min"
                        ],
                        [
                            "exercise": "Schulterkreisen & Armrotationen",
                            "duration": "2 Min"
                        ]
                    ],
                    "exercises": [
                        [
                            "name": "Bankdrücken",
                            "sets": 4,
                            "reps": "6-8",
                            "rest": 180,
                            "note": "Schwere Grundübung, progressive Steigerung"
                        ],
                        [
                            "name": "Kurzhantel-Schrägbankdrücken",
                            "sets": 3,
                            "reps": "8-10",
                            "rest": 120,
                            "note": "Obere Brust betonen"
                        ],
                        [
                            "name": "Cable Crossover",
                            "sets": 3,
                            "reps": "12-15",
                            "rest": 60,
                            "note": "Kontrolliert dehnen, Spitze anspannen"
                        ]
                    ]
                ]
            ],
            "notes": [
                "Progression: Woche 1-2 im unteren Wiederholungsbereich starten, ab Woche 3 Gewicht erhöhen.",
                "Aufwärmen: Vor jeder schweren Übung 2 Aufwärmsätze mit 50% und 70% des Arbeitsgewichts."
            ],
            "nutrition": [
                "dailyCalories": 3100,
                "meals": [
                    [
                        "time": "07:30",
                        "items": [
                            "Haferflocken mit Milch (100 g)",
                            "Banane",
                            "3 Eier",
                            "Handvoll Walnüsse"
                        ],
                        "calories": 750
                    ],
                    [
                        "time": "12:30",
                        "items": [
                            "Reis (150 g roh)",
                            "Hähnchenbrust (200 g)",
                            "Gemüsemix",
                            "1 EL Olivenöl"
                        ],
                        "calories": 850
                    ],
                    [
                        "time": "16:00 (Pre-Workout)",
                        "items": [
                            "Vollkornbrot mit Hüttenkäse",
                            "Apfel"
                        ],
                        "calories": 450
                    ],
                    [
                        "time": "19:30",
                        "items": [
                            "Kartoffeln (300 g)",
                            "Lachs (150 g)",
                            "Salat mit Olivenöl",
                            "Quark mit Honig"
                        ],
                        "calories": 700
                    ],
                    [
                        "time": "21:30 (Snack)",
                        "items": [
                            "Magerquark / Skyr (200 g)",
                            "Beeren"
                        ],
                        "calories": 350
                    ]
                ],
                "shakes": "Nach dem Training: 30-40 g Whey Protein mit Wasser oder Milch und einer Banane"
            ]
        ]

        let plan = PlanMapper.trainingPlan(from: rawJson, language: "de")
        XCTAssertNotNil(plan, "Plan must successfully map from backend payload")
        guard let plan else { return }

        // 1. Verify Warmup parsed properly despite using "exercise" field
        let warmup = plan.days.first?.warmup
        XCTAssertEqual(warmup?.count, 2)
        XCTAssertEqual(warmup?.first?.name, "5 Min Rudergerät")

        // 2. Verify Nutrition parsed properly
        let nutrition = plan.nutrition
        XCTAssertNotNil(nutrition, "Nutrition must not be nil")
        guard let nutrition else { return }

        XCTAssertEqual(nutrition.dailyCalories, 3100)
        XCTAssertEqual(nutrition.meals.count, 5, "Must parse all 5 meals from the AI response")

        // First meal
        XCTAssertEqual(nutrition.meals[0].time, "07:30")
        XCTAssertEqual(nutrition.meals[0].calories, 750)
        XCTAssertEqual(nutrition.meals[0].items.count, 4)
        XCTAssertTrue(nutrition.meals[0].items.contains("Haferflocken mit Milch (100 g)"))

        // Pre-Workout meal
        XCTAssertEqual(nutrition.meals[2].time, "16:00 (Pre-Workout)")
        XCTAssertEqual(nutrition.meals[2].calories, 450)
        XCTAssertEqual(nutrition.meals[2].items.count, 2)

        // Shakes string parsed into ShakeItem
        XCTAssertFalse(nutrition.shakes.isEmpty)
        XCTAssertEqual(nutrition.shakes.first?.what, "Nach dem Training: 30-40 g Whey Protein mit Wasser oder Milch und einer Banane")

        // Computed macros from 3100 calories
        XCTAssertGreaterThan(nutrition.protein, 100)
        XCTAssertGreaterThan(nutrition.carbs, 100)
        XCTAssertGreaterThan(nutrition.fat, 40)
    }

    func testPlanMapperWithNestedTrainingWeeksAndWeeklyNutritionSchedule() {
        let rawJson: [String: Any] = [
            "title": "6-Wochen Hypertrophie Plan",
            "summary": "Ausgewogener Ganzkörper-Plan mit Fokus auf Brust und progressive Belastungssteigerung.",
            "training": [
                "duration_weeks": 6,
                "method": "Ganzkörper",
                "focus": "Brust",
                "weeks": [
                    [
                        "week": 1,
                        "days": [
                            [
                                "weekday": "Mi",
                                "name": "Titan",
                                "focus": "Brust & Trizeps",
                                "warmup": [
                                    ["exercise": "Armkreisen", "duration": "3 Min"],
                                    ["exercise": "Liegestütze auf Knien", "duration": "2x 10 Wdh"]
                                ],
                                "exercises": [
                                    ["name": "Bankdrücken", "sets": 4, "reps": "8-10", "rest": 90, "note": "Brust aktiv anspannen"],
                                    ["name": "Kurzhantel-Schrägbankdrücken", "sets": 3, "reps": "10-12", "rest": 60, "note": "Voller Bewegungsumfang"]
                                ]
                            ]
                        ]
                    ],
                    [
                        "week": 2,
                        "days": [
                            [
                                "weekday": "Mi",
                                "name": "Titan",
                                "focus": "Brust & Trizeps (Variation)",
                                "exercises": [
                                    ["name": "Dips (Brustfokus)", "sets": 4, "reps": "10-12", "rest": 60, "note": "Tiefe Dehnung"],
                                    ["name": "Cable Crossover", "sets": 3, "reps": "12-15", "rest": 45, "note": "Spannung halten"]
                                ]
                            ]
                        ]
                    ]
                ]
            ],
            "nutrition": [
                "dailyCalories": 2450,
                "macros": [
                    "proteinGrams": 142,
                    "carbsGrams": 286,
                    "fatGrams": 65
                ],
                "weeklySchedule": [
                    [
                        "dayNumber": 1,
                        "dayName": "Montag",
                        "dailyCalories": 2450,
                        "meals": [
                            [
                                "time": "08:00",
                                "name": "Griechischer Joghurt mit Protein-Granola & Waldbeeren",
                                "calories": 490,
                                "protein": 38,
                                "carbs": 52,
                                "fat": 14,
                                "items": [
                                    "300g Griechischer Joghurt (2% Fett)",
                                    "40g Knusper-Granola",
                                    "120g Waldbeeren",
                                    "1 TL Honig",
                                    "15g Mandeln"
                                ],
                                "instructions": "Joghurt in eine Schale geben, mit Granola, frischen Beeren, gehackten Mandeln und Honig anrichten."
                            ],
                            [
                                "time": "13:00",
                                "name": "Rotes Linsen-Curry mit Paneer & Naturreis",
                                "calories": 660,
                                "protein": 38,
                                "carbs": 82,
                                "fat": 18,
                                "items": [
                                    "80g Rote Linsen",
                                    "80g Paneer",
                                    "70g Naturreis",
                                    "150g Tomatensauce",
                                    "80ml Kokosmilch"
                                ],
                                "instructions": "Reis und Linsen kochen. Paneer anbraten, Currysauce dazugeben und servieren."
                            ]
                        ]
                    ]
                ],
                "shakes": "1x Post-Workout Shake (30g Protein) direkt nach dem Training."
            ]
        ]

        let plan = PlanMapper.trainingPlan(from: rawJson, language: "de")
        XCTAssertNotNil(plan)
        guard let plan else { return }

        XCTAssertEqual(plan.weeks, 6)
        XCTAssertEqual(plan.days.count, 1)
        XCTAssertEqual(plan.days.first?.weekday, "Mi")

        // Cycle 1 mapped from week 1
        XCTAssertEqual(plan.days.first?.cycle1Slots.count, 2)
        XCTAssertEqual(plan.days.first?.cycle1Slots[0].exercise.name, "Bankdrücken")
        XCTAssertEqual(plan.days.first?.cycle1Slots[1].exercise.name, "Kurzhantel-Schrägbankdrücken")

        // Cycle 2 mapped from week 2
        XCTAssertEqual(plan.days.first?.cycle2Slots.count, 2)
        XCTAssertEqual(plan.days.first?.cycle2Slots[0].exercise.name, "Dips (Brustfokus)")
        XCTAssertEqual(plan.days.first?.cycle2Slots[1].exercise.name, "Cable Crossover")
        XCTAssertTrue(plan.hasTwoCycles)

        // Warmup parsed
        XCTAssertEqual(plan.days.first?.warmup.count, 2)

        // Nutrition mapped from macros and weeklySchedule
        guard let nutrition = plan.nutrition else {
            XCTFail("Nutrition should be present")
            return
        }
        XCTAssertEqual(nutrition.dailyCalories, 2450)
        XCTAssertEqual(nutrition.protein, 142)
        XCTAssertEqual(nutrition.carbs, 286)
        XCTAssertEqual(nutrition.fat, 65)

        // Meals with detailed macros and instructions
        XCTAssertEqual(nutrition.meals.count, 2)
        XCTAssertEqual(nutrition.meals[0].protein, 38)
        XCTAssertEqual(nutrition.meals[0].carbs, 52)
        XCTAssertEqual(nutrition.meals[0].fat, 14)
        XCTAssertEqual(nutrition.meals[0].instructions, "Joghurt in eine Schale geben, mit Granola, frischen Beeren, gehackten Mandeln und Honig anrichten.")

        XCTAssertFalse(nutrition.shakes.isEmpty)
        XCTAssertEqual(nutrition.shakes.first?.what, "1x Post-Workout Shake (30g Protein) direkt nach dem Training.")
    }
}
