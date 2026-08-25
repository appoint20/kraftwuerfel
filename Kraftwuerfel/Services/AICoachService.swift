import Foundation

public enum TrainingGoal: String, Codable, CaseIterable, Identifiable {
    case muscle = "muscle"
    case strength = "strength"
    case definition = "definition"
    case fitness = "fitness"
    case weightLoss = "abnehmen"
    
    public var id: String { rawValue }
    
    public var titleDe: String {
        switch self {
        case .muscle: return "Muskelaufbau"
        case .strength: return "Maximalkraft"
        case .definition: return "Definition"
        case .fitness: return "Allgemeine Fitness"
        case .weightLoss: return "Abnehmen"
        }
    }
    
    public var titleEn: String {
        switch self {
        case .muscle: return "Muscle Building"
        case .strength: return "Max Strength"
        case .definition: return "Definition"
        case .fitness: return "General Fitness"
        case .weightLoss: return "Weight Loss"
        }
    }

    /// Die einzige Stelle, an der Ansichten den Titel holen sollten. Vorher
    /// stand überall `titleDe` — die Auswahl blieb dadurch auch auf Englisch
    /// deutsch, und der Wert wanderte so in den fertigen Plan.
    public func localized(_ lang: String) -> String {
        lang == "en" ? titleEn : titleDe
    }
}

public enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    
    public var id: String { rawValue }
    
    public var titleDe: String {
        switch self {
        case .beginner: return "Anfänger (< 1 Jahr)"
        case .intermediate: return "Fortgeschritten (1-3 Jahre)"
        case .advanced: return "Experte (> 3 Jahre)"
        }
    }
    
    public var titleEn: String {
        switch self {
        case .beginner: return "Beginner (< 1 yr)"
        case .intermediate: return "Intermediate (1-3 yrs)"
        case .advanced: return "Advanced (> 3 yrs)"
        }
    }

    /// Ohne Jahresangabe — für Stellen, an denen der Wert in einem Fließtext
    /// oder in einem fertigen Plan auftaucht.
    public var shortTitleDe: String {
        switch self {
        case .beginner: return "Anfänger"
        case .intermediate: return "Fortgeschritten"
        case .advanced: return "Experte"
        }
    }

    public var shortTitleEn: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    public func localized(_ lang: String) -> String {
        lang == "en" ? titleEn : titleDe
    }

    public func localizedShort(_ lang: String) -> String {
        lang == "en" ? shortTitleEn : shortTitleDe
    }
}

public struct UserBiometrics: Codable, Hashable {
    public var sex: String // "male", "female", "other"
    public var age: Int
    public var heightCm: Double
    public var weightKg: Double
    
    public init(sex: String = "male", age: Int = 28, heightCm: Double = 180, weightKg: Double = 80) {
        self.sex = sex
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
    }
}

public struct AICoachInput: Codable, Hashable {
    public var goal: TrainingGoal
    public var experience: ExperienceLevel
    public var biometrics: UserBiometrics
    public var selectedDays: [String] // ["Mo", "Mi", "Fr"]
    public var sessionDurationMinutes: Int
    public var weeks: Int
    public var equipment: Set<EquipmentType>
    public var focusMuscles: Set<MuscleCategory>
    public var limitations: [String]
    public var diet: DietType
    public var includeWarmup: Bool

    /*
      Zielgewicht in Kilogramm. `nil` heißt: kein Ziel gesetzt, dann bestimmt
      allein das Trainingsziel den Kalorienrahmen. Ist es gesetzt, schlägt es
      die Kategorie — wer 95 kg wiegt und 85 will, braucht ein Defizit, ganz
      gleich ob als Ziel „Muskelaufbau“ dasteht.
    */
    public var goalWeightKg: Double?

    /// Satzschema wie im Generator. Vorher rechnete der KI-Coach immer mit
    /// `.standard`, obwohl die App drei weitere Methoden kennt.
    public var method: TrainingMethod
    
