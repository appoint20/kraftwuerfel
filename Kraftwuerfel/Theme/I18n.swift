import Foundation
import SwiftUI

/*
  Portierung von src/lib/i18n.jsx. Deutsch ist Standard, Englisch per Schalter
  im Header — und die Wahl überlebt den Neustart, wie im Web über localStorage.

  Übungsnamen bleiben Daten und werden über Exercise.nameEn aufgelöst;
  Kategorien, Equipment und Splits tragen ihre Übersetzung im jeweiligen enum.
  Hier stehen nur die Oberflächentexte.
*/
public final class I18n: ObservableObject {
    public static let shared = I18n()

    private static let storageKey = "kraftwuerfel:lang"

    @Published public var lang: String {
        didSet { UserDefaults.standard.set(lang, forKey: Self.storageKey) }
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        self.lang = (stored == "en" || stored == "de") ? stored! : "de"
    }

    public var locale: Locale { Locale(identifier: lang == "en" ? "en_GB" : "de_DE") }

    /// `t("gen.savedAs", ["name": planName])` — unbekannte Schlüssel geben sich
    /// selbst zurück, genau wie im Web.
    public func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        Strings.t(key, lang: lang, vars)
    }

    /// Die Tabellen liegen in `Strings` — dort ohne Modellabhängigkeit, damit
    /// die Widget-Erweiterung sie mitübersetzen kann. Diese beiden Verweise
    /// halten die bisherigen Aufrufstellen am Leben.
    static var de: [String: String] { Strings.de }
    static var en: [String: String] { Strings.en }

    public func weekday(_ day: String) -> String {
        guard lang == "en" else { return day }
        return Self.weekdayEn[day] ?? day
    }

    public func exerciseName(_ ex: Exercise) -> String { ex.localizedName(language: lang) }
    public func category(_ c: MuscleCategory) -> String { c.localized(lang) }
    public func equipment(_ e: EquipmentType) -> String { e.localized(lang) }
    public func split(_ s: SplitType) -> String { s.localized(lang) }
    public func method(_ m: TrainingMethod) -> String { lang == "en" ? m.titleEn : m.titleDe }

    private static let weekdayEn = [
        "Mo": "Mon", "Di": "Tue", "Mi": "Wed", "Do": "Thu",
        "Fr": "Fri", "Sa": "Sat", "So": "Sun",
    ]

    // MARK: - Texttabellen (1:1 aus i18n.jsx erzeugt)

}

/// Reihenfolge wie WEEKDAYS in lib/dateUtils.js — Montag zuerst.
public enum Weekdays {
    public static let all = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    /// Sortiert eine Auswahl in die Wochenreihenfolge (sortWeekdays im Web).
    public static func sorted(_ days: Set<String>) -> [String] {
        all.filter { days.contains($0) }
    }

    /// Heutiger Tag in Mo-zuerst-Notation.
    public static func today(_ now: Date = Date()) -> String {
        let idx = Calendar(identifier: .gregorian).component(.weekday, from: now) // So = 1
        return all[(idx + 5) % 7]
    }

    /*
      Reihenfolge für die Favoritenliste: heute zuerst, danach der Rest der
      Woche in normaler Reihenfolge (rotateWeekdaysFromToday im Web).
    */
    public static func rotatedFromToday(_ now: Date = Date()) -> [String] {
        guard let start = all.firstIndex(of: today(now)) else { return all }
        return Array(all[start...] + all[..<start])
    }
}
