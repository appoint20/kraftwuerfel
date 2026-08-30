import Foundation

/*
  Lokale Plan- und Ernährungsberechnung für den KI-Coach.

  Wird aufgerufen:
  1. Als Standard/Fallback, wenn der Nutzer offline ist oder kein Konto hat
  2. Zur Erzeugung und Relokalisierung des Meal Guides
  3. Zur Generierung von 2 Zyklen × N Tagen differenzierter Trainingseinheiten
*/
public final class AICoachService {
    public static let shared = AICoachService()

    private init() {}

    // MARK: - Öffentliche Schnittstelle

    public func generatePlan(input: AICoachInput, language: String = "de") -> TrainingPlan {
        let isEn = language == "en"

        // 1. Ernährungsplan berechnen
        let nutrition = generateNutrition(input: input, language: language)

        // 2. Tagespläne für 2 Zyklen × N Tage generieren
        let dayNamesDe = ["Titan", "Vulkan", "Olymp", "Gipfel", "Atlas", "Komet", "Phönix"]
        let dayNamesEn = ["Titan", "Vulcan", "Olympus", "Summit", "Atlas", "Comet", "Phoenix"]

        var generatedDays: [DayPlan] = []
        let selectedCount = input.selectedDays.count

        for (index, day) in input.selectedDays.enumerated() {
            let dayName = isEn ? dayNamesEn[index % dayNamesEn.count] : dayNamesDe[index % dayNamesDe.count]

            // Ziel-Muskelgruppen und Fokus pro Tag differenzieren
            let (focusDe, focusEn, targetMuscles) = splitForDay(index: index, totalDays: selectedCount)

            // Warmup
            var warmup: [WarmupExercise] = []
            if input.includeWarmup {
                warmup = isEn ? [
                    WarmupExercise(name: "5 min Light Cardio (Rowing/Treadmill)", duration: "5 min"),
                    WarmupExercise(name: "Dynamic Mobility & Band Pull-Aparts", duration: "3 min")
                ] : [
                    WarmupExercise(name: "5 min Leichtes Cardio (Rudergerät/Laufband)", duration: "5 min"),
                    WarmupExercise(name: "Dynamisches Dehnen & Schultermobilität", duration: "3 min")
                ]
            }

            // Satz- und Wiederholungsschemata differenziert pro Zyklus
            let baseSets = input.experience == .advanced ? 4 : 3
            let repsC1: String
            let repsC2: String
            let restC1: Int
            let restC2: Int

            switch input.goal {
            case .strength:
                repsC1 = "4-6"
                repsC2 = "6-8"
                restC1 = 120
                restC2 = 90
            case .muscle:
                repsC1 = "6-10"
                repsC2 = "10-14"
                restC1 = 90
                restC2 = 60
            case .definition, .weightLoss:
                repsC1 = "8-12"
                repsC2 = "12-15"
                restC1 = 60
                restC2 = 45
            case .fitness:
                repsC1 = "8-12"
                repsC2 = "10-12"
                restC1 = 75
                restC2 = 60
            }

            // Übungsanzahl strikt 6 bis 8 Übungen pro Trainingstag
            let count = max(6, min(8, max(6, input.sessionDurationMinutes / 8)))

            let effectiveEquipment: Set<EquipmentType> = {
                let allowed = AICoachSession.allowedEquipment(for: input.trainingLocation)
                return input.equipment.isEmpty ? allowed : input.equipment.intersection(allowed)
            }()

            // Zyklus 1: Grundübungen & Kraftaufbau
            let cycle1 = PlanGenerator.buildPlan(
                categories: targetMuscles,
                count: count,
                method: input.method,
                restTime: restC1,
                equipment: effectiveEquipment
            )
            let usedInCycle1 = Set(cycle1.map(\.exercise.name))

            // Zyklus 2: Differenzierte Übungsvariationen & Hypertrophie
            let cycle2 = PlanGenerator.buildPlan(
                categories: targetMuscles,
                count: count,
                method: input.method,
                restTime: restC2,
                extraExclude: usedInCycle1,
                equipment: effectiveEquipment
            )

            func setsFor(_ slot: ExerciseSlot) -> Int {
                input.method == .standard ? baseSets : slot.sets
            }

            let cycle1Slots = cycle1.map {
                ExerciseSlot(exercise: $0.exercise, sets: setsFor($0), reps: repsC1, restSeconds: restC1)
            }
            let cycle2Slots = cycle2.map {
                ExerciseSlot(exercise: $0.exercise, sets: setsFor($0), reps: repsC2, restSeconds: restC2)
            }

            generatedDays.append(DayPlan(
                weekday: day,
                name: dayName,
                focus: isEn ? focusEn : focusDe,
                warmup: warmup,
                cycle1Slots: cycle1Slots,
                cycle2Slots: cycle2Slots
            ))
        }

        let planTitle = isEn
            ? "AI Hypertrophy & Performance Program"
            : "KI Hypertrophie & Performance Plan"

        let planSummary = isEn
            ? "Individually periodized across \(input.selectedDays.count) training days per week with 2 rotating progression cycles."
            : "Individuell periodisiert für \(input.selectedDays.count) Trainingstage pro Woche mit 2 rotierenden Progressions-Zyklen."

        return TrainingPlan(
            title: planTitle,
            summary: planSummary,
            weeks: input.weeks,
            days: generatedDays,
            nutrition: nutrition,
            notes: isEn ? [
                "Cycle 1 focuses on strength & heavy compound loading. Cycle 2 focuses on volume & hypertrophy.",
                "Alternate between Cycle 1 and Cycle 2 each week for optimal progressive overload.",
                "Ensure 7-8 hours of quality sleep for peak muscle protein synthesis."
            ] : [
                "Zyklus 1 fokussiert Grundkraft und schwere Lasten. Zyklus 2 setzt auf Volumen und Hypertrophie.",
                "Wechsle wöchentlich zwischen Zyklus 1 und Zyklus 2 für optimale Progression.",
                "Achte auf 7–8 Stunden Schlaf für beste Muskelregeneration."
            ],
            language: language
        )
    }

    // MARK: - Ernährungsplan-Generator

    public func generateNutrition(input: AICoachInput, language: String = "de") -> NutritionPlan {
        let isEn = language == "en"
        let weight = input.biometrics.weightKg

        // BMR & TDEE & Ziel-Kalorienberechnung über UserBiometrics
        var tdee = input.biometrics.targetCalories(for: input.goal, goalWeightKg: input.goalWeightKg)

        // Somatotyp-Feinabstimmung (Ektomorph: +150 kcal für schnellen Stoffwechsel / Endomorph: -100 kcal)
        switch input.biometrics.somatotype {
        case .ectomorph:
            if input.goal == .muscle || input.goal == .strength { tdee += 150 }
        case .endomorph:
            if input.goal == .weightLoss || input.goal == .definition { tdee -= 100 }
        case .mesomorph:
            break
        }

        tdee = max(1200, tdee)

        // Makronährstoffe
        let proteinPerKg: Double = input.goal == .muscle || input.goal == .definition ? 2.0 : 1.6
        let proteinGrams = Int(weight * proteinPerKg)
        let fatGrams = Int(weight * 0.9)
        let remainingCalories = max(tdee - (proteinGrams * 4 + fatGrams * 9), 400)
        let carbGrams = remainingCalories / 4

        let dayNamesDe = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
        let dayNamesEn = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

        // 7 komplett individuelle Tage ohne Mahlzeiten-Wiederholungen innerhalb der Woche
        let weeklySchedule: [NutritionDaySchedule] = (0..<7).map { dayIdx in
            let dailyMeals = generateMealsForDay(diet: input.diet, dayIndex: dayIdx, totalCalories: tdee, language: language)
            return NutritionDaySchedule(
                dayNumber: dayIdx + 1,
                dayName: isEn ? dayNamesEn[dayIdx] : dayNamesDe[dayIdx],
                dailyCalories: tdee,
                protein: proteinGrams,
                carbs: carbGrams,
                fat: fatGrams,
                meals: dailyMeals
            )
        }
        let shakes = generateShakes(diet: input.diet, language: language)

        return NutritionPlan(
            diet: input.diet,
            dailyCalories: tdee,
            protein: proteinGrams,
            carbs: carbGrams,
            fat: fatGrams,
            weeklySchedule: weeklySchedule,
            meals: weeklySchedule.first?.meals ?? [],
            shakes: shakes,
            notes: {
                var notes = isEn
                    ? ["Drink at least 3-4 liters of water daily",
                       "Distribute ~30g protein evenly every 3-4 hours"]
                    : ["Trinke täglich mindestens 3–4 Liter Wasser",
                       "Verteile dein Eiweiß gleichmäßig alle 3–4 Stunden"]
                if let goal = input.goalWeightKg, let delta = input.weightDelta, abs(delta) >= 1 {
                    let target = Int(goal.rounded())
                    notes.insert(
                        isEn
                            ? (delta > 0
                               ? "Calculated as a surplus towards \(target) kg (~0.25–0.5 kg per week)."
                               : "Calculated as a deficit towards \(target) kg (~0.25–0.5 kg per week).")
                            : (delta > 0
                               ? "Auf einen Überschuss Richtung \(target) kg gerechnet (~0,25–0,5 kg pro Woche)."
                               : "Auf ein Defizit Richtung \(target) kg gerechnet (~0,25–0,5 kg pro Woche)."),
                        at: 0
                    )
                }
                return notes
            }(),
            disclaimer: isEn
                ? "Nutritional values are scientifically estimated reference values for healthy adults."
                : "Nährwertangaben sind wissenschaftlich berechnete Richtwerte für gesunde Erwachsene."
        )
    }

