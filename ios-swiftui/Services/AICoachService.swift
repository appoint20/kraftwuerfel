import Foundation

public struct AICoachRequest: Codable {
    public let sex: String
    public let age: Int
    public let height: Int
    public let weight: Int
    public let goal: String
    public let experience: String
    public let days: [String]
    public let sessionMinutes: Int
    public let equipment: [String]
    public let focus: [String]
    public let limitations: String
    public let weeks: Int
    public let language: String
    public let warmup: String
    public let diet: String
    
    public init(
        sex: String,
        age: Int,
        height: Int,
        weight: Int,
        goal: String,
        experience: String,
        days: [String],
        sessionMinutes: Int,
        equipment: [String],
        focus: [String],
        limitations: String,
        weeks: Int,
        language: String,
        warmup: String,
        diet: String
    ) {
        self.sex = sex
        self.age = age
        self.height = height
        self.weight = weight
        self.goal = goal
        self.experience = experience
        self.days = days
        self.sessionMinutes = sessionMinutes
        self.equipment = equipment
        self.focus = focus
        self.limitations = limitations
        self.weeks = weeks
        self.language = language
        self.warmup = warmup
        self.diet = diet
    }
}

public final class AICoachService {
    public static let shared = AICoachService()
    
    public func generatePlan(from request: AICoachRequest) async throws -> TrainingPlan {
        // 1. Calculate Mifflin-St Jeor BMR & Calories
        let isFemale = request.sex == "female"
        let bmr: Double = isFemale
            ? 10.0 * Double(request.weight) + 6.25 * Double(request.height) - 5.0 * Double(request.age) - 161.0
            : 10.0 * Double(request.weight) + 6.25 * Double(request.height) - 5.0 * Double(request.age) + 5.0
        
        let activityMultiplier = 1.2 + min(Double(request.days.count), 6.0) * 0.075
        var dailyCalories = Int(round((bmr * activityMultiplier) / 10.0) * 10.0)
        
        if request.goal == "abnehmen" || request.goal == "definition" {
            dailyCalories -= 400
        } else if request.goal == "muscle" || request.goal == "strength" {
            dailyCalories += 300
        }
        dailyCalories = max(1200, dailyCalories)
        
        let proteinPerKg = (request.goal == "abnehmen" || request.goal == "definition") ? 2.0 : 1.8
        let protein = Int(round(Double(request.weight) * proteinPerKg))
        let fat = Int(round(Double(dailyCalories) * 0.27 / 9.0))
        let carbs = max(0, Int(round(Double(dailyCalories - protein * 4 - fat * 9) / 4.0)))
        
        let dietType = DietType(rawValue: request.diet) ?? .omnivore
        let proteinSource: String
        switch dietType {
        case .vegan:
            proteinSource = "Tofu, Linsen, Kichererbsen, Edamame"
        case .lactoVegetarian:
            proteinSource = "Magerquark, Hüttenkäse, Paneer, Griechischer Joghurt, Milch"
        case .vegetarian:
            proteinSource = "Magerquark, Eier, Hüttenkäse, Tofu"
        case .omnivore:
            proteinSource = "Hähnchenbrust, Lachs, Magerquark, Rindfleisch"
        }
        
        let shakeBase = dietType == .vegan
            ? "Veganes Erbsen-/Reisprotein mit Hafermilch"
            : "Whey Protein Isolat mit fettarmer Milch oder Wasser"
        
        let meals = [
            MealItem(time: "07:30", name: "Frühstück", calories: Int(Double(dailyCalories) * 0.25), items: ["Haferflocken", "Beeren", dietType == .vegan ? "Sojamilch" : "Magerquark"]),
            MealItem(time: "12:30", name: "Mittagessen", calories: Int(Double(dailyCalories) * 0.35), items: [proteinSource, "Reis oder Süßkartoffeln", "Brokkoli & Gemüse"]),
            MealItem(time: "16:00", name: "Pre-Workout Snack", calories: Int(Double(dailyCalories) * 0.15), items: ["Banane", "Mandeln", dietType == .vegan ? "Pflanzendrink" : "Griechischer Joghurt"]),
            MealItem(time: "19:30", name: "Abendessen", calories: Int(Double(dailyCalories) * 0.25), items: [proteinSource, "Großer bunter Salat", "Vollkornbrot"])
        ]
        
        let shakes = [
            ShakeItem(when: "Direkt nach dem Training", what: "\(shakeBase) (30g Protein)")
        ]
        
        let nutrition = NutritionPlan(
            diet: dietType,
            dailyCalories: dailyCalories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            meals: meals,
            shakes: shakes,
            notes: ["Trinke täglich mindestens 2,5 bis 3,5 Liter Wasser.", "Achte auf ausreichend Mikronährstoffe und mindestens 7-8 Stunden Schlaf."],
            disclaimer: "Richtwerte auf Basis deiner Angaben, keine medizinische Ernährungsberatung."
        )
        
        // 2. Build Day Plans
        var dayPlans: [DayPlan] = []
        let sampleWarmup = [
            WarmupExercise(name: "5 Min Laufband / Rudergerät", duration: "5 min"),
            WarmupExercise(name: "Dynamisches Dehnen & Hüftkreisen", duration: "3 min")
        ]
        
        for (index, day) in request.days.enumerated() {
            let name = ["Titan", "Vulkan", "Atlas", "Nova", "Granit"][index % 5]
            let focus: String
            var slots: [ExerciseSlot] = []
            
            if isFemale {
                if index % 2 == 0 {
                    focus = "Glutes & Legs Focus"
                    slots = [
                        ExerciseSlot(exercise: Exercise(name: "Hip Thrust", nameEn: "Hip Thrust", category: .glutes, equipment: .barbell, isHeavy: true), sets: 4, reps: "8-12", note: "Peak Kontraktion oben 1s halten"),
                        ExerciseSlot(exercise: Exercise(name: "Bulgarian Split Squats", nameEn: "Bulgarian Split Squats", category: .legs, equipment: .dumbbell, isHeavy: true), sets: 3, reps: "10-12", note: "Fester Stand"),
                        ExerciseSlot(exercise: Exercise(name: "Rumänisches Kreuzheben", nameEn: "Romanian Deadlift", category: .glutes, equipment: .barbell, isHeavy: true), sets: 3, reps: "10-12", note: "Rücken gerade halten"),
                        ExerciseSlot(exercise: Exercise(name: "Hüftabduktion (Maschine)", nameEn: "Hip Abduction", category: .glutes, equipment: .machine), sets: 3, reps: "15-20", note: "Gluteus Medius Brennen"),
                        ExerciseSlot(exercise: Exercise(name: "Plank (Unterarmstütz)", nameEn: "Plank", category: .core, equipment: .bodyweight), sets: 3, reps: "60s", note: "Core Spannung")
                    ]
                } else {
                    focus = "Upper Body & Posture"
                    slots = [
                        ExerciseSlot(exercise: Exercise(name: "Latzug breit", nameEn: "Lat Pulldown (Wide)", category: .back, equipment: .cable), sets: 3, reps: "10-12", note: "Schulterblätter zusammen"),
                        ExerciseSlot(exercise: Exercise(name: "Schrägbankdrücken (Kurzhantel)", nameEn: "Incline DB Bench Press", category: .chest, equipment: .dumbbell), sets: 3, reps: "10-12", note: "Obere Brust betonen"),
                        ExerciseSlot(exercise: Exercise(name: "Kabelrudern sitzend", nameEn: "Seated Cable Row", category: .back, equipment: .cable), sets: 3, reps: "12", note: "Aufrechte Haltung"),
                        ExerciseSlot(exercise: Exercise(name: "Seitheben am Kabelzug", nameEn: "Cable Lateral Raises", category: .shoulders, equipment: .cable), sets: 3, reps: "12-15", note: "Seitliche Schulter"),
                        ExerciseSlot(exercise: Exercise(name: "Russian Twists", nameEn: "Russian Twists", category: .core, equipment: .bodyweight), sets: 3, reps: "20", note: "Seitliche Bauchmuskeln")
                    ]
                }
            } else {
                focus = index % 2 == 0 ? "Push (Chest & Shoulders)" : "Pull (Back & Biceps)"
                slots = [
                    ExerciseSlot(exercise: Exercise(name: "Bankdrücken", nameEn: "Bench Press", category: .chest, equipment: .barbell, isHeavy: true), sets: 4, reps: "6-8", note: "Stabile Schultern"),
                    ExerciseSlot(exercise: Exercise(name: "Schrägbankdrücken (Kurzhantel)", nameEn: "Incline DB Press", category: .chest, equipment: .dumbbell), sets: 3, reps: "8-10", note: "Volle Dehnung"),
                    ExerciseSlot(exercise: Exercise(name: "Overhead Press (Militärdrücken)", nameEn: "Military Press", category: .shoulders, equipment: .barbell, isHeavy: true), sets: 3, reps: "8-10", note: "Core fest anspannen"),
                    ExerciseSlot(exercise: Exercise(name: "Trizepsdrücken am Kabel (Seil)", nameEn: "Tricep Pushdown", category: .triceps, equipment: .cable), sets: 3, reps: "12-15", note: "Arme ganz durchstrecken")
                ]
            }
            
            dayPlans.append(DayPlan(weekday: day, name: name, focus: focus, warmup: request.warmup == "no" ? [] : sampleWarmup, slots: slots))
        }
        
        return TrainingPlan(
            title: "KI-Trainingsplan (\(request.days.count) Tage)",
            summary: "Personalisierter \(request.weeks)-Wochen Plan optimiert für \(request.goal.uppercased()) und Ernährungsform \(dietType.titleDe).",
            weeks: request.weeks,
            days: dayPlans,
            nutrition: nutrition,
            notes: ["Führe jede Wiederholung kontrolliert aus.", "Steigere das Gewicht, sobald du die Maximalwiederholungen sauber schaffst."]
        )
    }
}
