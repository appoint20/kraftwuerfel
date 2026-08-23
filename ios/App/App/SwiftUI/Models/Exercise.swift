import Foundation

public enum MuscleCategory: String, Codable, CaseIterable, Identifiable {
    case chest = "Brust"
    case back = "Rücken"
    case neck = "Nacken"
    case shoulders = "Schultern"
    case biceps = "Bizeps"
    case triceps = "Trizeps"
    case legs = "Beine"
    case glutes = "Gesäß"
    case calves = "Waden"
    case core = "Bauch"
    case fullBody = "Ganzkörper"
    
    public var id: String { rawValue }
    
    public var localized: String {
        switch self {
        case .chest: return "Brust"
        case .back: return "Rücken"
        case .neck: return "Nacken"
        case .shoulders: return "Schultern"
        case .biceps: return "Bizeps"
        case .triceps: return "Trizeps"
        case .legs: return "Beine"
        case .glutes: return "Gesäß"
        case .calves: return "Waden"
        case .core: return "Bauch"
        case .fullBody: return "Ganzkörper"
        }
    }
    
    public var localizedEn: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .neck: return "Neck"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .legs: return "Legs"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        case .core: return "Core"
        case .fullBody: return "Full Body"
        }
    }
}

public enum EquipmentType: String, Codable, CaseIterable, Identifiable {
    case barbell = "Langhantel"
    case dumbbell = "Kurzhantel"
    case machine = "Maschine"
    case cable = "Kabelzug"
    case bodyweight = "Körpergewicht"
    case smithMachine = "Multipresse"
    case kettlebell = "Kettlebell"
    case weightPlate = "Gewichtsscheibe"
    
    public var id: String { rawValue }
    
    public var localizedEn: String {
        switch self {
        case .barbell: return "Barbell"
        case .dumbbell: return "Dumbbell"
        case .machine: return "Machine"
        case .cable: return "Cable"
        case .bodyweight: return "Bodyweight"
        case .smithMachine: return "Smith Machine"
        case .kettlebell: return "Kettlebell"
        case .weightPlate: return "Weight Plate"
        }
    }
}

public struct Exercise: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let nameEn: String
    public let category: MuscleCategory
    public let equipment: EquipmentType
    public let isHeavy: Bool
    
    public init(name: String, nameEn: String, category: MuscleCategory, equipment: EquipmentType, isHeavy: Bool = false) {
        self.id = name.lowercased().replacingOccurrences(of: " ", with: "_")
        self.name = name
        self.nameEn = nameEn
        self.category = category
        self.equipment = equipment
        self.isHeavy = isHeavy
    }
    
    public func localizedName(language: String) -> String {
        language == "en" ? nameEn : name
    }
}

