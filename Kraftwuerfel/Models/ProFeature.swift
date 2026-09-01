import Foundation

/*
  Was Pro kann — an einer Stelle aufgeschrieben.

  Die Grenze zwischen kostenlos und Pro stand vorher verstreut in den
  Ansichten: ein `isProUnlocked` im gespeicherten Plan, eins im KI-Coach,
  eine Zahl im Favoritenspeicher, und die Verkaufsseite zählte davon
  unabhängig ihre eigene Liste auf. Wer eine Funktion verschob, musste an
  vier Stellen daran denken — und die Verkaufsseite war die, an die niemand
  dachte. Sie versprach dann Dinge, die längst kostenlos waren, oder
  verschwieg welche, die es nicht mehr sind.

  Diese Aufzählung ist jetzt die Quelle: Die Sperren fragen sie, und die
  Verkaufsseite zeigt genau dieselbe Liste.
*/
public enum ProFeature: String, CaseIterable, Identifiable, Codable {
    /*
      Die Reihenfolge IST die Reihenfolge auf der Verkaufsseite — sie zeigt
      `allCases`. Werbefreiheit steht deshalb oben und nicht unten: Sie ist
      der Grund, aus dem die meisten ein Abo abschließen, und stand vorher an
      letzter Stelle unter fünf Funktionen, die man erst benutzt haben muss,
      um sie zu vermissen.
    */
    /// Keine Werbung — der Hauptgrund für das Abo.
    case noAds
    /// KI-Coach und KI-Analyse. Kostenlos erreichbar, aber erst nach
    /// belohnten Videos — siehe AdManager.requiredRewardedVideos.
    case aiCoach
    /// Trainingspläne und Meal Guides dauerhaft speichern.
    case savedPlans
    /// Das Trainingsarchiv: abgeschlossene Einheiten mit Gewichten und
    /// Wiederholungen im Fortschritt-Tab.
    case workoutHistory
    /// Die Planbewertung (PlanQualityScore) mit ihren Einzelwertungen.
    case planScore
    /// Mehr als ein Lieblingstag.
    case unlimitedFavorites

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .aiCoach:            return "sparkles"
        case .savedPlans:         return "bookmark.fill"
        case .workoutHistory:     return "chart.line.uptrend.xyaxis"
        case .planScore:          return "checkmark.seal.fill"
        case .unlimitedFavorites: return "heart.fill"
        case .noAds:              return "hand.raised.fill"
        }
    }

    public var titleDe: String {
        switch self {
        case .aiCoach:            return "KI-Coach ohne Wartezeit"
        case .savedPlans:         return "Pläne speichern"
        case .workoutHistory:     return "Trainingsarchiv"
        case .planScore:          return "Planbewertung"
        case .unlimitedFavorites: return "Unbegrenzte Favoriten"
        case .noAds:              return "Komplett werbefrei"
        }
    }

    public var titleEn: String {
        switch self {
        case .aiCoach:            return "AI coach without the wait"
        case .savedPlans:         return "Save plans"
        case .workoutHistory:     return "Training archive"
        case .planScore:          return "Plan score"
        case .unlimitedFavorites: return "Unlimited favourites"
        case .noAds:              return "Completely ad-free"
        }
    }

    public var subtitleDe: String {
        switch self {
        case .aiCoach:
            return "Pläne und Ernährung sofort erstellen, ohne vorher Videos anzusehen"
        case .savedPlans:
            return "Trainingspläne und Meal Guides dauerhaft aufbewahren"
        case .workoutHistory:
            return "Jede Einheit mit Gewichten, Wiederholungen und Verlauf"
        case .planScore:
            return "Volumen, Balance und Regeneration deines Plans im Blick"
        case .unlimitedFavorites:
            return "Kostenlos ist ein Lieblingstag möglich, mit Pro beliebig viele"
        case .noAds:
            return "Keine Banner, keine Videos, keine Unterbrechung im Training — in der ganzen App"
        }
    }

    public var subtitleEn: String {
        switch self {
        case .aiCoach:
            return "Create plans and nutrition instantly, without watching videos first"
        case .savedPlans:
            return "Keep training plans and meal guides for good"
        case .workoutHistory:
            return "Every session with weights, reps and progression"
        case .planScore:
            return "See the volume, balance and recovery of your plan"
        case .unlimitedFavorites:
            return "Free gives you one favourite day, Pro as many as you like"
        case .noAds:
            return "No banners, no videos, no interruption mid-workout — anywhere in the app"
        }
    }

    public func localized(_ lang: String) -> String { lang == "en" ? titleEn : titleDe }
    public func localizedSubtitle(_ lang: String) -> String { lang == "en" ? subtitleEn : subtitleDe }
}

public extension Notification.Name {
    /*
      „Zeig die Pro-Seite" — von überall her, ohne Rückruf durch fünf Ebenen.

      Die Bewertungskarte steckt tief in der Plananzeige, die selbst in drei
      verschiedenen Bildschirmen sitzt. Einen `showPro`-Rückruf durch alle
      durchzureichen hieße, vier Ansichten anzufassen, die mit Pro nichts zu
      tun haben. MainTabView hört stattdessen zu und öffnet das Blatt.
    */
    static let kraftShowPro = Notification.Name("kraftwuerfel.showPro")
}