    public init(
        goal: TrainingGoal = .muscle,
        experience: ExperienceLevel = .intermediate,
        biometrics: UserBiometrics = UserBiometrics(),
        selectedDays: [String] = ["Mo", "Mi", "Fr"],
        sessionDurationMinutes: Int = 60,
        weeks: Int = 4,
        equipment: Set<EquipmentType> = [],
        focusMuscles: Set<MuscleCategory> = [],
        limitations: [String] = [],
        diet: DietType = .omnivore,
        includeWarmup: Bool = true,
        goalWeightKg: Double? = nil,
        method: TrainingMethod = .standard
    ) {
        self.goal = goal
        self.experience = experience
        self.biometrics = biometrics
        self.selectedDays = selectedDays
        self.sessionDurationMinutes = sessionDurationMinutes
        self.weeks = weeks
        self.equipment = equipment
        self.focusMuscles = focusMuscles
        self.limitations = limitations
        self.diet = diet
        self.includeWarmup = includeWarmup
        self.goalWeightKg = goalWeightKg
        self.method = method
    }

    /// Differenz zum Zielgewicht in Kilogramm. Positiv heißt zunehmen.
    public var weightDelta: Double? {
        guard let goalWeightKg else { return nil }
        return goalWeightKg - biometrics.weightKg
    }
}

public final class AICoachService {
    public static let shared = AICoachService()
    
    private init() {}
    
