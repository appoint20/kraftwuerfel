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

    public func end() {
        plan = nil
        persist()
    }

    private func clearStatusSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.status = nil
        }
    }
}
