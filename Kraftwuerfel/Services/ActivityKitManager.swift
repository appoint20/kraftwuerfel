import ActivityKit
import Foundation

/*
  Startet, aktualisiert und beendet die Sperrbildschirm-Karte.

  Die vorherige Fassung rief alles richtig auf und trotzdem passierte nichts:
  Der `ActivityAttributes`-Typ lag nur in der App, und es gab kein Ziel mit
  einer `ActivityConfiguration`. ActivityKit nimmt die Anfrage in so einem Fall
  entgegen, findet aber nichts, was die Karte zeichnen könnte — der
  Sperrbildschirm blieb leer, ohne Fehlermeldung.

  Jetzt liegt der Typ in Shared/ (App + Erweiterung), und
  KraftwuerfelWidget zeichnet ihn. Zwei Dinge bleiben hier wichtig:

  1. Pausen laufen über ein Zieldatum, nicht über Restsekunden. ActivityKit
     drosselt Updates; ein Sekundentakt käme gar nicht an. Die Karte zählt
     selbst herunter.

  2. Alles ist an den Main-Actor gebunden. `currentActivity` wurde vorher aus
     mehreren Tasks gelesen und geschrieben.
*/
@MainActor
public final class ActivityKitManager {
    public static let shared = ActivityKitManager()

    private var activity: Activity<WorkoutActivityAttributes>?

    /// Der zuletzt gesendete Zustand. Teil-Updates (nur der Puls, nur die
    /// Pause) müssen die übrigen Felder erhalten — vorher hat
    /// `updateRestTimer` die Satzzahl aus dem Aktivitätszustand zurückgelesen
    /// und alles andere stillschweigend auf die Vorgabewerte gesetzt.
    private var state: WorkoutActivityAttributes.ContentState?

    private init() {}

    public var isRunning: Bool { activity != nil }

    /// `false`, wenn der Nutzer Live-Aktivitäten für die App abgeschaltet hat.
    /// Der Aufrufer kann das anzeigen, statt sich zu wundern.
    public var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Start

    public func start(
        planTitle: String,
        exerciseName: String,
        setNumber: Int,
        totalSets: Int,
        exerciseIndex: Int,
        totalExercises: Int,
        language: String
    ) {
        guard activity == nil, areActivitiesEnabled else { return }

        let initial = WorkoutActivityAttributes.ContentState(
            exerciseName: exerciseName,
            setNumber: setNumber,
            totalSets: totalSets,
            exerciseIndex: exerciseIndex,
            totalExercises: totalExercises,
            language: language
        )

        do {
            activity = try Activity.request(
                attributes: WorkoutActivityAttributes(planTitle: planTitle),
                content: ActivityContent(state: initial, staleDate: nil),
                pushType: nil
            )
            state = initial
        } catch {
            // Häufigster Grund: das Kontingent gleichzeitiger Aktivitäten ist
            // voll oder der Nutzer hat sie abgeschaltet. Kein Grund, das
            // Training zu stören.
            activity = nil
            state = nil
        }
    }

    // MARK: - Aktualisieren

    public func setActiveSet(
        exerciseName: String,
        setNumber: Int,
        totalSets: Int,
        exerciseIndex: Int,
        totalExercises: Int,
        language: String
    ) {
        mutate {
            $0.exerciseName = exerciseName
            $0.setNumber = setNumber
            $0.totalSets = totalSets
            $0.exerciseIndex = exerciseIndex
            $0.totalExercises = totalExercises
            $0.isResting = false
            $0.restEndsAt = nil
            $0.language = language
        }
    }

    /// Die Karte bekommt das Ende der Pause, nicht die Restsekunden.
    public func startRest(until endDate: Date) {
        mutate {
            $0.isResting = true
            $0.restEndsAt = endDate
        }
    }

    public func endRest() {
        mutate {
            $0.isResting = false
            $0.restEndsAt = nil
        }
    }

    /// `nil` blendet den Puls auf der Karte aus — genau das ist gewollt,
    /// solange nichts Belastbares vorliegt.
    public func setHeartRate(_ bpm: Int?, source: HeartRateSource) {
        mutate {
            $0.heartRate = bpm
            $0.heartRateSource = source
        }
    }

    // MARK: - Ende

    public func end() {
        guard let activity else { return }
        let final = state
        self.activity = nil
        self.state = nil

        Task {
            await activity.end(
                final.map { ActivityContent(state: $0, staleDate: nil) },
                dismissalPolicy: .immediate
            )
        }
    }

    // MARK: - Intern

    /// Ein Update = aktueller Zustand + Änderung. Nie ein frisch gebauter
    /// Zustand, sonst verliert die Karte Felder, die gerade nicht Thema sind.
    private func mutate(_ change: (inout WorkoutActivityAttributes.ContentState) -> Void) {
        guard let activity, var next = state else { return }
        change(&next)
        guard next != state else { return }   // nichts geändert, nichts senden
        state = next

        Task {
            await activity.update(ActivityContent(state: next, staleDate: nil))
        }
    }
}
