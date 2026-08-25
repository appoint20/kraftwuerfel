import Foundation
import SwiftUI

/// Ein favorisierter Tagesplan — entspricht einem Eintrag aus useFavorites.js.
public struct FavoriteDayPlan: Identifiable, Codable, Hashable {
    public var id = UUID()
    public let day: String              // "Mo" … "So"
    public let split: String
    public let method: TrainingMethod
    public let cycles: [[ExerciseSlot]]
    public let favoritedAt: Date

    public init(
        day: String,
        split: String,
        method: TrainingMethod,
        cycles: [[ExerciseSlot]],
        favoritedAt: Date = Date()
    ) {
        self.day = day
        self.split = split
        self.method = method
        self.cycles = cycles
        self.favoritedAt = favoritedAt
    }
}

/*
  Portierung von hooks/useFavorites.js für den lokalen Modus.

  Pro Wochentag gibt es höchstens einen Favoriten — `toggle` ersetzt einen
  vorhandenen Eintrag, statt einen zweiten anzulegen. Genau daran krankte im
  Web einmal die Herz-Schaltfläche, deshalb steht die Regel hier im Store und
  nicht in der View.
*/
public final class FavoritesStore: ObservableObject {
    public static let shared = FavoritesStore()

    private static let storageKey = "kraftwuerfel:favorites"

    @Published public private(set) var favorites: [FavoriteDayPlan] = []
    @Published public var status: String?

    private init() { load() }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([FavoriteDayPlan].self, from: data)
        else { return }
        favorites = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    public func isFavorited(day: String) -> Bool {
        favorites.contains { $0.day == day }
    }

    public func toggle(day: String, cycles: [[ExerciseSlot]], split: String, method: TrainingMethod) {
        if let existing = favorites.first(where: { $0.day == day }) {
            remove(id: existing.id)
            status = I18n.shared.t("fav.removed", ["day": I18n.shared.weekday(day)])
        } else {
            let created = FavoriteDayPlan(day: day, split: split, method: method, cycles: cycles)
            favorites.removeAll { $0.day == day }
            favorites.insert(created, at: 0)
            persist()
            status = I18n.shared.t("fav.added", ["day": I18n.shared.weekday(day)])
        }
        clearStatusSoon()
    }

    public func remove(id: UUID) {
        favorites.removeAll { $0.id == id }
        persist()
    }

    /// Heute zuerst, danach die Woche der Reihe nach; bei Gleichstand das
    /// zuletzt Favorisierte oben.
    public var sortedForDisplay: [FavoriteDayPlan] {
        let order = Weekdays.rotatedFromToday()
        return favorites.sorted { a, b in
            let ai = order.firstIndex(of: a.day) ?? order.count
            let bi = order.firstIndex(of: b.day) ?? order.count
            if ai != bi { return ai < bi }
            return a.favoritedAt > b.favoritedAt
        }
    }

    private func clearStatusSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.status = nil
        }
    }
}
