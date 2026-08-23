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
        case .chest: return NSLocalizedString("Chest", comment: "")
        case .back: return NSLocalizedString("Back", comment: "")
        case .neck: return NSLocalizedString("Neck", comment: "")
        case .shoulders: return NSLocalizedString("Shoulders", comment: "")
        case .biceps: return NSLocalizedString("Biceps", comment: "")
        case .triceps: return NSLocalizedString("Triceps", comment: "")
        case .legs: return NSLocalizedString("Legs", comment: "")
        case .glutes: return NSLocalizedString("Glutes", comment: "")
        case .calves: return NSLocalizedString("Calves", comment: "")
        case .core: return NSLocalizedString("Core", comment: "")
        case .fullBody: return NSLocalizedString("Full Body", comment: "")
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
    
    public var localized: String {
        switch self {
        case .barbell: return NSLocalizedString("Barbell", comment: "")
        case .dumbbell: return NSLocalizedString("Dumbbell", comment: "")
        case .machine: return NSLocalizedString("Machine", comment: "")
        case .cable: return NSLocalizedString("Cable", comment: "")
        case .bodyweight: return NSLocalizedString("Bodyweight", comment: "")
        case .smithMachine: return NSLocalizedString("Smith Machine", comment: "")
        case .kettlebell: return NSLocalizedString("Kettlebell", comment: "")
        case .weightPlate: return NSLocalizedString("Weight Plate", comment: "")
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
    
    public func localizedName(language: String = Locale.current.language.languageCode?.identifier ?? "de") -> String {
        language == "en" ? nameEn : name
    }
}

// MARK: - Exercise Catalogue
public enum ExerciseDatabase {
    public static let all: [Exercise] = [
        // Chest
        Exercise(name: "Bankdrücken", nameEn: "Bench Press", category: .chest, equipment: .barbell, isHeavy: true),
        Exercise(name: "Schrägbankdrücken (Kurzhantel)", nameEn: "Incline DB Bench Press", category: .chest, equipment: .dumbbell, isHeavy: true),
        Exercise(name: "Fliegende (Kabelzug)", nameEn: "Cable Flyes", category: .chest, equipment: .cable),
        Exercise(name: "Dips", nameEn: "Chest Dips", category: .chest, equipment: .bodyweight, isHeavy: true),
        Exercise(name: "Brustpresse", nameEn: "Chest Press Machine", category: .chest, equipment: .machine),
        
        // Back
        Exercise(name: "Kreuzheben", nameEn: "Deadlift", category: .back, equipment: .barbell, isHeavy: true),
        Exercise(name: "Klimmzüge", nameEn: "Pull-ups", category: .back, equipment: .bodyweight, isHeavy: true),
        Exercise(name: "Latzug breit", nameEn: "Lat Pulldown (Wide)", category: .back, equipment: .cable),
        Exercise(name: "Kabelrudern sitzend", nameEn: "Seated Cable Row", category: .back, equipment: .cable),
        Exercise(name: "Langhantelrudern", nameEn: "Barbell Row", category: .back, equipment: .barbell, isHeavy: true),
        
        // Shoulders
        Exercise(name: "Overhead Press (Militärdrücken)", nameEn: "Military Press", category: .shoulders, equipment: .barbell, isHeavy: true),
        Exercise(name: "Seitheben (Kurzhantel)", nameEn: "Lateral Raises", category: .shoulders, equipment: .dumbbell),
        Exercise(name: "Seitheben am Kabelzug", nameEn: "Cable Lateral Raises", category: .shoulders, equipment: .cable),
        Exercise(name: "Face Pulls", nameEn: "Face Pulls", category: .shoulders, equipment: .cable),
        
        // Legs & Glutes
        Exercise(name: "Kniebeugen", nameEn: "Barbell Squats", category: .legs, equipment: .barbell, isHeavy: true),
        Exercise(name: "Hip Thrust", nameEn: "Hip Thrust", category: .glutes, equipment: .barbell, isHeavy: true),
        Exercise(name: "Bulgarian Split Squats", nameEn: "Bulgarian Split Squats", category: .legs, equipment: .dumbbell, isHeavy: true),
        Exercise(name: "Rumänisches Kreuzheben", nameEn: "Romanian Deadlift", category: .glutes, equipment: .barbell, isHeavy: true),
        Exercise(name: "Beinpresse 45°", nameEn: "45° Leg Press", category: .legs, equipment: .machine, isHeavy: true),
        Exercise(name: "Beinbeuger liegend", nameEn: "Lying Leg Curls", category: .legs, equipment: .machine),
        Exercise(name: "Hüftabduktion (Maschine)", nameEn: "Hip Abduction Machine", category: .glutes, equipment: .machine),
        
        // Arms
        Exercise(name: "Langhantel-Curls", nameEn: "Barbell Bicep Curls", category: .biceps, equipment: .barbell),
        Exercise(name: "Hammer Curls", nameEn: "Hammer Curls", category: .biceps, equipment: .dumbbell),
        Exercise(name: "Trizepsdrücken am Kabel (Seil)", nameEn: "Tricep Cable Pushdown (Rope)", category: .triceps, equipment: .cable),
        Exercise(name: "French Press (Skull Crusher)", nameEn: "Skull Crushers", category: .triceps, equipment: .barbell),
        
        // Core
        Exercise(name: "Plank (Unterarmstütz)", nameEn: "Forearm Plank", category: .core, equipment: .bodyweight),
        Exercise(name: "Cable Crunches", nameEn: "Cable Crunches", category: .core, equipment: .cable),
        Exercise(name: "Beinheben hängend", nameEn: "Hanging Leg Raises", category: .core, equipment: .bodyweight),
        Exercise(name: "Russian Twists", nameEn: "Russian Twists", category: .core, equipment: .bodyweight),
    ]
}
