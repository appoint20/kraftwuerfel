import Combine
import Foundation
import SwiftUI

public enum ChallengeCategory: String, CaseIterable, Identifiable, Codable {
    case calisthenics = "calisthenics"
    case squats = "squats"
    case plankAndWallsit = "plank_wallsit"
    case pushups = "pushups"
    case coreAbs = "core_abs"
    case fullBodyBlast = "fullbody_blast"

    public var id: String { rawValue }

    public func title(language: String) -> String {
        let isEn = language == "en"
        switch self {
        case .calisthenics: return isEn ? "Calisthenics Home Routine" : "Calisthenics Home Routine"
        case .squats: return isEn ? "Squats & Leg Power" : "Kniebeugen & Bein-Power"
        case .plankAndWallsit: return isEn ? "Wall-Sit & Plank Iron Core" : "Wall-Sit & Plank Haltekraft"
        case .pushups: return isEn ? "Push-Up Master Progression" : "Liegestütz-Meister"
        case .coreAbs: return isEn ? "Core & Sixpack Burner" : "Core & Sixpack Burner"
        case .fullBodyBlast: return isEn ? "Full Body Home Blast" : "Ganzkörper Home Blast"
        }
    }

    public var icon: String {
        switch self {
        case .calisthenics: return "figure.gymnastics"
        case .squats: return "figure.cross.training"
        case .plankAndWallsit: return "timer"
        case .pushups: return "figure.strengthtraining.traditional"
        case .coreAbs: return "flame.fill"
        case .fullBodyBlast: return "bolt.fill"
        }
    }
}

public struct DailyChallengeTask: Identifiable, Codable {
    public let id: String
    public let dayNumber: Int
    public let titleDe: String
    public let titleEn: String
    public let targetRepsOrTimeDe: String
    public let targetRepsOrTimeEn: String
    public let exerciseName: String
    public let tipDe: String
    public let tipEn: String

    public func title(for lang: String) -> String { lang == "en" ? titleEn : titleDe }
    public func target(for lang: String) -> String { lang == "en" ? targetRepsOrTimeEn : targetRepsOrTimeDe }
    public func tip(for lang: String) -> String { lang == "en" ? tipEn : tipDe }
}

public final class ChallengeStore: ObservableObject {
    public static let shared = ChallengeStore()

    @Published public var durationDays: Int {
        didSet { saveSettings() }
    }
    @Published public var category: ChallengeCategory {
        didSet { saveSettings() }
    }
    @Published public var reminderEnabled: Bool {
        didSet {
            saveSettings()
            updateNotifications()
        }
    }
    @Published public var reminderHour: Int {
        didSet {
            saveSettings()
            updateNotifications()
        }
    }
    @Published public var reminderMinute: Int {
        didSet {
            saveSettings()
            updateNotifications()
        }
    }

    @Published public var completedDays: Set<Int> = [] {
        didSet { saveProgress() }
    }
    @Published public var startDate: Date {
        didSet { saveProgress() }
    }
    @Published public var lastCompletedDate: Date? {
        didSet { saveProgress() }
    }

    private static let settingsKey = "kraftwuerfel:challenge_settings"
    private static let progressKey = "kraftwuerfel:challenge_progress"

    public static let availableDurations = [10, 20, 30, 45, 60, 90, 100]

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           let s = try? JSONDecoder().decode(SavedSettings.self, from: data) {
            self.durationDays = s.durationDays
            self.category = s.category
            self.reminderEnabled = s.reminderEnabled
            self.reminderHour = s.reminderHour
            self.reminderMinute = s.reminderMinute
        } else {
            self.durationDays = 30
            self.category = .calisthenics
            self.reminderEnabled = true
            self.reminderHour = 9
            self.reminderMinute = 0
        }