    // MARK: - Split-Zuweisung pro Tag

    private func splitForDay(index: Int, totalDays: Int) -> (focusDe: String, focusEn: String, categories: [MuscleCategory]) {
        switch totalDays {
        case 1:
            return (
                "Ganzkörper & Grundkraft",
                "Full Body & Foundation",
                [.chest, .back, .legs, .shoulders, .core]
            )
        case 2:
            if index == 0 {
                return (
                    "Oberkörper & Core",
                    "Upper Body & Core",
                    [.chest, .back, .shoulders, .biceps, .triceps, .core]
                )
            } else {
                return (
                    "Unterkörper & Stabilität",
                    "Lower Body & Stability",
                    [.legs, .glutes, .calves, .core]
                )
            }
        case 3:
            if index == 0 {
                return (
                    "Push (Brust, Schultern, Trizeps)",
                    "Push (Chest, Shoulders, Triceps)",
                    [.chest, .shoulders, .triceps]
                )
            } else if index == 1 {
                return (
                    "Pull (Rücken, Bizeps)",
                    "Pull (Back, Biceps)",
                    [.back, .biceps]
                )
            } else {
                return (
                    "Beine & Core",
                    "Legs & Core",
                    [.legs, .glutes, .calves, .core]
                )
            }
        case 4:
            switch index {
            case 0:
                return (
                    "Oberkörper A (Brust & Rücken Fokus)",
                    "Upper Body A (Chest & Back Focus)",
                    [.chest, .back, .shoulders]
                )
            case 1:
                return (
                    "Unterkörper A (Quads & Glutes)",
                    "Lower Body A (Quads & Glutes)",
                    [.legs, .glutes, .calves]
                )
            case 2:
                return (
                    "Oberkörper B (Arme & Schultern)",
                    "Upper Body B (Arms & Shoulders)",
                    [.shoulders, .biceps, .triceps, .chest]
                )
            default:
                return (
                    "Unterkörper B (Hamstrings & Core)",
                    "Lower Body B (Hamstrings & Core)",
                    [.legs, .glutes, .core]
                )
            }
        case 5:
            switch index {
            case 0:
                return ("Brust & Trizeps", "Chest & Triceps", [.chest, .triceps])
            case 1:
                return ("Rücken & Bizeps", "Back & Biceps", [.back, .biceps])
            case 2:
                return ("Beine & Waden", "Legs & Calves", [.legs, .glutes, .calves])
            case 3:
                return ("Schultern & Nacken", "Shoulders & Traps", [.shoulders, .core])
            default:
                return ("Arme & Rumpf", "Arms & Core", [.biceps, .triceps, .core, .chest])
            }
        case 6:
            switch index {
            case 0:
                return ("Push A (Schwer)", "Push A (Heavy)", [.chest, .shoulders, .triceps])
            case 1:
                return ("Pull A (Schwer)", "Pull A (Heavy)", [.back, .biceps])
            case 2:
                return ("Legs A (Quads Fokus)", "Legs A (Quads Focus)", [.legs, .glutes, .calves])
            case 3:
                return ("Push B (Hypertrophie)", "Push B (Hypertrophy)", [.chest, .shoulders, .triceps])
            case 4:
                return ("Pull B (Hypertrophie)", "Pull B (Hypertrophy)", [.back, .biceps])
            default:
                return ("Legs B (Posterior & Core)", "Legs B (Posterior & Core)", [.legs, .glutes, .core])
            }
        default: // 7 Tage
            switch index {
            case 0:
                return ("Brust Fokus", "Chest Focus", [.chest, .triceps])
            case 1:
                return ("Rücken Fokus", "Back Focus", [.back, .biceps])
            case 2:
                return ("Quads & Waden", "Quads & Calves", [.legs, .calves])
            case 3:
                return ("Schultern & Core", "Shoulders & Core", [.shoulders, .core])
            case 4:
                return ("Hamstrings & Gesäß", "Hamstrings & Glutes", [.legs, .glutes])
            case 5:
                return ("Arme (Bizeps & Trizeps)", "Arms (Biceps & Triceps)", [.biceps, .triceps])
            default:
                return ("Ganzkörper & Stabilität", "Full Body & Mobility", [.chest, .back, .legs, .core])
            }
        }
    }

    // MARK: - Relokalisierung

