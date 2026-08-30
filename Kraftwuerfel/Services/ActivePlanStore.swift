import Foundation
import SwiftUI

/*
  Portierung von hooks/useActivePlan.js für den lokalen Modus.

  Es gibt höchstens einen laufenden Plan. Starten überschreibt, Beenden
  löscht — genauso wie im Web.
*/
public final class ActivePlanStore: ObservableObject {
    public static let shared = ActivePlanStore()

    private static let storageKey = "kraftwuerfel:activePlan"

    @Published public private(set) var plan: ActivePlan?
    @Published public var status: String?

    private init() { load() }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(ActivePlan.self, from: data)
        else { return }
        plan = decoded
    }

    private func persist() {
        guard let plan, let data = try? JSONEncoder().encode(plan) else {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
            return
        }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    public func start(
        days: [String],
        duration: Int,
        split: String,
        method: TrainingMethod,
        count: Int,
        restTime: Int,
        dayPlans: [String: [[ExerciseSlot]]]
    ) {
        plan = ActivePlan(
            // Auf Mitternacht normalisiert, damit die Wochenrechnung nicht an
            // der Uhrzeit des Starts hängt.
            startDate: PlanProgress.normalize(Date()),
            duration: duration,
            days: days,
            split: split,
            method: method,
            count: count,
            restTime: restTime,
            dayPlans: dayPlans
        )
        persist()
        status = I18n.shared.t("tp.started")
        clearStatusSoon()
    }

    // MARK: - Einen fertigen Plan aktiv setzen

    /*
      Jeden Plan starten können, nicht nur einen frisch gewürfelten.

      Bisher führte genau ein Weg zum laufenden Plan: im Trainingsplan-Tab
      würfeln und starten. Ein KI-Plan, ein gespeicherter Plan oder ein selbst
      zusammengestellter ließ sich zwar ansehen und als Live-Session starten,
      aber nie als Plan verfolgen — der Fortschritt über Wochen, die Zyklen
      und die Wochentagsansicht blieben dem Würfel vorbehalten.

      Beide Wege enden hier, damit es weiterhin genau einen laufenden Plan
      gibt und genau eine Stelle, die ihn schreibt.
    */

    /// Einen KI- oder gespeicherten Wochenplan übernehmen.
    public func activate(trainingPlan: TrainingPlan, title: String? = nil) {
        let days = trainingPlan.days.map(\.weekday)
        guard !days.isEmpty else { return }

        var dayPlans: [String: [[ExerciseSlot]]] = [:]
        for day in trainingPlan.days {
            var cycles: [[ExerciseSlot]] = [day.cycle1Slots]
            /*
              `hasDistinctCycles` und nicht `!cycle2Slots.isEmpty`: DayPlan.init
              füllt einen leeren zweiten Zyklus mit einer Kopie des ersten auf,
              `cycle2Slots` ist also nie leer. Mit der naheliegenden Prüfung
              bekäme jeder Plan zwei Reiter, hinter denen zweimal dasselbe
              steht.
            */
            if day.hasDistinctCycles { cycles.append(day.cycle2Slots) }
            dayPlans[day.weekday] = cycles
        }

        let counts = trainingPlan.days.map(\.cycle1Slots.count)
        let restTimes = trainingPlan.days.flatMap(\.cycle1Slots).map(\.restSeconds)

        plan = ActivePlan(
            startDate: PlanProgress.normalize(Date()),
            duration: max(1, trainingPlan.weeks),
            days: Weekdays.sorted(Set(days)),
            split: trainingPlan.title,
            method: .standard,
            count: counts.max() ?? 6,
            restTime: restTimes.first ?? 60,
            dayPlans: dayPlans,
            title: title ?? trainingPlan.title
        )
        persist()
        status = I18n.shared.t("tp.started")
        clearStatusSoon()
    }

    /*
      Ein einzelnes Workout auf mehrere Wochentage legen.

      Ein gespeicherter oder selbst gebauter Plan ist EINE Einheit, kein
      Wochenplan. Damit daraus ein verfolgbarer Plan wird, läuft dieselbe
      Einheit an den gewählten Tagen — das ist genau das, was jemand meint,
      der „diesen Plan 4 Wochen lang dreimal die Woche" sagt.
    */
    public func activate(
        slots: [ExerciseSlot],
        name: String,
        days: [String],
        durationWeeks: Int = 4
    ) {
        let cleanDays = Weekdays.sorted(Set(days.isEmpty ? ["Mo", "Mi", "Fr"] : days))
        guard !slots.isEmpty else { return }

        var dayPlans: [String: [[ExerciseSlot]]] = [:]
        for day in cleanDays { dayPlans[day] = [slots] }

        plan = ActivePlan(
            startDate: PlanProgress.normalize(Date()),
            duration: max(1, durationWeeks),
            days: cleanDays,
            split: name,
            method: .standard,
            count: slots.count,
            restTime: slots.first?.restSeconds ?? 60,
            dayPlans: dayPlans,
            title: name
        )
        persist()
        status = I18n.shared.t("tp.started")
        clearStatusSoon()
    }

    // MARK: - Den laufenden Plan anpassen

    /*
      Der laufende Plan ist kein Betonblock mehr.

      Bisher stand er ab dem Start fest: Wer eine Übung nicht machen konnte —
      Bank besetzt, Knie zwickt, Gerät defekt — musste den ganzen Plan
      beenden und neu würfeln. Damit war der Fortschritt weg, und der Preis
      für eine einzelne getauschte Übung war die ganze Woche.

      Alle Änderungen laufen über `mutate`, damit es genau eine Stelle gibt,
      die schreibt und speichert.
    */
    private func mutate(_ change: (inout ActivePlan) -> Bool) {
        guard var current = plan else { return }
        guard change(&current) else { return }
        plan = current
        persist()
    }

    /// Die Übungen eines Tages in einem Zyklus — leer, wenn es sie nicht gibt.
    public func slots(day: String, cycle: Int) -> [ExerciseSlot] {
        guard let cycles = plan?.dayPlans[day], cycles.indices.contains(cycle) else { return [] }
        return cycles[cycle]
    }

    /// Eine einzelne Übung gegen eine andere aus dem Katalog tauschen.
    public func replaceSlot(day: String, cycle: Int, at index: Int, with exercise: Exercise) {
        mutate { plan in
            guard var cycles = plan.dayPlans[day], cycles.indices.contains(cycle),
                  cycles[cycle].indices.contains(index) else { return false }
            let old = cycles[cycle][index]
            cycles[cycle][index] = ExerciseSlot(
                exercise: exercise,
                sets: old.sets,
                reps: old.reps,
                restSeconds: old.restSeconds,
                note: old.note
            )
            plan.dayPlans[day] = cycles
            return true
        }
    }

    /*
      Eine einzelne Übung neu würfeln. Satzschema und Pause bleiben stehen —
      getauscht wird die Übung, nicht die Belastung.
    */
    public func rerollSlot(day: String, cycle: Int, at index: Int, method: TrainingMethod) {
        mutate { plan in
            guard var cycles = plan.dayPlans[day], cycles.indices.contains(cycle),
                  let fresh = PlanGenerator.rerollSlot(plan: cycles[cycle], at: index, method: method)
            else { return false }
            cycles[cycle][index] = fresh
            plan.dayPlans[day] = cycles
            return true
        }
    }

    public func removeSlot(day: String, cycle: Int, at index: Int) {
        mutate { plan in
            guard var cycles = plan.dayPlans[day], cycles.indices.contains(cycle),
                  cycles[cycle].indices.contains(index),
                  // Ein Trainingstag ohne eine einzige Übung wäre keiner.
                  cycles[cycle].count > 1
            else { return false }
            cycles[cycle].remove(at: index)
            plan.dayPlans[day] = cycles
            return true
        }
    }

    public func addSlot(day: String, cycle: Int, exercise: Exercise) {
        mutate { plan in
            guard var cycles = plan.dayPlans[day], cycles.indices.contains(cycle) else { return false }
            let rest = cycles[cycle].last?.restSeconds ?? plan.restTime
            let reps = cycles[cycle].last?.reps ?? PlanGenerator.defaultReps
            cycles[cycle].append(
                ExerciseSlot(exercise: exercise, sets: 3, reps: reps, restSeconds: rest)
            )
            plan.dayPlans[day] = cycles
            return true
        }
    }

    public func moveSlot(day: String, cycle: Int, from: Int, to: Int) {
        mutate { plan in
            guard var cycles = plan.dayPlans[day], cycles.indices.contains(cycle),
                  cycles[cycle].indices.contains(from), cycles[cycle].indices.contains(to),
                  from != to
            else { return false }
            let item = cycles[cycle].remove(at: from)
            cycles[cycle].insert(item, at: to)
            plan.dayPlans[day] = cycles
            return true
        }
    }

    /// Sätze, Wiederholungen und Pause einer Übung ändern.
    public func updateSlot(
        day: String, cycle: Int, at index: Int,
        sets: Int? = nil, reps: String? = nil, restSeconds: Int? = nil
    ) {
        mutate { plan in
            guard var cycles = plan.dayPlans[day], cycles.indices.contains(cycle),
                  cycles[cycle].indices.contains(index) else { return false }
            var slot = cycles[cycle][index]
            if let sets { slot.sets = max(1, min(6, sets)) }
            if let reps, !reps.trimmingCharacters(in: .whitespaces).isEmpty { slot.reps = reps }
            if let restSeconds { slot.restSeconds = restSeconds }
            cycles[cycle][index] = slot
            plan.dayPlans[day] = cycles
            return true
        }
    }

    /*
      Einen ganzen Trainingstag neu mischen.

      Die Kategorien kommen aus dem Tag selbst, nicht aus den Einstellungen
      des Generators: Der laufende Plan kann aus einem anderen Split stammen
      als das, was gerade im Generator eingestellt ist, und ein Beintag darf
      beim Mischen nicht zum Brusttag werden.

      Der jeweils andere Zyklus wird ausgeschlossen, damit Zyklus 1 und 2
      verschieden bleiben — das ist der Sinn der beiden Zyklen.
    */
    public func reshuffleDay(day: String, cycle: Int) {
        mutate { plan in
            guard var cycles = plan.dayPlans[day], cycles.indices.contains(cycle) else { return false }

            let current = cycles[cycle]
            guard !current.isEmpty else { return false }

            var categories: [MuscleCategory] = []
            for slot in current where !categories.contains(slot.exercise.category) {
                categories.append(slot.exercise.category)
            }
            guard !categories.isEmpty else { return false }

            let otherNames: Set<String> = cycles.indices
                .filter { $0 != cycle }
                .flatMap { cycles[$0] }
                .reduce(into: Set<String>()) { $0.insert($1.exercise.name) }

            let fresh = PlanGenerator.buildPlan(
                categories: categories,
                count: current.count,
                method: plan.method,
                restTime: plan.restTime,
                extraExclude: otherNames
            )
            guard !fresh.isEmpty else { return false }

            // Satzschema und Pause der bestehenden Plätze behalten — gemischt
            // werden die Übungen, nicht die Belastung.
            cycles[cycle] = fresh.enumerated().map { index, slot in
                guard current.indices.contains(index) else { return slot }
                let old = current[index]
                return ExerciseSlot(
                    exercise: slot.exercise,
                    sets: old.sets,
                    reps: old.reps,
                    restSeconds: old.restSeconds
                )
            }
            plan.dayPlans[day] = cycles
            return true
        }
    }

    public func end() {
        plan = nil
        persist()
    }

    /// Für die Kontolöschung — wie `end()`, aber ohne Statusmeldung.
    public func wipe() {
        plan = nil
        status = nil
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    private func clearStatusSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.status = nil
        }
    }
}
