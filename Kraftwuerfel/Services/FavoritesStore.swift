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

  Dieselbe Überlegung gilt für die Gratis-Grenze von einem Favoriten: Sie
  steht in `canFavorite`/`toggle`, damit jede Ansicht dieselbe Antwort bekommt
  und keine sie versehentlich umgeht.
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

    // MARK: - Grenze für Gratis-Nutzer

    /// Ohne Pro bleibt genau ein Favorit — der eine Plan, den man im Gym
    /// aufschlägt. Alles darüber ist Pro.
    public static let freeLimit = 1

    /*
      Ob dieser Tag jetzt gerade favorisiert werden dürfte.

      Ein bereits favorisierter Tag zählt ausdrücklich als erlaubt: Sonst
      könnte ein Gratis-Nutzer seinen einen Favoriten nicht mehr entfernen und
      säße für immer auf demselben Tag fest.
    */
    public func canFavorite(day: String, isPro: Bool) -> Bool {
        isPro || isFavorited(day: day) || favorites.count < Self.freeLimit
    }

    /// Was ein Antippen bewirkt hat — `.blockedByLimit` ist der Moment, in dem
    /// die View zum Pro-Angebot führen soll.
    public enum ToggleOutcome {
        case added, removed, blockedByLimit
    }

    /*
      `isPro` kommt von außen herein, statt dass der Store StoreKitManager
      fragt: Der ist an den MainActor gebunden, dieser Store nicht — und die
      Grenze ist ohnehin eine Frage der Ansicht, die den Kauf anbieten kann.
    */
    @discardableResult
    public func toggle(
        day: String,
        cycles: [[ExerciseSlot]],
        split: String,
        method: TrainingMethod,
        isPro: Bool
    ) -> ToggleOutcome {
        if let existing = favorites.first(where: { $0.day == day }) {
            remove(id: existing.id)
            status = I18n.shared.t("fav.removed", ["day": I18n.shared.weekday(day)])
            clearStatusSoon()
            return .removed
        }

        guard canFavorite(day: day, isPro: isPro) else {
            // Kein Status-Text: Die View zeigt stattdessen das Pro-Angebot,
            // und zwei Meldungen übereinander wären eine zu viel.
            return .blockedByLimit
        }

        let created = FavoriteDayPlan(day: day, split: split, method: method, cycles: cycles)
        favorites.removeAll { $0.day == day }
        favorites.insert(created, at: 0)
        persist()
        status = I18n.shared.t("fav.added", ["day": I18n.shared.weekday(day)])
        clearStatusSoon()
        return .added
    }

    public func remove(id: UUID) {
        favorites.removeAll { $0.id == id }
        persist()
    }

    /// Für die Kontolöschung — der Schlüssel verschwindet ganz, nicht bloß
    /// eine leere Liste an seiner Stelle.
    public func wipe() {
        favorites = []
        status = nil
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
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