    public func relocalize(
        _ plan: TrainingPlan,
        input: AICoachInput,
        language: String
    ) -> TrainingPlan {
        guard plan.language != language else { return plan }

        let fresh = generatePlan(input: input, language: language)
        let previousDays = Dictionary(
            plan.days.map { ($0.weekday, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let days: [DayPlan] = fresh.days.map { day in
            guard let previous = previousDays[day.weekday] else { return day }
            return DayPlan(
                weekday: day.weekday,
                name: day.name,
                focus: day.focus,
                warmup: day.warmup,
                cycle1Slots: previous.cycle1Slots,
                cycle2Slots: previous.cycle2Slots
            )
        }

        return TrainingPlan(
            id: plan.id,
            title: fresh.title,
            summary: fresh.summary,
            weeks: fresh.weeks,
            days: days,
            nutrition: fresh.nutrition,
            notes: fresh.notes,
            createdAt: plan.createdAt,
            language: language
        )
    }

    // MARK: - Mahlzeiten-Vorlagen für 7 Tage ohne Wiederholungen

    private func generateMealsForDay(diet: DietType, dayIndex: Int, totalCalories: Int, language: String) -> [MealItem] {
        let isEn = language == "en"
        let day = dayIndex % 7
        let cBreakfast = totalCalories / 4
        let cLunch = Int(Double(totalCalories) * 0.35)
        let cSnack = totalCalories / 6
        let cDinner = Int(Double(totalCalories) * 0.3)

        switch diet {
        case .lactoVegetarian:
            let plansEn: [[MealItem]] = [
                [
                    MealItem(time: "08:00", name: "High-Protein Power Oats", calories: cBreakfast, items: ["80g Rolled Oats", "250g Quark / Greek Yogurt", "30g Whey Protein", "Handful Blueberries & Walnuts"]),
                    MealItem(time: "12:30", name: "Paneer & Lentil Power Bowl", calories: cLunch, items: ["150g Paneer (grilled)", "100g Basmati Rice", "150g Lentil Dal", "Spinach & Cucumber Salad"]),
                    MealItem(time: "16:00", name: "Pre-Workout Banana Quark", calories: cSnack, items: ["1 Banana", "150g Low-fat Quark with Cinnamon", "1 Rice Cake"]),
                    MealItem(time: "19:30", name: "Cottage Cheese & Quinoa Bowl", calories: cDinner, items: ["200g Cottage Cheese (Hüttenkäse)", "100g Quinoa", "Steamed Broccoli & Sweet Potatoes", "1 tbsp Olive Oil"])
                ],
                [
                    MealItem(time: "08:00", name: "Protein Berry Quark Bowl", calories: cBreakfast, items: ["250g Low-fat Quark", "40g Rolled Oats", "100g Mixed Berries", "20g Crushed Almonds"]),
                    MealItem(time: "12:30", name: "Chickpea & Halloumi Bowl", calories: cLunch, items: ["200g Chickpeas", "80g Light Halloumi", "150g Sweet Potatoes", "Mixed Greens & Tahini"]),
                    MealItem(time: "16:00", name: "Greek Yogurt & Honey Rice Cakes", calories: cSnack, items: ["200g Greek Yogurt 0%", "2 Rice Cakes", "1 tsp Honey", "Cinnamon"]),
                    MealItem(time: "19:30", name: "Lentil Pasta with Ricotta", calories: cDinner, items: ["100g Red Lentil Pasta", "100g Ricotta", "Tomato Basil Sugo", "Zucchini & Bell Peppers"])
                ],
                [
                    MealItem(time: "08:00", name: "Almond Milk Porridge & Seeds", calories: cBreakfast, items: ["70g Rolled Oats", "250ml Almond Milk", "30g Whey Protein", "1 tbsp Chia & Flaxseeds"]),
                    MealItem(time: "12:30", name: "Tofu & Paneer Curry with Brown Rice", calories: cLunch, items: ["120g Paneer", "100g Smoked Tofu", "100g Brown Rice", "Steamed Cauliflower & Peas"]),
                    MealItem(time: "16:00", name: "Apple & Protein Cottage Cup", calories: cSnack, items: ["1 Crisp Apple", "150g Cottage Cheese", "10g Pumpkin Seeds"]),
                    MealItem(time: "19:30", name: "Spinach Dal with Spelt Naan", calories: cDinner, items: ["200g Yellow Lentil Dal", "Fresh Spinach", "1 Whole Spelt Flatbread", "100g Greek Yogurt Raita"])
                ],
                [
                    MealItem(time: "08:00", name: "Cottage Cheese Protein Pancakes", calories: cBreakfast, items: ["150g Cottage Cheese", "60g Oat Flour", "2 Egg Whites / 50ml Milk", "Blueberry Compote"]),
                    MealItem(time: "12:30", name: "Mediterranean Edamame Rice Bowl", calories: cLunch, items: ["150g Edamame beans", "100g Basmati Rice", "60g Feta", "Cherry Tomatoes & Cucumber"]),
                    MealItem(time: "16:00", name: "Skyr & Dark Chocolate Snack", calories: cSnack, items: ["200g Skyr", "15g 85% Dark Chocolate", "1 Kiwi"]),
                    MealItem(time: "19:30", name: "Roasted Vegetable & Paneer Skillet", calories: cDinner, items: ["160g Paneer", "200g Roasted Potatoes", "Bell Peppers, Zucchini & Herbs", "1 tbsp Olive Oil"])
                ],
                [
                    MealItem(time: "08:00", name: "Overnight Chia & Protein Muesli", calories: cBreakfast, items: ["80g Rolled Oats", "200g Quark", "15g Chia Seeds", "Raspberries & Walnuts"]),
                    MealItem(time: "12:30", name: "Black Bean & Quinoa Fiesta Bowl", calories: cLunch, items: ["200g Black Beans", "100g Quinoa", "Half Avocado", "Corn & Salsa"]),
                    MealItem(time: "16:00", name: "Peanut Butter Banana Toast", calories: cSnack, items: ["1 Slice Whole Grain Toast", "25g Natural Peanut Butter", "Half Banana"]),
                    MealItem(time: "19:30", name: "Grilled Veggie & Halloumi Wrap", calories: cDinner, items: ["1 Whole Wheat Wrap", "90g Grilled Halloumi", "Hummus & Rocket Greens", "Roasted Tomatoes"])
                ],
                [
                    MealItem(time: "08:00", name: "Greek Yogurt & Granola Crunch", calories: cBreakfast, items: ["250g Greek Yogurt 0%", "50g Protein Granola", "Strawberries", "10g Flaxseeds"]),
                    MealItem(time: "12:30", name: "Red Lentil Coconut Stew", calories: cLunch, items: ["180g Red Lentils", "100g Jasmine Rice", "Spinach & Light Coconut Milk"]),
                    MealItem(time: "16:00", name: "Whey Protein & Mixed Nuts", calories: cSnack, items: ["30g Whey Isolate Shake", "25g Walnuts & Cashews"]),
                    MealItem(time: "19:30", name: "Stuffed Bell Peppers with Quinoa & Feta", calories: cDinner, items: ["2 Bell Peppers", "120g Cooked Quinoa", "70g Feta Cheese", "Tomato Coulis"])
                ],
                [
                    MealItem(time: "08:00", name: "Warm Cinnamon Apple Porridge", calories: cBreakfast, items: ["80g Oats", "250g Low-fat Quark", "1 Diced Apple & Cinnamon", "15g Pecans"]),
                    MealItem(time: "12:30", name: "Paneer Tikka with Wild Rice", calories: cLunch, items: ["150g Marinated Paneer", "120g Wild Rice", "Steamed Green Asparagus"]),
                    MealItem(time: "16:00", name: "Protein Pudding with Fresh Berries", calories: cSnack, items: ["200g High Protein Pudding", "Handful Blackberries"]),
                    MealItem(time: "19:30", name: "Gourmet Vegetable & Ricotta Frittata", calories: cDinner, items: ["150g Ricotta", "200g Potatoes", "Broccoli, Spinach & Fresh Herbs", "Side Garden Salad"])
                ]
            ]

            let plansDe: [[MealItem]] = [
                [
                    MealItem(time: "08:00", name: "High-Protein Power Oats", calories: cBreakfast, items: ["80g Haferflocken", "250g Magerquark / Griechischer Joghurt", "30g Whey-Protein", "Heidelbeeren & Walnüsse"]),
                    MealItem(time: "12:30", name: "Paneer & Linsen Power Bowl", calories: cLunch, items: ["150g Paneer angebraten", "100g Basmatireis", "150g Linsen-Dal", "Frischer Blattspinat & Gurkensalat"]),
                    MealItem(time: "16:00", name: "Pre-Workout Bananen-Quark", calories: cSnack, items: ["1 Banane", "150g Magerquark mit Zimt", "1 Reiswaffel"]),
                    MealItem(time: "19:30", name: "Hüttenkäse & Quinoa Bowl", calories: cDinner, items: ["200g Körniger Frischkäse", "100g Quinoa", "Gedünsteter Brokkoli & Süßkartoffel", "1 EL Olivenöl"])
                ],
                [
                    MealItem(time: "08:00", name: "Protein Beeren-Quark Bowl", calories: cBreakfast, items: ["250g Magerquark", "40g Haferflocken", "100g gemischte Beeren", "20g gehackte Mandeln"]),
                    MealItem(time: "12:30", name: "Kichererbsen & Halloumi Bowl", calories: cLunch, items: ["200g Kichererbsen", "80g Light-Halloumi", "150g Süßkartoffeln", "Bunter Salat & Tahini"]),
                    MealItem(time: "16:00", name: "Griechischer Joghurt & Honig-Reiswaffel", calories: cSnack, items: ["200g Griechischer Joghurt 0%", "2 Reiswaffeln", "1 TL Honig", "Zimt"]),
                    MealItem(time: "19:30", name: "Linsennudeln mit Ricotta", calories: cDinner, items: ["100g Rote Linsen-Pasta", "100g Ricotta", "Tomaten-Basilikum-Sugo", "Zucchini & Paprika"])
                ],
                [
                    MealItem(time: "08:00", name: "Mandelmilch-Porridge mit Saaten", calories: cBreakfast, items: ["70g Haferflocken", "250ml Mandelmilch", "30g Whey-Protein", "1 EL Chia- & Leinsamen"]),
                    MealItem(time: "12:30", name: "Tofu & Paneer Curry mit Naturreis", calories: cLunch, items: ["120g Paneer", "100g Räuchertofu", "100g Naturreis", "Blumenkohl & Erbsen"]),
                    MealItem(time: "16:00", name: "Apfel & Protein-Hüttenkäse", calories: cSnack, items: ["1 Knackiger Apfel", "150g Körniger Frischkäse", "10g Kürbiskerne"]),
                    MealItem(time: "19:30", name: "Spinat-Dal mit Dinkel-Fladenbrot", calories: cDinner, items: ["200g Gelbes Linsen-Dal", "Frischer Blattspinat", "1 Dinkel-Fladenbrot", "100g Joghurt-Raita"])
                ],
                [
                    MealItem(time: "08:00", name: "Hüttenkäse Protein-Pancakes", calories: cBreakfast, items: ["150g Körniger Frischkäse", "60g Hafermehl", "2 Eiklar / 50ml Milch", "Heidelbeer-Kompott"]),
                    MealItem(time: "12:30", name: "Mediterrane Edamame-Reis Bowl", calories: cLunch, items: ["150g Edamame", "100g Basmatireis", "60g Feta", "Kirschtomaten & Gurke"]),
                    MealItem(time: "16:00", name: "Skyr & Dunkle Schokolade", calories: cSnack, items: ["200g Skyr", "15g 85% Zartbitterschokolade", "1 Kiwi"]),
                    MealItem(time: "19:30", name: "Ofengemüse-Pfanne mit Paneer", calories: cDinner, items: ["160g Paneer", "200g Ofenkartoffeln", "Paprika, Zucchini & Kräuter", "1 EL Olivenöl"])
                ],
                [
                    MealItem(time: "08:00", name: "Overnight Chia & Protein-Müsli", calories: cBreakfast, items: ["80g Haferflocken", "200g Magerquark", "15g Chiasamen", "Himbeeren & Walnüsse"]),
                    MealItem(time: "12:30", name: "Schwarze Bohnen & Quinoa Fiesta", calories: cLunch, items: ["200g Schwarze Bohnen", "100g Quinoa", "Halbe Avocado", "Mais & Salsa"]),
                    MealItem(time: "16:00", name: "Erdnussbutter-Bananen Toast", calories: cSnack, items: ["1 Scheibe Vollkorntoast", "25g Naturbelassene Erdnussbutter", "Halbe Banane"]),
                    MealItem(time: "19:30", name: "Gegrillter Gemüse & Halloumi Wrap", calories: cDinner, items: ["1 Vollkorn-Wrap", "90g Grill-Halloumi", "Hummus & Rucola", "Geschmorte Tomaten"])
                ],
                [
                    MealItem(time: "08:00", name: "Griechischer Joghurt & Knusper-Granola", calories: cBreakfast, items: ["250g Griechischer Joghurt 0%", "50g Protein-Granola", "Erdbeeren", "10g Leinsamen"]),
                    MealItem(time: "12:30", name: "Roter Linsen-Kokos Eintopf", calories: cLunch, items: ["180g Rote Linsen", "100g Jasminreis", "Spinat & milde Kokosmilch"]),
                    MealItem(time: "16:00", name: "Whey Protein & Nussmischung", calories: cSnack, items: ["30g Whey Isolat Shake", "25g Walnüsse & Cashews"]),
                    MealItem(time: "19:30", name: "Gefüllte Paprika mit Quinoa & Feta", calories: cDinner, items: ["2 Paprikaschoten", "120g Quinoa", "70g Feta", "Würzige Tomatensauce"])
                ],
                [
                    MealItem(time: "08:00", name: "Warmer Zimt-Apfel Porridge", calories: cBreakfast, items: ["80g Haferflocken", "250g Magerquark", "1 Apfel gewürfelt & Zimt", "15g Pekannüsse"]),
                    MealItem(time: "12:30", name: "Paneer Tikka mit Wildreis", calories: cLunch, items: ["150g Mariniertes Paneer", "120g Wildreis", "Gedünsteter grüner Spargel"]),
                    MealItem(time: "16:00", name: "High-Protein Pudding mit Beeren", calories: cSnack, items: ["200g Protein-Pudding", "Eine Handvoll Brombeeren"]),
                    MealItem(time: "19:30", name: "Gemüse-Ricotta Frittata", calories: cDinner, items: ["150g Ricotta", "200g Kartoffeln", "Brokkoli, Spinat & Kräuter", "Frischer Gartensalat"])
                ]
            ]
            return isEn ? plansEn[day] : plansDe[day]

        case .vegetarian:
            let plansEn: [[MealItem]] = [
                [
                    MealItem(time: "08:00", name: "Scrambled Eggs & Whole Grain", calories: cBreakfast, items: ["3 Whole Eggs", "2 Slices Whole Grain Bread", "Avocado & Tomatoes"]),
                    MealItem(time: "12:30", name: "Tofu & Sweet Potato Bowl", calories: cLunch, items: ["200g Crispy Tofu", "150g Sweet Potatoes", "Green Veggies & Tahini"]),
                    MealItem(time: "16:00", name: "Greek Yogurt & Berries", calories: cSnack, items: ["200g Greek Yogurt", "Berries", "Handful Almonds"]),
                    MealItem(time: "19:30", name: "Lentil Pasta with Feta", calories: cDinner, items: ["120g Red Lentil Pasta", "Tomato Sauce", "50g Feta Cheese", "Zucchini"])
                ],
                [
                    MealItem(time: "08:00", name: "Omelette with Spinach & Mushrooms", calories: cBreakfast, items: ["3 Eggs", "100g Mushrooms", "Spinach", "1 Slice Rye Bread"]),
                    MealItem(time: "12:30", name: "Tempeh Quinoa Buddha Bowl", calories: cLunch, items: ["180g Tempeh", "100g Quinoa", "Steamed Broccoli & Edamame"]),
                    MealItem(time: "16:00", name: "Cottage Cheese & Peach Bowl", calories: cSnack, items: ["200g Cottage Cheese", "1 Sliced Peach", "Cinnamon"]),
                    MealItem(time: "19:30", name: "Vegetarian Chili Sin Carne", calories: cDinner, items: ["200g Kidney Beans & Corn", "100g Brown Rice", "Avocado & Salsa"])
                ],
                [
                    MealItem(time: "08:00", name: "Protein French Toast with Berries", calories: cBreakfast, items: ["2 Slices Spelt Bread soaked in Eggs & Milk", "Cinnamon", "Fresh Raspberries"]),
                    MealItem(time: "12:30", name: "Grilled Halloumi & Roasted Chickpeas", calories: cLunch, items: ["100g Halloumi", "180g Roasted Chickpeas", "Large Greek Salad"]),
                    MealItem(time: "16:00", name: "Boiled Eggs & Carrot Sticks", calories: cSnack, items: ["2 Hard Boiled Eggs", "Crunchy Carrots with Hummus"]),
                    MealItem(time: "19:30", name: "Tofu Fried Rice with Sesame", calories: cDinner, items: ["200g Smoked Tofu", "120g Basmati Rice", "Peas, Carrots & Sesame Oil"])
                ],
                [
                    MealItem(time: "08:00", name: "Avocado & Poached Eggs Toast", calories: cBreakfast, items: ["2 Poached Eggs", "2 Whole Grain Slices", "Half Avocado", "Chili Flakes"]),
                    MealItem(time: "12:30", name: "Spinach Ricotta Gnocchi Bowl", calories: cLunch, items: ["180g Potato Gnocchi", "120g Ricotta", "Steamed Spinach & Cherry Tomatoes"]),
                    MealItem(time: "16:00", name: "Skyr & Dark Chocolate Chips", calories: cSnack, items: ["200g Skyr", "15g Dark Chocolate", "1 Banana"]),
                    MealItem(time: "19:30", name: "Lentil Shepherd's Pie", calories: cDinner, items: ["200g Brown Lentils & Vegetables", "Mashed Potato Crust", "Green Side Salad"])
                ],
                [
                    MealItem(time: "08:00", name: "Berry Protein Oatmeal", calories: cBreakfast, items: ["80g Oats", "30g Whey Protein", "Almond Milk", "Blueberries"]),
                    MealItem(time: "12:30", name: "Falafel & Hummus Power Plate", calories: cLunch, items: ["6 Baked Falafels", "80g Hummus", "100g Couscous", "Cucumber & Tomato Salad"]),
                    MealItem(time: "16:00", name: "Peanut Butter Rice Cakes & Apple", calories: cSnack, items: ["2 Rice Cakes", "25g Peanut Butter", "1 Apple"]),
                    MealItem(time: "19:30", name: "Stuffed Zucchini with Feta & Walnuts", calories: cDinner, items: ["2 Zucchinis", "80g Feta", "30g Walnuts", "150g Roasted Potatoes"])
                ],
                [
                    MealItem(time: "08:00", name: "Egg & Cheese Breakfast Burrito", calories: cBreakfast, items: ["1 Whole Grain Wrap", "3 Scrambled Eggs", "30g Cheddar", "Tomato Salsa"]),
                    MealItem(time: "12:30", name: "Black Bean Burger with Sweet Fries", calories: cLunch, items: ["1 Black Bean Patty", "Whole Grain Bun", "150g Baked Sweet Potato Fries"]),
                    MealItem(time: "16:00", name: "Mixed Nuts & Protein Shake", calories: cSnack, items: ["30g Protein Shake", "25g Almonds"]),
                    MealItem(time: "19:30", name: "Creamy Coconut Dal with Rice", calories: cDinner, items: ["200g Red Lentil Dal", "100g Jasmine Rice", "Steamed Broccoli"])
                ],
                [
                    MealItem(time: "08:00", name: "Greek Yogurt Waffles with Berries", calories: cBreakfast, items: ["2 Protein Waffles", "150g Greek Yogurt", "Strawberries", "Maple Syrup"]),
                    MealItem(time: "12:30", name: "Paneer & Vegetable Skewers", calories: cLunch, items: ["160g Grilled Paneer", "120g Basmati Rice", "Grilled Bell Peppers & Onions"]),
                    MealItem(time: "16:00", name: "Cottage Cheese & Pineapple Cup", calories: cSnack, items: ["200g Cottage Cheese", "100g Fresh Pineapple"]),
                    MealItem(time: "19:30", name: "Vegetable Shakshuka with Feta", calories: cDinner, items: ["3 Eggs poached in spicy tomato bell pepper stew", "60g Feta", "1 Slice Sourdough Bread"])
                ]
            ]

            let plansDe: [[MealItem]] = [
                [
                    MealItem(time: "08:00", name: "Rührei & Vollkornbrot", calories: cBreakfast, items: ["3 Eier", "2 Scheiben Vollkornbrot", "Avocado & Tomaten"]),
                    MealItem(time: "12:30", name: "Tofu & Süßkartoffel Bowl", calories: cLunch, items: ["200g Knuspriger Tofu", "150g Süßkartoffeln", "Grünes Gemüse & Tahini"]),
                    MealItem(time: "16:00", name: "Griechischer Joghurt & Beeren", calories: cSnack, items: ["200g Griechischer Joghurt", "Waldbeeren", "Eine Handvoll Mandeln"]),
                    MealItem(time: "19:30", name: "Linsennudeln mit Feta", calories: cDinner, items: ["120g Rote Linsen-Pasta", "Tomatensugo", "50g Feta", "Zucchini"])
                ],
                [
                    MealItem(time: "08:00", name: "Champignon-Spinat Omelett", calories: cBreakfast, items: ["3 Eier", "100g Champignons", "Frischer Blattspinat", "1 Scheibe Roggenbrot"]),
                    MealItem(time: "12:30", name: "Tempeh-Quinoa Buddha Bowl", calories: cLunch, items: ["180g Tempeh", "100g Quinoa", "Gedünsteter Brokkoli & Edamame"]),
                    MealItem(time: "16:00", name: "Hüttenkäse mit Pfirsich", calories: cSnack, items: ["200g Körniger Frischkäse", "1 Pfirsich gewürfelt", "Prise Zimt"]),
                    MealItem(time: "19:30", name: "Vegetarisches Chili Sin Carne", calories: cDinner, items: ["200g Kidneybohnen & Mais", "100g Naturreis", "Avocado & Salsa"])
                ],
                [
                    MealItem(time: "08:00", name: "Protein French Toast mit Beeren", calories: cBreakfast, items: ["2 Scheiben Dinkelbrot in Ei gewendet", "Zimt", "Frische Himbeeren"]),
                    MealItem(time: "12:30", name: "Grill-Halloumi & Röstkichererbsen", calories: cLunch, items: ["100g Halloumi", "180g Geröstete Kichererbsen", "Großer griechischer Bauernsalat"]),
                    MealItem(time: "16:00", name: "Gekochte Eier & Karottensticks", calories: cSnack, items: ["2 Gekochte Eier", "Karottensticks mit Hummus"]),
                    MealItem(time: "19:30", name: "Tofu-Bratreis mit Sesam", calories: cDinner, items: ["200g Räuchertofu", "120g Basmatireis", "Erbsen, Karotten & Sesamöl"])
                ],
                [
                    MealItem(time: "08:00", name: "Pochierte Eier auf Avocado-Toast", calories: cBreakfast, items: ["2 Pochierte Eier", "2 Scheiben Vollkornbrot", "Halbe Avocado", "Chiliflocken"]),
                    MealItem(time: "12:30", name: "Spinat-Ricotta Gnocchi Pfanne", calories: cLunch, items: ["180g Kartoffel-Gnocchi", "120g Ricotta", "Blattspinat & Kirschtomaten"]),
                    MealItem(time: "16:00", name: "Skyr mit Schokodrops & Banane", calories: cSnack, items: ["200g Skyr", "15g Zartbitter-Drops", "1 Banane"]),
                    MealItem(time: "19:30", name: "Linsen-Auflauf mit Kartoffelhaube", calories: cDinner, items: ["200g Braune Linsen & Gemüse", "Kartoffelpüree-Haube", "Grüner Beilagensalat"])
                ],
                [
                    MealItem(time: "08:00", name: "Beeren-Protein Haferflocken", calories: cBreakfast, items: ["80g Haferflocken", "30g Whey-Protein", "Mandelmilch", "Heidelbeeren"]),
                    MealItem(time: "12:30", name: "Falafel & Hummus Power Teller", calories: cLunch, items: ["6 Ofen-Falafeln", "80g Hummus", "100g Couscous", "Gurken-Tomaten Salat"]),
                    MealItem(time: "16:00", name: "Erdnussbutter-Reiswaffeln & Apfel", calories: cSnack, items: ["2 Reiswaffeln", "25g Erdnussbutter", "1 Apfel"]),
                    MealItem(time: "19:30", name: "Gefüllte Zucchini mit Feta & Walnuss", calories: cDinner, items: ["2 Zucchini", "80g Feta", "30g Walnüsse", "150g Ofenkartoffeln"])
                ],
                [
                    MealItem(time: "08:00", name: "Ei & Käse Frühstücks-Burrito", calories: cBreakfast, items: ["1 Vollkorn-Wrap", "3 Rühreier", "30g Cheddar", "Tomatensalsa"]),
                    MealItem(time: "12:30", name: "Schwarze-Bohnen Burger mit Süßkartoffelpommes", calories: cLunch, items: ["1 Bohnen-Patty", "Vollkorn-Brötchen", "150g Gebackene Süßkartoffelpommes"]),
                    MealItem(time: "16:00", name: "Nussmischung & Protein-Shake", calories: cSnack, items: ["30g Protein-Shake", "25g Mandeln"]),
                    MealItem(time: "19:30", name: "Cremiges Kokos-Dal mit Duftreis", calories: cDinner, items: ["200g Rote Linsen Dal", "100g Jasminreis", "Gedünsteter Brokkoli"])
                ],
                [
                    MealItem(time: "08:00", name: "Protein-Waffeln mit Beerenquark", calories: cBreakfast, items: ["2 Protein-Waffeln", "150g Quark", "Erdbeeren", "Ahornsirup"]),
                    MealItem(time: "12:30", name: "Paneer-Gemüsespieße vom Grill", calories: cLunch, items: ["160g Paneer", "120g Basmatireis", "Paprika & Zwiebeln"]),
                    MealItem(time: "16:00", name: "Hüttenkäse mit Ananas", calories: cSnack, items: ["200g Körniger Frischkäse", "100g Frische Ananas"]),
                    MealItem(time: "19:30", name: "Würzige Shakshuka mit Feta", calories: cDinner, items: ["3 Eier pochiert in würziger Tomaten-Paprika-Sauce", "60g Feta", "1 Scheibe Sauerteigbrot"])
                ]
            ]
            return isEn ? plansEn[day] : plansDe[day]

        case .vegan:
            let plansEn: [[MealItem]] = [
                [
                    MealItem(time: "08:00", name: "Vegan Protein Oatmeal", calories: cBreakfast, items: ["80g Oats", "30g Pea/Rice Protein", "Soy Milk", "Chia Seeds & Berries"]),
                    MealItem(time: "12:30", name: "Tempeh & Quinoa Bowl", calories: cLunch, items: ["180g Tempeh", "120g Quinoa", "Edamame & Steamed Broccoli"]),
                    MealItem(time: "16:00", name: "Peanut Butter Rice Cakes", calories: cSnack, items: ["3 Rice Cakes", "30g Natural Peanut Butter", "1 Apple"]),
                    MealItem(time: "19:30", name: "Chickpea Coconut Curry", calories: cDinner, items: ["200g Chickpeas", "100g Basmati Rice", "Light Coconut Milk & Spinach"])
                ],
                [
                    MealItem(time: "08:00", name: "Tofu Scramble with Turmeric & Sourdough", calories: cBreakfast, items: ["200g Tofu scrambled", "Spinach & Tomatoes", "2 Slices Sourdough Bread"]),
                    MealItem(time: "12:30", name: "Lentil Bolognese with Whole Grain Pasta", calories: cLunch, items: ["120g Whole Grain Pasta", "180g Brown Lentil Bolognese", "Nutritional Yeast"]),
                    MealItem(time: "16:00", name: "Soy Yogurt & Chia Berry Bowl", calories: cSnack, items: ["200g Soy Yogurt", "15g Chia Seeds", "Mixed Berries"]),
                    MealItem(time: "19:30", name: "Smoked Tofu & Sweet Potato Skillet", calories: cDinner, items: ["180g Smoked Tofu", "180g Sweet Potatoes", "Kale & Tahini Dressing"])
                ],
                [
                    MealItem(time: "08:00", name: "Acai Protein Power Smoothie Bowl", calories: cBreakfast, items: ["100g Frozen Acai", "30g Pea Protein", "1 Banana", "Granola & Hemp Seeds"]),
                    MealItem(time: "12:30", name: "Black Bean Burrito Bowl", calories: cLunch, items: ["200g Black Beans", "120g Brown Rice", "Guacamole & Corn Salsa"]),
                    MealItem(time: "16:00", name: "Edamame & Mixed Raw Nuts", calories: cSnack, items: ["150g Steamed Edamame", "20g Walnuts"]),
                    MealItem(time: "19:30", name: "Creamy Peanut Tofu Stir-Fry", calories: cDinner, items: ["200g Crispy Tofu", "100g Soba Noodles", "Broccoli & Peanut Sauce"])
                ],
                [
                    MealItem(time: "08:00", name: "Warm Apple Cinnamon Buckwheat Porridge", calories: cBreakfast, items: ["80g Buckwheat/Oats", "30g Vegan Protein", "Almond Milk", "Diced Apple & Cinnamon"]),
                    MealItem(time: "12:30", name: "Mediterranean Chickpea & Couscous Salad", calories: cLunch, items: ["200g Chickpeas", "100g Couscous", "Cucumber, Tomatoes & Olive Oil"]),
                    MealItem(time: "16:00", name: "Banana & Almond Butter Toast", calories: cSnack, items: ["1 Slice Spelt Bread", "25g Almond Butter", "Half Banana"]),
                    MealItem(time: "19:30", name: "Red Lentil Dahl with Garlic Flatbread", calories: cDinner, items: ["220g Red Lentil Dahl", "Fresh Spinach", "1 Vegan Flatbread"])
                ],
                [
                    MealItem(time: "08:00", name: "Vegan Protein Pancakes with Blueberries", calories: cBreakfast, items: ["80g Oat Flour", "30g Plant Protein", "Oat Milk", "Fresh Blueberries"]),
                    MealItem(time: "12:30", name: "Seitan & Wild Rice Power Plate", calories: cLunch, items: ["180g Seitan Strips", "120g Wild Rice", "Steamed Green Asparagus"]),
                    MealItem(time: "16:00", name: "Hummus with Spelt Crackers & Cucumber", calories: cSnack, items: ["80g Hummus", "4 Spelt Crackers", "Cucumber Sticks"]),
                    MealItem(time: "19:30", name: "Stuffed Sweet Potatoes with Black Beans", calories: cDinner, items: ["2 Baked Sweet Potatoes", "180g Spiced Black Beans", "Avocado Cream"])
                ],
                [
                    MealItem(time: "08:00", name: "Superfood Chia & Seed Overnight Oats", calories: cBreakfast, items: ["70g Oats", "20g Chia & Pumpkin Seeds", "Soy Milk", "Strawberries"]),
                    MealItem(time: "12:30", name: "Crispy Tempeh Teriyaki with Jasmine Rice", calories: cLunch, items: ["180g Tempeh", "120g Jasmine Rice", "Stir-fried Pak Choi & Sesame"]),
                    MealItem(time: "16:00", name: "Plant Protein Shake & 85% Dark Chocolate", calories: cSnack, items: ["30g Pea Protein Shake", "15g Dark Chocolate"]),
                    MealItem(time: "19:30", name: "Creamy Pumpkin Lentil Soup", calories: cDinner, items: ["250g Pumpkin & Red Lentil Soup", "2 Slices Whole Grain Bread with Hummus"])
                ],
                [
                    MealItem(time: "08:00", name: "Avocado Sourdough with Hemp Seeds & Tomatoes", calories: cBreakfast, items: ["2 Slices Sourdough", "1 Avocado", "2 tbsp Hemp Seeds", "Cherry Tomatoes"]),
                    MealItem(time: "12:30", name: "Grilled Veggie & Falafel Wrap", calories: cLunch, items: ["1 Whole Grain Wrap", "5 Falafels", "Tahini Sauce & Mixed Greens"]),
                    MealItem(time: "16:00", name: "Mango Soy Yogurt Parfait", calories: cSnack, items: ["200g Soy Yogurt", "100g Diced Mango", "10g Flaxseeds"]),
                    MealItem(time: "19:30", name: "Tofu Tikka Masala with Basmati Rice", calories: cDinner, items: ["200g Marinated Tofu", "100g Basmati Rice", "Spicy Coconut Tomato Sauce"])
                ]
            ]

            let plansDe: [[MealItem]] = [
                [
                    MealItem(time: "08:00", name: "Veganes Protein-Müsli", calories: cBreakfast, items: ["80g Haferflocken", "30g Erbsen-/Reisprotein", "Sojamilch", "Chiasamen & Beeren"]),
                    MealItem(time: "12:30", name: "Tempeh & Quinoa Bowl", calories: cLunch, items: ["180g Tempeh", "120g Quinoa", "Edamame & Gedünsteter Brokkoli"]),
                    MealItem(time: "16:00", name: "Erdnussbutter-Reiswaffeln", calories: cSnack, items: ["3 Reiswaffeln", "30g Naturbelassene Erdnussbutter", "1 Apfel"]),
                    MealItem(time: "19:30", name: "Kichererbsen-Kokos-Curry", calories: cDinner, items: ["200g Kichererbsen", "100g Basmatireis", "Light-Kokosmilch & Blattspinat"])
                ],
                [
                    MealItem(time: "08:00", name: "Tofu-Rührei mit Kurkuma & Sauerteigbrot", calories: cBreakfast, items: ["200g Tofu zerbröselt", "Blattspinat & Tomaten", "2 Scheiben Sauerteigbrot"]),
                    MealItem(time: "12:30", name: "Linsen-Bolognese mit Vollkornnudeln", calories: cLunch, items: ["120g Vollkorn-Pasta", "180g Braune Linsen Bolognese", "Hefeflocken"]),
                    MealItem(time: "16:00", name: "Soja-Joghurt mit Chia & Beeren", calories: cSnack, items: ["200g Soja-Joghurt", "15g Chiasamen", "Gemischte Beeren"]),
                    MealItem(time: "19:30", name: "Räuchertofu-Süßkartoffel Pfanne", calories: cDinner, items: ["180g Räuchertofu", "180g Süßkartoffeln", "Grünkohl & Tahini-Dressing"])
                ],
                [
                    MealItem(time: "08:00", name: "Acai Protein Smoothie Bowl", calories: cBreakfast, items: ["100g Gefrorenes Acai", "30g Erbsenprotein", "1 Banane", "Granola & Hanfsamen"]),
                    MealItem(time: "12:30", name: "Schwarze Bohnen Burrito Bowl", calories: cLunch, items: ["200g Schwarze Bohnen", "120g Naturreis", "Guacamole & Maissalsa"]),
                    MealItem(time: "16:00", name: "Gedämpfte Edamame & Nüsse", calories: cSnack, items: ["150g Edamame", "20g Walnüsse"]),
                    MealItem(time: "19:30", name: "Tofu-Erdnuss Gemüsepfanne", calories: cDinner, items: ["200g Knuspriger Tofu", "100g Soba-Nudeln", "Brokkoli & cremige Erdnusssauce"])
                ],
                [
                    MealItem(time: "08:00", name: "Warmer Apfel-Zimt Buchweizen-Porridge", calories: cBreakfast, items: ["80g Buchweizen/Hafer", "30g Veganes Protein", "Mandelmilch", "Apfel & Zimt"]),
                    MealItem(time: "12:30", name: "Mediterraner Kichererbsen-Couscous Salat", calories: cLunch, items: ["200g Kichererbsen", "100g Couscous", "Gurke, Tomaten & Olivenöl"]),
                    MealItem(time: "16:00", name: "Bananen-Mandelmus Toast", calories: cSnack, items: ["1 Scheibe Dinkelbrot", "25g Mandelmus", "Halbe Banane"]),
                    MealItem(time: "19:30", name: "Rotes Linsen-Dal mit Knoblauchfladen", calories: cDinner, items: ["220g Rotes Linsen-Dal", "Frischer Spinat", "1 Veganes Fladenbrot"])
                ],
                [
                    MealItem(time: "08:00", name: "Vegane Protein-Pancakes mit Blaubeeren", calories: cBreakfast, items: ["80g Hafermehl", "30g Pflanzenprotein", "Hafermilch", "Frische Blaubeeren"]),
                    MealItem(time: "12:30", name: "Seitan-Streifen mit Wildreis & Spargel", calories: cLunch, items: ["180g Seitan", "120g Wildreis", "Gedünsteter grüner Spargel"]),
                    MealItem(time: "16:00", name: "Hummus mit Dinkel-Crackern & Gurke", calories: cSnack, items: ["80g Hummus", "4 Dinkel-Cracker", "Gurkensticks"]),
                    MealItem(time: "19:30", name: "Gefüllte Ofen-Süßkartoffel mit Bohnen", calories: cDinner, items: ["2 Gebackene Süßkartoffeln", "180g Gewürzte Schwarze Bohnen", "Avocado-Creme"])
                ],
                [
                    MealItem(time: "08:00", name: "Superfood Chia & Saaten Overnight Oats", calories: cBreakfast, items: ["70g Haferflocken", "20g Chia- & Kürbiskerne", "Sojamilch", "Erdbeeren"]),
                    MealItem(time: "12:30", name: "Knuspriges Teriyaki-Tempeh mit Duftreis", calories: cLunch, items: ["180g Tempeh", "120g Jasminreis", "Gebratener Pak Choi & Sesam"]),
                    MealItem(time: "16:00", name: "Pflanzenprotein-Shake & Zartbitterschokolade", calories: cSnack, items: ["30g Erbsenprotein-Shake", "15g Zartbitterschokolade"]),
                    MealItem(time: "19:30", name: "Cremige Kürbis-Linsensuppe", calories: cDinner, items: ["250g Kürbis-Linsensuppe", "2 Scheiben Vollkornbrot mit Hummus"])
                ],
                [
                    MealItem(time: "08:00", name: "Avocado-Sauerteigbrot mit Hanfsamen", calories: cBreakfast, items: ["2 Scheiben Sauerteigbrot", "1 Avocado", "2 EL Hanfsamen", "Kirschtomaten"]),
                    MealItem(time: "12:30", name: "Gegrillter Gemüse & Falafel Wrap", calories: cLunch, items: ["1 Vollkorn-Wrap", "5 Falafeln", "Tahini-Sauce & Salat"]),
                    MealItem(time: "16:00", name: "Mango Soja-Joghurt Parfait", calories: cSnack, items: ["200g Soja-Joghurt", "100g Mango gewürfelt", "10g Leinsamen"]),
                    MealItem(time: "19:30", name: "Tofu Tikka Masala mit Basmatireis", calories: cDinner, items: ["200g Marinierter Tofu", "100g Basmatireis", "Würzige Kokos-Tomatensauce"])
                ]
            ]
            return isEn ? plansEn[day] : plansDe[day]

        case .omnivore:
            let plansEn: [[MealItem]] = [
                [
                    MealItem(time: "08:00", name: "Power Breakfast Bowl", calories: cBreakfast, items: ["3 Whole Eggs", "2 Slices Spelt Bread", "100g Smoked Salmon", "Avocado"]),
                    MealItem(time: "12:30", name: "Chicken, Rice & Greens", calories: cLunch, items: ["200g Chicken Breast", "120g Basmati Rice", "Steamed Broccoli & Olive Oil"]),
                    MealItem(time: "16:00", name: "Pre-Workout Banana Quark", calories: cSnack, items: ["1 Banana", "200g Low-fat Quark with Berries"]),
                    MealItem(time: "19:30", name: "Lean Beef & Sweet Potatoes", calories: cDinner, items: ["180g Lean Rump Steak", "200g Sweet Potatoes", "Mixed Green Salad"])
                ],
                [
                    MealItem(time: "08:00", name: "Turkey Breast & Scrambled Eggs Toast", calories: cBreakfast, items: ["3 Eggs", "80g Turkey Breast", "2 Slices Whole Grain Bread", "Tomatoes"]),
                    MealItem(time: "12:30", name: "Salmon Fillet & Quinoa Bowl", calories: cLunch, items: ["180g Wild Salmon Fillet", "120g Quinoa", "Steamed Green Asparagus & Lemon"]),
                    MealItem(time: "16:00", name: "Greek Yogurt & Walnuts", calories: cSnack, items: ["200g Greek Yogurt", "25g Walnuts", "1 Apple"]),
                    MealItem(time: "19:30", name: "Lean Ground Beef & Potato Mash", calories: cDinner, items: ["180g 5% Lean Ground Beef", "200g Boiled Potatoes", "Green Beans & Herbs"])
                ],
                [
                    MealItem(time: "08:00", name: "High-Protein Oatmeal with Whey & Berries", calories: cBreakfast, items: ["80g Rolled Oats", "35g Whey Protein", "Almond Milk", "Blueberries"]),
                    MealItem(time: "12:30", name: "Tuna Steak & Brown Rice", calories: cLunch, items: ["180g Tuna Steak", "120g Brown Rice", "Mixed Stir-Fry Vegetables"]),
                    MealItem(time: "16:00", name: "Boiled Eggs & Rice Cakes", calories: cSnack, items: ["2 Boiled Eggs", "2 Rice Cakes", "Cottage Cheese"]),
                    MealItem(time: "19:30", name: "Grilled Chicken Breast with Sweet Potato Fries", calories: cDinner, items: ["200g Chicken Breast", "200g Baked Sweet Potatoes", "Cucumber Salad"])
                ],
                [
                    MealItem(time: "08:00", name: "Omelette with Feta & Spinach", calories: cBreakfast, items: ["3 Eggs", "50g Feta Cheese", "Fresh Spinach", "1 Slice Spelt Bread"]),
                    MealItem(time: "12:30", name: "Turkey Chili with Jasmine Rice", calories: cLunch, items: ["180g Minced Turkey Breast", "100g Jasmine Rice", "Kidney Beans & Bell Peppers"]),
                    MealItem(time: "16:00", name: "Skyr & Dark Chocolate Snack", calories: cSnack, items: ["200g Skyr", "15g 85% Dark Chocolate", "1 Orange"]),
                    MealItem(time: "19:30", name: "Pan-Seared Cod Fillet & Wild Rice", calories: cDinner, items: ["200g Cod Fillet", "120g Wild Rice", "Steamed Broccoli & Olive Oil"])
                ],
                [
                    MealItem(time: "08:00", name: "Smoked Salmon & Poached Eggs", calories: cBreakfast, items: ["100g Smoked Salmon", "2 Poached Eggs", "2 Slices Whole Grain Toast", "Avocado"]),
                    MealItem(time: "12:30", name: "Chicken Fajita Bowl with Rice", calories: cLunch, items: ["200g Spiced Chicken Strips", "120g Basmati Rice", "Roasted Peppers & Onions"]),
                    MealItem(time: "16:00", name: "Whey Protein & Almonds", calories: cSnack, items: ["30g Whey Isolate Shake", "25g Raw Almonds"]),
                    MealItem(time: "19:30", name: "Beef Tenderloin & Baked Potato", calories: cDinner, items: ["180g Beef Tenderloin", "1 Large Baked Potato with Quark", "Grilled Zucchini"])
                ],
                [
                    MealItem(time: "08:00", name: "Protein Pancakes with Quark & Honey", calories: cBreakfast, items: ["3 Protein Pancakes", "150g Quark", "Fresh Strawberries", "1 tsp Honey"]),
                    MealItem(time: "12:30", name: "Grilled Shrimp & Quinoa Salad", calories: cLunch, items: ["200g King Prawns", "120g Quinoa", "Avocado, Tomatoes & Lime Dressing"]),
                    MealItem(time: "16:00", name: "Peanut Butter Rice Cakes & Banana", calories: cSnack, items: ["2 Rice Cakes", "25g Peanut Butter", "1 Banana"]),
                    MealItem(time: "19:30", name: "Roast Turkey Steak & Vegetable Medley", calories: cDinner, items: ["200g Turkey Steak", "200g Roasted Potatoes", "Carrots & Broccoli"])
                ],
                [
                    MealItem(time: "08:00", name: "Sunday Power Omelette with Herbs", calories: cBreakfast, items: ["3 Eggs", "50g Ham or Salmon", "Chives & Tomatoes", "2 Slices Spelt Bread"]),
                    MealItem(time: "12:30", name: "Mediterranean Lemon Chicken & Rice", calories: cLunch, items: ["200g Lemon Herb Chicken", "120g Basmati Rice", "Roasted Cherry Tomatoes"]),
                    MealItem(time: "16:00", name: "Cottage Cheese & Mixed Berries", calories: cSnack, items: ["200g Cottage Cheese", "100g Fresh Blueberries & Walnuts"]),
                    MealItem(time: "19:30", name: "Oven-Baked Salmon & Sweet Potato Mash", calories: cDinner, items: ["180g Salmon Fillet", "200g Sweet Potato Mash", "Steamed Spinach"])
                ]
            ]

            let plansDe: [[MealItem]] = [
                [
                    MealItem(time: "08:00", name: "Power-Frühstück", calories: cBreakfast, items: ["3 Eier", "2 Scheiben Dinkelbrot", "100g Räucherlachs", "Avocado"]),
                    MealItem(time: "12:30", name: "Hähnchenbrust, Reis & Brokkoli", calories: cLunch, items: ["200g Hähnchenbrustfilet", "120g Basmatireis", "Gedünsteter Brokkoli & Olivenöl"]),
                    MealItem(time: "16:00", name: "Pre-Workout Bananen-Quark", calories: cSnack, items: ["1 Banane", "200g Magerquark mit Beeren"]),
                    MealItem(time: "19:30", name: "Rumpsteak & Süßkartoffeln", calories: cDinner, items: ["180g Mageres Rumpsteak", "200g Süßkartoffeln", "Großer bunter Salat"])
                ],
                [
                    MealItem(time: "08:00", name: "Putenbrust & Rührei auf Vollkornbrot", calories: cBreakfast, items: ["3 Eier", "80g Putenbrustaufschnitt", "2 Scheiben Vollkornbrot", "Tomaten"]),
                    MealItem(time: "12:30", name: "Lachsfilet & Quinoa Bowl", calories: cLunch, items: ["180g Wildlachsfilet", "120g Quinoa", "Grüner Spargel & Zitrone"]),
                    MealItem(time: "16:00", name: "Griechischer Joghurt & Walnüsse", calories: cSnack, items: ["200g Griechischer Joghurt", "25g Walnüsse", "1 Apfel"]),
                    MealItem(time: "19:30", name: "Mageres Rinderhack & Kartoffelpüree", calories: cDinner, items: ["180g Rinderhack (5% Fett)", "200g Kartoffeln", "Grüne Bohnen & Kräuter"])
                ],
                [
                    MealItem(time: "08:00", name: "High-Protein Haferflocken mit Whey & Beeren", calories: cBreakfast, items: ["80g Haferflocken", "35g Whey-Protein", "Mandelmilch", "Heidelbeeren"]),
                    MealItem(time: "12:30", name: "Thunfischsteak & Naturreis", calories: cLunch, items: ["180g Thunfischsteak", "120g Naturreis", "Buntes Wokgemüse"]),
                    MealItem(time: "16:00", name: "Gekochte Eier & Reiswaffeln", calories: cSnack, items: ["2 Gekochte Eier", "2 Reiswaffeln", "Hüttenkäse"]),
                    MealItem(time: "19:30", name: "Gegrillte Hähnchenbrust & Süßkartoffelpommes", calories: cDinner, items: ["200g Hähnchenbrust", "200g Ofen-Süßkartoffeln", "Gurkensalat"])
                ],
                [
                    MealItem(time: "08:00", name: "Feta-Spinat Omelett", calories: cBreakfast, items: ["3 Eier", "50g Feta", "Frischer Spinat", "1 Scheibe Dinkelbrot"]),
                    MealItem(time: "12:30", name: "Puten-Chili mit Jasminreis", calories: cLunch, items: ["180g Putenhackfleisch", "100g Jasminreis", "Kidneybohnen & Paprika"]),
                    MealItem(time: "16:00", name: "Skyr & Zartbitterschokolade", calories: cSnack, items: ["200g Skyr", "15g 85% Zartbitterschokolade", "1 Orange"]),
                    MealItem(time: "19:30", name: "Kabeljaufilet & Wildreis", calories: cDinner, items: ["200g Kabeljaufilet", "120g Wildreis", "Gedünsteter Brokkoli & Olivenöl"])
                ],
                [
                    MealItem(time: "08:00", name: "Räucherlachs & Pochierte Eier", calories: cBreakfast, items: ["100g Räucherlachs", "2 Pochierte Eier", "2 Scheiben Vollkorntoast", "Avocado"]),
                    MealItem(time: "12:30", name: "Hähnchen-Fajita Bowl mit Reis", calories: cLunch, items: ["200g Würzige Hähnchenstreifen", "120g Basmatireis", "Paprika & Zwiebeln"]),
                    MealItem(time: "16:00", name: "Whey Protein & Mandeln", calories: cSnack, items: ["30g Whey Isolat Shake", "25g Ganze Mandeln"]),
                    MealItem(time: "19:30", name: "Rinderfilet & Ofenkartoffel", calories: cDinner, items: ["180g Rinderfilet", "1 Große Ofenkartoffel mit Kräuterquark", "Gegrillte Zucchini"])
                ],
                [
                    MealItem(time: "08:00", name: "Protein-Pancakes mit Beerenquark", calories: cBreakfast, items: ["3 Protein-Pancakes", "150g Magerquark", "Frische Erdbeeren", "1 TL Honig"]),
                    MealItem(time: "12:30", name: "Garnelen & Quinoa Salat", calories: cLunch, items: ["200g Riesengarnelen", "120g Quinoa", "Avocado, Tomaten & Limettendressing"]),
                    MealItem(time: "16:00", name: "Erdnussbutter-Reiswaffeln & Banane", calories: cSnack, items: ["2 Reiswaffeln", "25g Erdnussbutter", "1 Banane"]),
                    MealItem(time: "19:30", name: "Putensteak & Buntes Ofengemüse", calories: cDinner, items: ["200g Putensteak", "200g Röstkartoffeln", "Karotten & Brokkoli"])
                ],
                [
                    MealItem(time: "08:00", name: "Sonntags-Kräuteromelett mit Schinken", calories: cBreakfast, items: ["3 Eier", "50g Magerer Schinken", "Schnittlauch & Tomaten", "2 Scheiben Dinkelbrot"]),
                    MealItem(time: "12:30", name: "Mediterranes Zitronen-Hähnchen", calories: cLunch, items: ["200g Hähnchenbrust mit Rosmarin & Zitrone", "120g Basmatireis", "Geschmorte Kirschtomaten"]),
                    MealItem(time: "16:00", name: "Hüttenkäse & Blaubeeren", calories: cSnack, items: ["200g Körniger Frischkäse", "100g Frische Blaubeeren & Walnüsse"]),
                    MealItem(time: "19:30", name: "Lachsfilet aus dem Ofen & Süßkartoffelpüree", calories: cDinner, items: ["180g Lachsfilet", "200g Süßkartoffelpüree", "Gedünsteter Blattspinat"])
                ]
            ]
            return isEn ? plansEn[day] : plansDe[day]
        }
    }

    private func generateShakes(diet: DietType, language: String) -> [ShakeItem] {
        let isEn = language == "en"
        let proteinPowder = diet == .vegan
            ? (isEn ? "30g Pea & Rice Protein" : "30g Veganes Erbsen-/Reisprotein")
            : (isEn ? "30g Whey Protein Isolate" : "30g Whey Protein Isolat")

        return isEn ? [
            ShakeItem(when: "Directly Post-Workout", what: "\(proteinPowder) + 1 Banana + 5g Creatine in Water/Oat Milk"),
            ShakeItem(when: "Optional Afternoon Boost", what: "Green Smoothie with Spinach, Chia Seeds & Lemon")
        ] : [
            ShakeItem(when: "Direkt nach dem Training", what: "\(proteinPowder) + 1 Banane + 5g Kreatin in Wasser/Hafermilch"),
            ShakeItem(when: "Optionaler Nachmittag-Boost", what: "Grüner Smoothie mit Spinat, Chiasamen & Zitrone")
        ]
    }
}
