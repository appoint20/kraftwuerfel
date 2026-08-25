import ActivityKit
import Foundation

/*
  Der Vertrag zwischen App und Sperrbildschirm-Karte.

  Diese Datei wird in ZWEI Ziele übersetzt: in die App (die die Aktivität
  startet und aktualisiert) und in die Widget-Erweiterung (die sie zeichnet).
  ActivityKit gleicht Attribute und ContentState über den Typnamen ab — beide
  Seiten müssen daher buchstäblich dieselbe Quelle benutzen. Eine Kopie in der
  Erweiterung würde beim ersten Feldwechsel auseinanderlaufen, und die Karte
  bliebe wieder leer.

  Deshalb liegt der Typ hier unter Shared/ und in keinem der beiden Ordner.
*/

/// Woher der angezeigte Puls stammt. Der Sperrbildschirm muss das genauso
/// ehrlich zeigen wie die App — ein Schätzwert darf nirgends wie ein Messwert
/// aussehen.
public enum HeartRateSource: String, Codable, Hashable, Sendable {
    /// Aus dem Belastungsmodell gerechnet, kein Sensor beteiligt.
    case estimated
    /// Echte Messwerte, die die Apple Watch während der Sitzung liefert.
    case appleWatch
}

public struct WorkoutActivityAttributes: ActivityAttributes {

    /// Der Teil, der sich während des Trainings ändert.
    public struct ContentState: Codable, Hashable {
        public var exerciseName: String
        public var setNumber: Int
        public var totalSets: Int
        public var exerciseIndex: Int
        public var totalExercises: Int

        public var isResting: Bool
        /// Zeitpunkt, an dem die Pause endet. Die Karte zählt damit selbst
        /// herunter (`Text(timerInterval:)`), statt auf Updates zu warten —
        /// ActivityKit begrenzt die Update-Rate, ein Sekundentakt käme nie an.
        public var restEndsAt: Date?

        /// `nil`, solange nichts Belastbares vorliegt. Dann zeigt die Karte
        /// gar keinen Puls — lieber nichts als eine erfundene Zahl.
        public var heartRate: Int?
        public var heartRateSource: HeartRateSource

        /// Sprache der App zum Zeitpunkt des Updates. Die Erweiterung kann sie
        /// nicht selbst herausfinden — sie hat eigene UserDefaults.
        public var language: String

        public init(
            exerciseName: String,
            setNumber: Int,
            totalSets: Int,
            exerciseIndex: Int = 0,
            totalExercises: Int = 1,
            isResting: Bool = false,
            restEndsAt: Date? = nil,
            heartRate: Int? = nil,
            heartRateSource: HeartRateSource = .estimated,
            language: String = "de"
        ) {
            self.exerciseName = exerciseName
            self.setNumber = setNumber
            self.totalSets = totalSets
            self.exerciseIndex = exerciseIndex
            self.totalExercises = totalExercises
            self.isResting = isResting
            self.restEndsAt = restEndsAt
            self.heartRate = heartRate
            self.heartRateSource = heartRateSource
            self.language = language
        }
    }

    /// Der Teil, der über die ganze Sitzung gleich bleibt.
    public var planTitle: String
    public var startedAt: Date

    public init(planTitle: String, startedAt: Date = Date()) {
        self.planTitle = planTitle
        self.startedAt = startedAt
    }
}