        if let data = UserDefaults.standard.data(forKey: Self.progressKey),
           let p = try? JSONDecoder().decode(SavedProgress.self, from: data) {
            self.completedDays = Set(p.completedDays)
            self.startDate = p.startDate
            self.lastCompletedDate = p.lastCompletedDate
        } else {
            self.completedDays = []
            self.startDate = Date()
            self.lastCompletedDate = nil
        }
    }

    public var currentDayNumber: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: Date())).day ?? 0
        return min(durationDays, max(1, days + 1))
    }

    public var isCompletedToday: Bool {
        completedDays.contains(currentDayNumber)
    }

    public var progressPercent: Double {
        guard durationDays > 0 else { return 0 }
        return Double(completedDays.count) / Double(durationDays)
    }

    public var streak: Int {
        completedDays.count
    }

    public func markTodayCompleted() {
        completedDays.insert(currentDayNumber)
        lastCompletedDate = Date()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /*
      Für die Kontolöschung (Art. 17 DSGVO).

      `resetChallenge()` setzt nur den Fortschritt zurück und schreibt ihn neu
      weg. Hier fallen beide Schlüssel als Ganzes weg — Fortschritt und
      Einstellungen —, und die geplanten Erinnerungen werden abbestellt.
    */
    public func wipe() {
        completedDays = []
        startDate = Date()
        lastCompletedDate = nil
        durationDays = 30
        category = .calisthenics
        reminderEnabled = true
        reminderHour = 9
        reminderMinute = 0

        NotificationManager.shared.cancelChallengeReminder()
        UserDefaults.standard.removeObject(forKey: Self.settingsKey)
        UserDefaults.standard.removeObject(forKey: Self.progressKey)
    }

    public func resetChallenge() {
        completedDays.removeAll()
        startDate = Date()
        lastCompletedDate = nil
        saveProgress()
        updateNotifications()
    }

    public func currentTask(language: String) -> DailyChallengeTask {
        taskForDay(currentDayNumber, category: category)
    }

    public func taskForDay(_ day: Int, category: ChallengeCategory) -> DailyChallengeTask {
        switch category {
        case .squats:
            let reps = 20 + (day * 5)
            return DailyChallengeTask(
                id: "sq_\(day)",
                dayNumber: day,
                titleDe: "Kniebeugen & Bein-Kraft",
                titleEn: "Squats & Leg Power",
                targetRepsOrTimeDe: "\(reps) Air Squats",
                targetRepsOrTimeEn: "\(reps) Air Squats",
                exerciseName: "Kniebeugen (Air Squats)",
                tipDe: "Halte den Rücken aufrecht und gehe bis in 90 Grad Tiefe.",
                tipEn: "Keep your chest up and squat down to a full 90-degree depth."
            )

        case .plankAndWallsit:
            let wallSec = min(180, 30 + (day * 4))
            let plankSec = min(180, 30 + (day * 3))
            return DailyChallengeTask(
                id: "ws_\(day)",
                dayNumber: day,
                titleDe: "Wall-Sit & Plank Haltekraft",
                titleEn: "Wall-Sit & Plank Static Hold",
                targetRepsOrTimeDe: "\(wallSec)s Wall-Sit + \(plankSec)s Plank",
                targetRepsOrTimeEn: "\(wallSec)s Wall-Sit + \(plankSec)s Plank",
                exerciseName: "Wandsitz & Unterarmstütz",
                tipDe: "Rücken fest an die Wand pressen, Oberschenkel parallel zum Boden.",
                tipEn: "Press your back flat against the wall, thighs parallel to the ground."
            )

        case .pushups:
            let reps = 15 + (day * 3)
            return DailyChallengeTask(
                id: "pu_\(day)",
                dayNumber: day,
                titleDe: "Liegestütz-Progression",
                titleEn: "Push-Up Progression",
                targetRepsOrTimeDe: "\(reps) Liegestütze",
                targetRepsOrTimeEn: "\(reps) Push-Ups",
                exerciseName: "Liegestütze (Push-Ups)",
                tipDe: "Körperspannung halten, Ellenbogen im 45-Grad-Winkel führen.",
                tipEn: "Keep your core tight, elbows at a 45-degree angle to your torso."
            )

        case .coreAbs:
            let crunches = 25 + (day * 3)
            let holdSec = min(120, 20 + (day * 3))
            return DailyChallengeTask(
                id: "core_\(day)",
                dayNumber: day,
                titleDe: "Core & Sixpack Blitz",
                titleEn: "Core & Sixpack Blitz",
                targetRepsOrTimeDe: "\(crunches) Crunches + \(holdSec)s Hollow Hold",
                targetRepsOrTimeEn: "\(crunches) Crunches + \(holdSec)s Hollow Hold",
                exerciseName: "Crunches & Hollow Body",
                tipDe: "Bauch aktiv anspannen, unterer Rücken bleibt fest auf der Matte.",
                tipEn: "Engage your lower abs, press your lower back firmly into the floor."
            )

        case .fullBodyBlast:
            let burpees = 10 + (day * 2)
            let lunges = 20 + (day * 2)
            return DailyChallengeTask(
                id: "fb_\(day)",
                dayNumber: day,
                titleDe: "Ganzkörper Bodyweight Blast",
                titleEn: "Full Body Bodyweight Blast",
                targetRepsOrTimeDe: "\(burpees) Burpees + \(lunges) Ausfallschritte",
                targetRepsOrTimeEn: "\(burpees) Burpees + \(lunges) Walking Lunges",
                exerciseName: "Burpees & Ausfallschritte",
                tipDe: "Konstantes Tempo halten, tiefe Atemzüge zwischen den Runden.",
                tipEn: "Maintain a steady pace and breathe rhythmically between reps."
            )

        case .calisthenics:
            let pushups = 15 + (day * 2)
            let squats = 25 + (day * 3)
            let plank = min(150, 30 + (day * 3))
            return DailyChallengeTask(
                id: "cal_\(day)",
                dayNumber: day,
                titleDe: "Calisthenics Home Routine",
                titleEn: "Calisthenics Home Routine",
                targetRepsOrTimeDe: "\(pushups) Push-Ups, \(squats) Squats, \(plank)s Plank",
                targetRepsOrTimeEn: "\(pushups) Push-Ups, \(squats) Squats, \(plank)s Plank",
                exerciseName: "Calisthenics Trio",
                tipDe: "Absolviere die 3 Übungen als Mini-Zirkel für maximalen Muskelreiz.",
                tipEn: "Perform these 3 exercises as a mini-circuit for maximum burn."
            )
        }
    }

    public func updateNotifications() {
        if reminderEnabled {
            NotificationManager.shared.scheduleChallengeReminder(
                hour: reminderHour,
                minute: reminderMinute,
                challengeTitle: category.title(language: I18n.shared.lang),
                dayNumber: currentDayNumber,
                totalDays: durationDays,
                language: I18n.shared.lang
            )
        } else {
            NotificationManager.shared.cancelChallengeReminder()
        }
    }

    private func saveSettings() {
        let s = SavedSettings(
            durationDays: durationDays,
            category: category,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute
        )
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }

    private func saveProgress() {
        let p = SavedProgress(
            completedDays: Array(completedDays),
            startDate: startDate,
            lastCompletedDate: lastCompletedDate
        )
        if let data = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(data, forKey: Self.progressKey)
        }
    }

    private struct SavedSettings: Codable {
        let durationDays: Int
        let category: ChallengeCategory
        let reminderEnabled: Bool
        let reminderHour: Int
        let reminderMinute: Int
    }

    private struct SavedProgress: Codable {
        let completedDays: [Int]
        let startDate: Date
        let lastCompletedDate: Date?
    }
}
