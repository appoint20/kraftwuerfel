import Foundation
import SwiftUI

/*
  WorkoutHistoryStore — Dauerhafte Speicherung und Auswertung aller absolvierten
  Live-Workouts (Trainingstagebuch & Fortschritt).

  Speichert für jede Trainingseinheit:
  - Datum, Dauer, verbrannte Kalorien, Spitzenpuls
  - Alle absolvierten Übungen mit ihren tatsächlich gestemmten Gewichten und Wdh
  - Berechnetes Gesamtvolumen (kg) und Steigerungswerte
*/

public struct LoggedExercise: Codable, Identifiable, Equatable {
    public var id: UUID
    public let exerciseId: String
    public let exerciseName: String
    public let category: MuscleCategory
    public let sets: [LoggedSet]

    public init(
        id: UUID = UUID(),
        exerciseId: String,
        exerciseName: String,
        category: MuscleCategory,
        sets: [LoggedSet]
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.category = category
        self.sets = sets
    }

    public var maxWeight: Double {
        sets.filter(\.done).map(\.weight).max() ?? (sets.map(\.weight).max() ?? 0)
    }

    public var totalVolume: Double {
        sets.filter(\.done).reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }

    public var completedSetsCount: Int {
        sets.filter(\.done).count
    }
}

public struct WorkoutSessionLog: Codable, Identifiable, Equatable {
    public var id: UUID
    public let date: Date
    public let planTitle: String
    public let durationSeconds: Int
    public let peakHeartRate: Double?
    public let estimatedCalories: Double?
    public let exercises: [LoggedExercise]
    public let motivationalQuote: String

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        planTitle: String,
        durationSeconds: Int,
        peakHeartRate: Double? = nil,
        estimatedCalories: Double? = nil,
        exercises: [LoggedExercise],
        motivationalQuote: String = ""
    ) {
        self.id = id
        self.date = date
        self.planTitle = planTitle
        self.durationSeconds = durationSeconds
        self.peakHeartRate = peakHeartRate
        self.estimatedCalories = estimatedCalories
        self.exercises = exercises
        self.motivationalQuote = motivationalQuote
    }

    public var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.totalVolume }
    }

    public var completedSetsCount: Int {
        exercises.reduce(0) { $0 + $1.completedSetsCount }
    }
}

public final class WorkoutHistoryStore: ObservableObject {
    public static let shared = WorkoutHistoryStore()

    @Published public private(set) var logs: [WorkoutSessionLog] = []

    private static let storageKey = "kraftwuerfel:workoutHistory"
    private let defaults = UserDefaults.standard

    private init() {
        load()
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.storageKey) else { return }
        if let decoded = try? JSONDecoder().decode([WorkoutSessionLog].self, from: data) {
            logs = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(logs) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    @discardableResult
    public func logSession(
        planTitle: String,
        durationSeconds: Int,
        peakHeartRate: Double?,
        estimatedCalories: Double?,
        exercises: [LoggedExercise],
        motivationalQuote: String
    ) -> WorkoutSessionLog {
        let entry = WorkoutSessionLog(
            date: Date(),
            planTitle: planTitle,
            durationSeconds: durationSeconds,
            peakHeartRate: peakHeartRate,
            estimatedCalories: estimatedCalories,
            exercises: exercises,
            motivationalQuote: motivationalQuote
        )
        logs.insert(entry, at: 0)
        persist()
        return entry
    }

    public func delete(id: UUID) {
        logs.removeAll { $0.id == id }
        persist()
    }

    public func wipe() {
        defaults.removeObject(forKey: Self.storageKey)
        logs = []
    }

    // MARK: - Auswertungen & Historie

    /// Liefert die letzten Werte für eine bestimmte Übung (für den Fokus-Modus "Letztes Mal: X kg × Y")
    public func mostRecentLog(for exerciseName: String) -> (weight: Double, reps: Int, date: Date)? {
        let cleanName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for session in logs {
            for ex in session.exercises {
                if ex.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleanName {
                    if let maxSet = ex.sets.filter(\.done).max(by: { $0.weight < $1.weight }) {
                        return (weight: maxSet.weight, reps: maxSet.reps, date: session.date)
                    } else if let firstSet = ex.sets.first {
                        return (weight: firstSet.weight, reps: firstSet.reps, date: session.date)
                    }
                }
            }
        }
        return nil
    }

    /// Alle einzigartigen Übungsnamen, die jemals trainiert wurden
    public var allLoggedExerciseNames: [String] {
        var names: [String] = []
        for session in logs {
            for ex in session.exercises {
                let trimmed = ex.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && !names.contains(trimmed) {
                    names.append(trimmed)
                }
            }
        }
        return names.sorted()
    }

    /// Chronologische Historie für eine bestimmte Übung (für den Fortschrittsgraphen)
    public func exerciseProgression(for exerciseName: String) -> [(date: Date, maxWeight: Double, volume: Double, totalReps: Int)] {
        let cleanName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var points: [(date: Date, maxWeight: Double, volume: Double, totalReps: Int)] = []

        // Chronologisch von alt nach neu sortiert
        for session in logs.reversed() {
            for ex in session.exercises {
                if ex.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleanName {
                    let totalReps = ex.sets.filter(\.done).reduce(0) { $0 + $1.reps }
                    points.append((
                        date: session.date,
                        maxWeight: ex.maxWeight,
                        volume: ex.totalVolume,
                        totalReps: totalReps
                    ))
                }
            }
        }
        return points
    }

    // MARK: - Globale Statistiken

    /*
      Die Tage, an denen schon trainiert wurde — auf Mitternacht normalisiert.

      Die Trainingserinnerung um neun braucht sie, um Tage auszulassen, an
      denen das Training längst im Archiv steht. Nur die letzten Wochen, weil
      die Erinnerungen ohnehin nur so weit im Voraus geplant werden.
    */
    public func trainedDates(since: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()) -> Set<Date> {
        let calendar = Calendar.current
        return Set(
            logs.filter { $0.date >= since }.map { calendar.startOfDay(for: $0.date) }
        )
    }

    public var totalWorkoutsCount: Int { logs.count }

    public var totalVolumeKg: Double {
        logs.reduce(0) { $0 + $1.totalVolume }
    }

    public var totalDurationMinutes: Int {
        logs.reduce(0) { $0 + ($1.durationSeconds / 60) }
    }
}