    public func generatePlan(input: AICoachInput, language: String = "de") -> TrainingPlan {
        let isEn = language == "en"
        
        // 1. Calculate BMR & TDEE (Mifflin-St Jeor)
        let weight = input.biometrics.weightKg
        let height = input.biometrics.heightCm
        let age = Double(input.biometrics.age)
        
        var bmr: Double = 10 * weight + 6.25 * height - 5 * age
        if input.biometrics.sex == "male" {
            bmr += 5
        } else {
            bmr -= 161
        }
        
        // Activity factor
        let activityFactor: Double = 1.2 + (Double(input.selectedDays.count) * 0.08)
        var tdee = Int(bmr * activityFactor)
        
        /*
          Kalorienrahmen.

          Ohne Zielgewicht entscheidet die Zielkategorie, wie bisher. Mit
          Zielgewicht entscheidet der Abstand dorthin — wer abnehmen will,
          braucht ein Defizit, auch wenn als Ziel „Muskelaufbau“ dasteht.

          Die Schritte sind bewusst grob und gedeckelt: ±500 kcal entsprechen
          etwa einem halben Kilo pro Woche. Alles Schnellere ist nichts, was
          eine App ohne ärztliche Begleitung vorschlagen sollte.
        */
        if let delta = input.weightDelta, abs(delta) >= 1 {
            let magnitude = abs(delta) >= 5 ? 500 : 300
            tdee += delta > 0 ? magnitude : -magnitude
        } else {
            switch input.goal {
            case .muscle: tdee += 300
            case .strength: tdee += 200
            case .definition: tdee -= 400
            case .weightLoss: tdee -= 500
            case .fitness: break
            }
        }

        // Untergrenze. Ein Zielgewicht weit unter dem heutigen darf die App
        // nicht in eine Empfehlung laufen lassen, die niemand essen sollte.
        tdee = max(1200, tdee)
        
        // Macros
        let proteinPerKg: Double = input.goal == .muscle || input.goal == .definition ? 2.0 : 1.6
        let proteinGrams = Int(weight * proteinPerKg)
        let fatGrams = Int(weight * 0.9)
        let remainingCalories = max(tdee - (proteinGrams * 4 + fatGrams * 9), 400)
        let carbGrams = remainingCalories / 4
        
        // Generate Meals based on Diet
        let meals = generateMeals(diet: input.diet, totalCalories: tdee, language: language)
        let shakes = generateShakes(diet: input.diet, language: language)
        
        let nutrition = NutritionPlan(
            diet: input.diet,
            dailyCalories: tdee,
            protein: proteinGrams,
            carbs: carbGrams,
            fat: fatGrams,
            meals: meals,
            shakes: shakes,
            notes: {
                var notes = isEn
                    ? ["Drink at least 3-4 liters of water daily",
                       "Consume ~30g protein every 3-4 hours"]
                    : ["Trinke täglich mindestens 3–4 Liter Wasser",
                       "Verteile dein Eiweiß gleichmäßig über den Tag"]
                // Sagen, worauf der Rahmen zielt — sonst ist die Zahl beliebig.
                if let goal = input.goalWeightKg, let delta = input.weightDelta, abs(delta) >= 1 {
                    let target = Int(goal.rounded())
                    notes.insert(
                        isEn
                            ? (delta > 0
                               ? "Calculated as a surplus towards \(target) kg — expect roughly 0.25–0.5 kg per week."
                               : "Calculated as a deficit towards \(target) kg — expect roughly 0.25–0.5 kg per week.")
                            : (delta > 0
                               ? "Auf einen Überschuss Richtung \(target) kg gerechnet — etwa 0,25–0,5 kg pro Woche."
                               : "Auf ein Defizit Richtung \(target) kg gerechnet — etwa 0,25–0,5 kg pro Woche."),
                        at: 0
                    )
                }
                return notes
            }(),
            disclaimer: isEn
                ? "Nutritional values are scientifically estimated reference values for healthy adults."
                : "Nährwertangaben sind wissenschaftlich berechnete Richtwerte für gesunde Erwachsene."
        )
        
        // 2. Generate Day Plans & Exercises
        let dayNamesDe = ["Titan", "Vulkan", "Olymp", "Gipfel", "Atlas", "Komet", "Phönix"]
        let dayNamesEn = ["Titan", "Vulcan", "Olympus", "Summit", "Atlas", "Comet", "Phoenix"]
        
        var generatedDays: [DayPlan] = []
        
        for (index, day) in input.selectedDays.enumerated() {
            let dayName = isEn ? dayNamesEn[index % dayNamesEn.count] : dayNamesDe[index % dayNamesDe.count]
            
            // Choose focus based on split & index
            let focusDe: String
            let focusEn: String
            var targetMuscles: [MuscleCategory] = []
            
            if input.selectedDays.count <= 2 {
                focusDe = "Ganzkörper & Kraft"
                focusEn = "Full Body & Strength"
                targetMuscles = [.chest, .back, .legs, .shoulders, .core]
            } else if input.selectedDays.count == 3 {
                if index == 0 {
                    focusDe = "Push (Brust, Schultern, Trizeps)"
                    focusEn = "Push (Chest, Shoulders, Triceps)"
                    targetMuscles = [.chest, .shoulders, .triceps]
                } else if index == 1 {
                    focusDe = "Pull (Rücken, Bizeps)"
                    focusEn = "Pull (Back, Biceps)"
                    targetMuscles = [.back, .biceps]
                } else {
                    focusDe = "Beine & Core"
                    focusEn = "Legs & Core"
                    targetMuscles = [.legs, .glutes, .calves, .core]
                }
            } else {
                if index % 4 == 0 {
                    focusDe = "Oberkörper (Fokus Brust & Rücken)"
                    focusEn = "Upper Body (Chest & Back Focus)"
                    targetMuscles = [.chest, .back, .shoulders]
                } else if index % 4 == 1 {
                    focusDe = "Unterkörper (Quads & Glutes)"
                    focusEn = "Lower Body (Quads & Glutes)"
                    targetMuscles = [.legs, .glutes, .calves]
                } else if index % 4 == 2 {
                    focusDe = "Oberkörper (Fokus Arme & Schultern)"
                    focusEn = "Upper Body (Arms & Shoulders)"
                    targetMuscles = [.shoulders, .biceps, .triceps]
                } else {
                    focusDe = "Unterkörper & Core"
                    focusEn = "Lower Body & Core"
                    targetMuscles = [.legs, .glutes, .core]
                }
            }
            
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
            
            /*
              Vorher wurde je Muskelgruppe GENAU EINE Übung gezogen. Bei einem
              Pull-Tag (Rücken, Bizeps) waren das zwei Übungen für ein ganzes
              Training — das war der Grund, warum die App nur vier bis fünf
              Übungen zeigte.

              Jetzt baut derselbe Generator wie im Rest der App den Tag: mit
              einer Übungszahl, die sich aus der Trainingsdauer ergibt, und nur
              aus dem Equipment, das zur Verfügung steht. Zyklus 2 schließt die
              Übungen aus Zyklus 1 aus, damit sich die Wochen unterscheiden.
            */
            /*
              Die Methode bestimmt das Satzschema, nicht mehr allein die
              Erfahrung. `buildPlan` verteilt bei 5x4x3 und 4x4x3 die schweren
              Sätze selbst; nur bei „Standard“ bleibt die alte Regel, dass
              Fortgeschrittene einen Satz mehr bekommen.
            */
            let baseSets = input.experience == .advanced ? 4 : 3
            let repsC1 = input.goal == .strength ? "4-6" : (input.goal == .muscle ? "6-10" : "10-12")
            let repsC2 = input.goal == .strength ? "6-8" : (input.goal == .muscle ? "10-14" : "12-15")
            let rest = input.goal == .strength ? 120 : (input.goal == .muscle ? 90 : 60)

            // Rund eine Übung je zehn Minuten, zwischen vier und zehn.
            let count = max(4, min(10, input.sessionDurationMinutes / 10))

            let cycle1 = PlanGenerator.buildPlan(
                categories: targetMuscles,
                count: count,
                method: input.method,
                restTime: rest,
                equipment: input.equipment
            )
            let usedInCycle1 = Set(cycle1.map(\.exercise.name))
            let cycle2 = PlanGenerator.buildPlan(
                categories: targetMuscles,
                count: count,
                method: input.method,
                restTime: rest,
                extraExclude: usedInCycle1,
                equipment: input.equipment
            )

            // Bei Standard gilt die Erfahrungsregel, sonst zählt, was das
            // Satzschema vergeben hat.
            func setsFor(_ slot: ExerciseSlot) -> Int {
                input.method == .standard ? baseSets : slot.sets
            }

            let cycle1Slots = cycle1.map {
                ExerciseSlot(exercise: $0.exercise, sets: setsFor($0), reps: repsC1, restSeconds: rest)
            }
            let cycle2Slots = cycle2.map {
                ExerciseSlot(exercise: $0.exercise, sets: setsFor($0), reps: repsC2, restSeconds: rest)
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
            ? "Individually periodized for \(input.selectedDays.count) training days per week with optimal recovery curves."
            : "Individuell periodisiert für \(input.selectedDays.count) Trainingstage pro Woche mit optimaler Regenerationskurve."
        
        return TrainingPlan(
            title: planTitle,
            summary: planSummary,
            weeks: input.weeks,
            days: generatedDays,
            nutrition: nutrition,
            notes: isEn ? [
                "Aim for progressive overload each week (add +1-2.5 kg or +1 rep)",
                "Ensure 7-8 hours of quality sleep for peak muscle recovery"
            ] : [
                "Steigere jede Woche progressiv das Gewicht (+1-2.5 kg) oder die Wiederholungen",
                "Achte auf 7–8 Stunden Schlaf für maximale Muskelproteinsynthese"
            ],
            language: language
        )
    }
    
    /*
      Denselben Plan in einer anderen Sprache.

      Ein fertiger Plan trägt seine Texte in sich: Titel, Zusammenfassung,
      Tagesnamen, Fokus, Aufwärmen, Hinweise und den ganzen Meal Guide. Sie
      entstehen beim Erzeugen und blieben deshalb auf Deutsch stehen, wenn
      jemand danach auf EN umschaltete.

      Hier wird ein frischer Plan in der Zielsprache gebaut — der bringt alle
      Texte richtig mit — und darauf werden die ALTEN Übungen gelegt. Ein
      Sprachwechsel darf das Training nicht neu würfeln.
    */
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

        var result = TrainingPlan(
            title: fresh.title,
            summary: fresh.summary,
            weeks: plan.weeks,
            days: days,
            nutrition: fresh.nutrition,
            notes: fresh.notes,
            createdAt: plan.createdAt,
            language: language
        )
        // Identität behalten: es ist derselbe Plan, nur anders beschriftet.
        result.id = plan.id
        return result
    }

    private func generateMeals(diet: DietType, totalCalories: Int, language: String) -> [MealItem] {
        let isEn = language == "en"
        
        switch diet {
        case .lactoVegetarian:
            return isEn ? [
                MealItem(time: "08:00", name: "High-Protein Power Oats", calories: totalCalories / 4, items: ["80g Rolled Oats", "250g Quark / Greek Yogurt", "30g Whey Protein", "Handful Blueberries & Walnuts"]),
                MealItem(time: "12:30", name: "Paneer & Lentil Power Bowl", calories: Int(Double(totalCalories) * 0.35), items: ["150g Paneer (grilled)", "100g Basmati Rice", "150g Lentil Dal", "Spinach & Cucumber Salad"]),
                MealItem(time: "16:00", name: "Pre-Workout Snack", calories: totalCalories / 6, items: ["1 Banana", "150g Low-fat Quark with Cinnamon", "1 Rice Cake"]),
                MealItem(time: "19:30", name: "Cottage Cheese & Quinoa Bowl", calories: Int(Double(totalCalories) * 0.3), items: ["200g Cottage Cheese (Hüttenkäse)", "100g Quinoa", "Steamed Broccoli & Sweet Potatoes", "1 tbsp Olive Oil"])
            ] : [
                MealItem(time: "08:00", name: "High-Protein Power Oats", calories: totalCalories / 4, items: ["80g Haferflocken", "250g Magerquark / Griechischer Joghurt", "30g Whey-Protein", "Heidelbeeren & Walnüsse"]),
                MealItem(time: "12:30", name: "Paneer & Linsen Power Bowl", calories: Int(Double(totalCalories) * 0.35), items: ["150g Paneer angebraten", "100g Basmatireis", "150g Linsen-Dal", "Frischer Blattspinat & Gurkensalat"]),
                MealItem(time: "16:00", name: "Pre-Workout Snack", calories: totalCalories / 6, items: ["1 Banane", "150g Magerquark mit Zimt", "1 Reiswaffel"]),
                MealItem(time: "19:30", name: "Hüttenkäse & Quinoa Bowl", calories: Int(Double(totalCalories) * 0.3), items: ["200g Körniger Frischkäse", "100g Quinoa", "Gedünsteter Brokkoli & Süßkartoffel", "1 EL Olivenöl"])
            ]
            
        case .vegetarian:
            return isEn ? [
                MealItem(time: "08:00", name: "Scrambled Eggs & Whole Grain", calories: totalCalories / 4, items: ["3 Whole Eggs", "2 Slices Whole Grain Bread", "Avocado & Tomatoes"]),
                MealItem(time: "12:30", name: "Tofu & Sweet Potato Bowl", calories: Int(Double(totalCalories) * 0.35), items: ["200g Crispy Tofu", "150g Sweet Potatoes", "Green Veggies & Tahini"]),
                MealItem(time: "16:00", name: "Greek Yogurt & Berries", calories: totalCalories / 6, items: ["200g Greek Yogurt", "Berries", "Handful Almonds"]),
                MealItem(time: "19:30", name: "Lentil Pasta with Feta", calories: Int(Double(totalCalories) * 0.3), items: ["120g Red Lentil Pasta", "Tomato Sauce", "50g Feta Cheese", "Zucchini"])
            ] : [
                MealItem(time: "08:00", name: "Rührei & Vollkornbrot", calories: totalCalories / 4, items: ["3 Eier", "2 Scheiben Vollkornbrot", "Avocado & Tomaten"]),
                MealItem(time: "12:30", name: "Tofu & Süßkartoffel Bowl", calories: Int(Double(totalCalories) * 0.35), items: ["200g Knuspriger Tofu", "150g Süßkartoffeln", "Grünes Gemüse & Tahini"]),
                MealItem(time: "16:00", name: "Griechischer Joghurt & Beeren", calories: totalCalories / 6, items: ["200g Griechischer Joghurt", "Waldbeeren", "Eine Handvoll Mandeln"]),
                MealItem(time: "19:30", name: "Linsennudeln mit Feta", calories: Int(Double(totalCalories) * 0.3), items: ["120g Rote Linsen-Pasta", "Tomatensugo", "50g Feta", "Zucchini"])
            ]
            
        case .vegan:
            return isEn ? [
                MealItem(time: "08:00", name: "Vegan Protein Oatmeal", calories: totalCalories / 4, items: ["80g Oats", "30g Pea/Rice Protein", "Soy Milk", "Chia Seeds & Berries"]),
                MealItem(time: "12:30", name: "Tempeh & Quinoa Bowl", calories: Int(Double(totalCalories) * 0.35), items: ["180g Tempeh", "120g Quinoa", "Edamame & Steamed Broccoli"]),
                MealItem(time: "16:00", name: "Peanut Butter Rice Cakes", calories: totalCalories / 6, items: ["3 Rice Cakes", "30g Natural Peanut Butter", "1 Apple"]),
                MealItem(time: "19:30", name: "Chickpea Coconut Curry", calories: Int(Double(totalCalories) * 0.3), items: ["200g Chickpeas", "100g Basmati Rice", "Light Coconut Milk & Spinach"])
            ] : [
                MealItem(time: "08:00", name: "Veganes Protein-Müsli", calories: totalCalories / 4, items: ["80g Haferflocken", "30g Erbsen-/Reisprotein", "Sojamilch", "Chiasamen & Beeren"]),
                MealItem(time: "12:30", name: "Tempeh & Quinoa Bowl", calories: Int(Double(totalCalories) * 0.35), items: ["180g Tempeh", "120g Quinoa", "Edamame & Gedünsteter Brokkoli"]),
                MealItem(time: "16:00", name: "Erdnussbutter-Reiswaffeln", calories: totalCalories / 6, items: ["3 Reiswaffeln", "30g Naturbelassene Erdnussbutter", "1 Apfel"]),
                MealItem(time: "19:30", name: "Kichererbsen-Kokos-Curry", calories: Int(Double(totalCalories) * 0.3), items: ["200g Kichererbsen", "100g Basmatireis", "Light-Kokosmilch & Blattspinat"])
            ]
            
        case .omnivore:
            return isEn ? [
                MealItem(time: "08:00", name: "Power Breakfast Bowl", calories: totalCalories / 4, items: ["3 Whole Eggs", "2 Slices Spelt Bread", "100g Smoked Salmon", "Avocado"]),
                MealItem(time: "12:30", name: "Chicken, Rice & Greens", calories: Int(Double(totalCalories) * 0.35), items: ["200g Chicken Breast", "120g Basmati Rice", "Steamed Broccoli & Olive Oil"]),
                MealItem(time: "16:00", name: "Pre-Workout Snack", calories: totalCalories / 6, items: ["1 Banana", "200g Low-fat Quark with Berries"]),
                MealItem(time: "19:30", name: "Lean Beef / Salmon Bowl", calories: Int(Double(totalCalories) * 0.3), items: ["180g Lean Rump Steak or Salmon", "200g Potatoes", "Mixed Green Salad"])
            ] : [
                MealItem(time: "08:00", name: "Power-Frühstück", calories: totalCalories / 4, items: ["3 Eier", "2 Scheiben Dinkelbrot", "100g Räucherlachs", "Avocado"]),
                MealItem(time: "12:30", name: "Hähnchenbrust, Reis & Brokkoli", calories: Int(Double(totalCalories) * 0.35), items: ["200g Hähnchenbrustfilet", "120g Basmatireis", "Gedünsteter Brokkoli & Olivenöl"]),
                MealItem(time: "16:00", name: "Pre-Workout Snack", calories: totalCalories / 6, items: ["1 Banane", "200g Magerquark mit Beeren"]),
                MealItem(time: "19:30", name: "Rinderfilet / Lachsfilet & Kartoffeln", calories: Int(Double(totalCalories) * 0.3), items: ["180g Mageres Rindersteak oder Lachs", "200g Kartoffeln", "Großer bunter Salat"])
            ]
        }
    }
    
    private func generateShakes(diet: DietType, language: String) -> [ShakeItem] {
        let isEn = language == "en"
        let isVegan = diet == .vegan
        let proteinType = isVegan ? (isEn ? "Vegan Blend" : "Veganes Proteinpulver") : (isEn ? "Whey Isolate" : "Whey Protein Isolat")
        
        return isEn ? [
            ShakeItem(when: "Directly Post-Workout", what: "30g \(proteinType) + 300ml Water + 5g Creatine Monohydrate"),
            ShakeItem(when: "Optional Evening Shake", what: "250ml Milk/Soy Milk + 25g Protein + 1 tbsp Peanut Butter")
        ] : [
            ShakeItem(when: "Direkt nach dem Training", what: "30g \(proteinType) + 300ml Wasser + 5g Kreatin Monohydrat"),
            ShakeItem(when: "Optional vor dem Schlafen", what: "250ml Milch/Sojamilch + 25g Casein/Protein + 1 EL Mandelmus")
        ]
    }
}
