import Foundation

/*
  MotivationalQuotes — Liefert abwechslungsreiche, motivierende KI-Abschlussbotschaften
  nach erfolgreichem Absolvieren einer Trainingseinheit.
*/
public struct MotivationalQuotes {

    public static let quotesDE: [String] = [
        "Glückwunsch, weiter so! 💪",
        "Starkes Training! Du bist wieder einen Schritt weiter. 🔥",
        "Geschafft! Deine Disziplin zahlt sich aus. 💪",
        "Training erfolgreich abgeschlossen – bleib dran! 🚀",
        "Brutale Einheit! Dein zukünftiges Ich dankt dir. ⚡️",
        "Keine Ausreden, voll durchgezogen! Respekt. 🏆",
        "Gains gesichert! Zeit für gute Regeneration und Proteine. 🥗",
        "Jeder Satz zählt – heute hast du alles gegeben! 💥",
        "Konstanz schlägt Talent: Wieder ein starker Tag im Kasten! 🎯",
        "Maschine! Morgen bist du stärker als gestern. 🦾",
        "Fokus gehalten und abgeliefert. Stark gemacht! 🦁",
        "Der innere Schweinehund hatte heute keine Chance! 🥊"
    ]

    public static let quotesEN: [String] = [
        "Congrats, keep pushing! 💪",
        "Strong workout! You're one step closer to your goals. 🔥",
        "Done! Your discipline is paying off. 💪",
        "Workout successfully completed – stay locked in! 🚀",
        "Brutal session! Your future self will thank you. ⚡️",
        "No excuses, pure dedication. Respect! 🏆",
        "Gains secured! Time for good recovery and fuel. 🥗",
        "Every rep counts – you crushed it today! 💥",
        "Consistency wins: Another solid day in the books! 🎯",
        "Beast mode! Tomorrow you'll be stronger than yesterday. 🦾",
        "Laser focus and great execution. Well done! 🦁",
        "Excuses lost, hard work won today! 🥊"
    ]

    public static func randomQuote(language: String = "de") -> String {
        if language == "en" {
            return quotesEN.randomElement() ?? "Great workout! Keep pushing. 💪"
        } else {
            return quotesDE.randomElement() ?? "Starkes Training! Weiter so. 💪"
        }
    }
}