public enum ExerciseDatabase {
    public static let all: [Exercise] = [
        // Chest
        Exercise(name: "Bankdrücken", nameEn: "Bench Press", category: .chest, equipment: .barbell, isHeavy: true),
        Exercise(name: "Schrägbankdrücken (Kurzhantel)", nameEn: "Incline DB Bench Press", category: .chest, equipment: .dumbbell, isHeavy: true),
        Exercise(name: "Fliegende (Kabelzug)", nameEn: "Cable Flyes", category: .chest, equipment: .cable),
        Exercise(name: "Dips", nameEn: "Chest Dips", category: .chest, equipment: .bodyweight, isHeavy: true),
        Exercise(name: "Brustpresse", nameEn: "Chest Press Machine", category: .chest, equipment: .machine),
        Exercise(name: "Liegestütze", nameEn: "Push-ups", category: .chest, equipment: .bodyweight),
        
        // Back
        Exercise(name: "Kreuzheben", nameEn: "Deadlift", category: .back, equipment: .barbell, isHeavy: true),
        Exercise(name: "Klimmzüge", nameEn: "Pull-ups", category: .back, equipment: .bodyweight, isHeavy: true),
        Exercise(name: "Latzug breit", nameEn: "Lat Pulldown (Wide)", category: .back, equipment: .cable),
        Exercise(name: "Kabelrudern sitzend", nameEn: "Seated Cable Row", category: .back, equipment: .cable),
        Exercise(name: "Langhantelrudern", nameEn: "Barbell Row", category: .back, equipment: .barbell, isHeavy: true),
        Exercise(name: "Kurzhantelrudern einarmig", nameEn: "One-Arm DB Row", category: .back, equipment: .dumbbell),
        
        // Shoulders
        Exercise(name: "Overhead Press (Militärdrücken)", nameEn: "Military Press", category: .shoulders, equipment: .barbell, isHeavy: true),
        Exercise(name: "Seitheben (Kurzhantel)", nameEn: "Lateral Raises", category: .shoulders, equipment: .dumbbell),
        Exercise(name: "Seitheben am Kabelzug", nameEn: "Cable Lateral Raises", category: .shoulders, equipment: .cable),
        Exercise(name: "Face Pulls", nameEn: "Face Pulls", category: .shoulders, equipment: .cable),
        Exercise(name: "Frontheben", nameEn: "Front Raises", category: .shoulders, equipment: .dumbbell),
        
        // Legs & Glutes
        Exercise(name: "Kniebeugen", nameEn: "Barbell Squats", category: .legs, equipment: .barbell, isHeavy: true),
        Exercise(name: "Hip Thrust", nameEn: "Hip Thrust", category: .glutes, equipment: .barbell, isHeavy: true),
        Exercise(name: "Bulgarian Split Squats", nameEn: "Bulgarian Split Squats", category: .legs, equipment: .dumbbell, isHeavy: true),
        Exercise(name: "Rumänisches Kreuzheben", nameEn: "Romanian Deadlift", category: .glutes, equipment: .barbell, isHeavy: true),
        Exercise(name: "Beinpresse 45°", nameEn: "45° Leg Press", category: .legs, equipment: .machine, isHeavy: true),
        Exercise(name: "Beinbeuger liegend", nameEn: "Lying Leg Curls", category: .legs, equipment: .machine),
        Exercise(name: "Beinstrecker", nameEn: "Leg Extensions", category: .legs, equipment: .machine),
        Exercise(name: "Hüftabduktion (Maschine)", nameEn: "Hip Abduction Machine", category: .glutes, equipment: .machine),
        Exercise(name: "Wadenheben stehend", nameEn: "Standing Calf Raises", category: .calves, equipment: .machine),
        
        // Arms
        Exercise(name: "Langhantel-Curls", nameEn: "Barbell Bicep Curls", category: .biceps, equipment: .barbell),
        Exercise(name: "Hammer Curls", nameEn: "Hammer Curls", category: .biceps, equipment: .dumbbell),
        Exercise(name: "Konzentrationscurls", nameEn: "Concentration Curls", category: .biceps, equipment: .dumbbell),
        Exercise(name: "Trizepsdrücken am Kabel (Seil)", nameEn: "Tricep Cable Pushdown (Rope)", category: .triceps, equipment: .cable),
        Exercise(name: "French Press (Skull Crusher)", nameEn: "Skull Crushers", category: .triceps, equipment: .barbell),
        Exercise(name: "Dips an der Bank", nameEn: "Bench Dips", category: .triceps, equipment: .bodyweight),
        
        // Core
        Exercise(name: "Plank (Unterarmstütz)", nameEn: "Forearm Plank", category: .core, equipment: .bodyweight),
        Exercise(name: "Cable Crunches", nameEn: "Cable Crunches", category: .core, equipment: .cable),
        Exercise(name: "Beinheben hängend", nameEn: "Hanging Leg Raises", category: .core, equipment: .bodyweight),
        Exercise(name: "Russian Twists", nameEn: "Russian Twists", category: .core, equipment: .bodyweight),
        Exercise(name: "Ab Wheel Rollout", nameEn: "Ab Wheel Rollout", category: .core, equipment: .bodyweight)
    ]
}
