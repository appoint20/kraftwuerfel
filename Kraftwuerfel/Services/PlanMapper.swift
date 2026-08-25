import Foundation

/*
  Wandelt die JSON-Antwort von POST /generate-plan in einen TrainingPlan um.

  Der Server hat jede Übung schon gegen seinen Katalog geprüft. Hier wird nur
  noch gegen den Katalog der App aufgelöst — findet sich ein Name nicht (weil
  die App eine ältere Liste hat), fällt die Übung weg, statt einen leeren
  Platzhalter anzuzeigen.
*/
public enum PlanMapper {

    public static func trainingPlan(from raw: [String: Any], language: String) -> TrainingPlan? {
        guard let rawDays = raw["days"] as? [[String: Any]], !rawDays.isEmpty else { return nil }

        let byName = Dictionary(
            ExerciseDatabase.all.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let days: [DayPlan] = rawDays.compactMap { rawDay in
            guard let weekday = rawDay["weekday"] as? String else { return nil }

            let slots: [ExerciseSlot] = (rawDay["exercises"] as? [[String: Any]] ?? []).compactMap { ex in
                guard let name = ex["name"] as? String, let exercise = byName[name] else { return nil }
                return ExerciseSlot(
                    exercise: exercise,
                    sets: ex["sets"] as? Int ?? 3,
                    reps: ex["reps"] as? String ?? PlanGenerator.defaultReps,
                    restSeconds: ex["rest"] as? Int ?? 60,
                    note: ex["note"] as? String ?? ""
                )
            }
            guard !slots.isEmpty else { return nil }

            let warmup: [WarmupExercise] = (rawDay["warmup"] as? [[String: Any]] ?? []).compactMap {
                guard let name = $0["name"] as? String else { return nil }
                return WarmupExercise(name: name, duration: $0["duration"] as? String ?? "")
            }

            return DayPlan(
                weekday: weekday,
                // Das Modell vergibt den Rufnamen; fehlt er, springt die lokale
                // Namensliste ein, damit die Karte nie namenlos bleibt.
                name: (rawDay["name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    ?? PlanNames.planName(for: weekday),
                focus: rawDay["focus"] as? String ?? "",
                warmup: warmup,
                slots: slots
            )
        }

        guard !days.isEmpty else { return nil }

        return TrainingPlan(
            title: raw["title"] as? String ?? "",
            summary: raw["summary"] as? String ?? "",
            weeks: raw["weeks"] as? Int ?? 4,
            days: days,
            notes: raw["notes"] as? [String] ?? []
        )
    }
}
