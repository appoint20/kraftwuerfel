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
    public let slots: [ExerciseSlot]
    
    public init(weekday: String, name: String, focus: String, warmup: [WarmupExercise] = [], slots: [ExerciseSlot]) {
        self.weekday = weekday
        self.name = name
        self.focus = focus
        self.warmup = warmup
        self.slots = slots
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
