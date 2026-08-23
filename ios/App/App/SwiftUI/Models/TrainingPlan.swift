import Foundation

public struct ExerciseSlot: Identifiable, Codable, Hashable {
    public var id = UUID()
    public let exercise: Exercise
    public var sets: Int
    public var reps: String
    public var restSeconds: Int
    public var note: String
    
    public init(exercise: Exercise, sets: Int = 3, reps: String = "8-12", restSeconds: Int = 60, note: String = "") {
        self.exercise = exercise
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
        self.note = note
    }
}

public struct WarmupExercise: Identifiable, Codable, Hashable {
    public var id = UUID()
    public let name: String
    public let duration: String
    
    public init(name: String, duration: String) {
        self.name = name
        self.duration = duration
    }
}

public struct DayPlan: Identifiable, Codable, Hashable {
    public var id = UUID()
    public let weekday: String // "Mo", "Di", "Mi", etc.
    public let name: String    // "Titan", "Vulkan", etc.
    public let focus: String   // "Chest & Triceps", "Glutes & Legs"
    public let warmup: [WarmupExercise]
    public var cycle1Slots: [ExerciseSlot]
    public var cycle2Slots: [ExerciseSlot]
    
    public var slots: [ExerciseSlot] {
        get { cycle1Slots }
        set { cycle1Slots = newValue }
    }
    
    public init(
        weekday: String,
        name: String,
        focus: String,
        warmup: [WarmupExercise] = [],
        cycle1Slots: [ExerciseSlot],
        cycle2Slots: [ExerciseSlot] = []
    ) {
        self.weekday = weekday
        self.name = name
        self.focus = focus
        self.warmup = warmup
        self.cycle1Slots = cycle1Slots
        self.cycle2Slots = cycle2Slots.isEmpty ? cycle1Slots : cycle2Slots
    }
    
    public init(weekday: String, name: String, focus: String, warmup: [WarmupExercise] = [], slots: [ExerciseSlot]) {
        self.weekday = weekday
        self.name = name
        self.focus = focus
        self.warmup = warmup
        self.cycle1Slots = slots
        self.cycle2Slots = slots
    }
    
    public func slots(forCycle cycle: Int) -> [ExerciseSlot] {
        return cycle == 2 ? cycle2Slots : cycle1Slots
    }
}

public struct TrainingPlan: Identifiable, Codable, Hashable {
    public var id = UUID()
    public let title: String
    public let summary: String
    public let weeks: Int
    public let days: [DayPlan]
    public let nutrition: NutritionPlan?
    public let notes: [String]
    public let createdAt: Date
    
    public init(
        title: String,
        summary: String,
        weeks: Int = 4,
        days: [DayPlan],
        nutrition: NutritionPlan? = nil,
        notes: [String] = [],
        createdAt: Date = Date()
    ) {
        self.title = title
        self.summary = summary
        self.weeks = weeks
        self.days = days
        self.nutrition = nutrition
        self.notes = notes
        self.createdAt = createdAt
    }
}

public struct LoggedSet: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var setNumber: Int
    public var weightKg: Double
    public var reps: Int
    public var isCompleted: Bool
    public var timestamp: Date?
    
    public init(setNumber: Int, weightKg: Double, reps: Int, isCompleted: Bool = false, timestamp: Date? = nil) {
        self.setNumber = setNumber
        self.weightKg = weightKg
        self.reps = reps
        self.isCompleted = isCompleted
        self.timestamp = timestamp
    }
}

public enum SplitType: String, CaseIterable, Identifiable, Codable {
    case fullBody = "Ganzkörper"
    case pushPullLegs = "Push/Pull/Beine"
    case upperLower = "Ober-/Unterkörper"
    case custom = "Eigene"
    
    public var id: String { rawValue }
    
    public var localizedEn: String {
        switch self {
        case .fullBody: return "Full Body"
        case .pushPullLegs: return "Push/Pull/Legs"
        case .upperLower: return "Upper/Lower"
        case .custom: return "Custom"
        }
    }
}

public enum TrainingMethod: String, CaseIterable, Identifiable, Codable {
    case standard = "standard"
    case fiveFourThree = "543"
    case fourFourThree = "443"
    case chestFocus = "brust-fokus"
    case backFocus = "ruecken-fokus"
    case legsFocus = "beine-fokus"
    
    public var id: String { rawValue }
    
    public var titleDe: String {
        switch self {
        case .standard: return "Standard"
        case .fiveFourThree: return "5x4x3"
        case .fourFourThree: return "4x4x3"
        case .chestFocus: return "Brust-Fokus"
        case .backFocus: return "Rücken-Fokus"
        case .legsFocus: return "Beine-Fokus"
        }
    }
    
    public var titleEn: String {
        switch self {
        case .standard: return "Standard"
        case .fiveFourThree: return "5×4×3"
        case .fourFourThree: return "4×4×3"
        case .chestFocus: return "Chest Focus"
        case .backFocus: return "Back Focus"
        case .legsFocus: return "Legs Focus"
        }
    }
}
