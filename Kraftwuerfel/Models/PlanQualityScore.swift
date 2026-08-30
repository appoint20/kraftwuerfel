import Foundation

/*
  Wie gut ist dieser Plan?

  Bisher konnte das niemand sagen. Der KI-Coach lieferte einen Plan, der
  Generator würfelte einen, und beide sahen gleich überzeugend aus — ob der
  Rücken vier oder achtzehn Sätze pro Woche bekam, stand nirgends.

  Diese Bewertung rechnet, sie fragt kein Modell. Das ist Absicht und nicht
  Sparsamkeit: Satzzahlen, Regenerationsabstände und Zeitbudgets sind
  arithmetische Größen. Ein Sprachmodell würde sie schätzen und bei derselben
  Eingabe zweimal etwas anderes sagen — hier kommt bei gleichem Plan immer
  dasselbe heraus, sofort, ohne Netz und ohne Kosten.

  Die Richtwerte stammen aus der gängigen Trainingsliteratur zum
  Wochenvolumen (etwa 10 bis 20 harte Sätze je Muskelgruppe für Hypertrophie).
  Sie sind Orientierung, keine Wahrheit — deshalb sind die Bänder breit und
  die Abzüge weich.
*/
public struct PlanQualityScore: Equatable {

    // MARK: - Einzelbewertung

    public struct Dimension: Identifiable, Equatable {
        public let id: String
        public let titleDe: String
        public let titleEn: String
        public let score: Int          // 0…100
        public let weight: Double
        public let detailDe: String
        public let detailEn: String
        public let icon: String

        public func title(_ lang: String) -> String { lang == "en" ? titleEn : titleDe }
        public func detail(_ lang: String) -> String { lang == "en" ? detailEn : detailDe }

        public var band: Band { Band(score: score) }
    }

    public enum Band {
        case strong, solid, weak

        public init(score: Int) {
            switch score {
            case 80...: self = .strong
            case 55..<80: self = .solid
            default: self = .weak
            }
        }

        public func label(_ lang: String) -> String {
            switch self {
            case .strong: return lang == "en" ? "Strong" : "Stark"
            case .solid:  return lang == "en" ? "Solid" : "Solide"
            case .weak:   return lang == "en" ? "Needs work" : "Schwach"
            }
        }
    }

    /// Ein konkreter, umsetzbarer Hinweis — kein Allgemeinplatz.
    public struct Finding: Identifiable, Equatable {
        public let id = UUID()
        public let textDe: String
        public let textEn: String
        public let isPositive: Bool

        public func text(_ lang: String) -> String { lang == "en" ? textEn : textDe }

        public static func == (a: Finding, b: Finding) -> Bool {
            a.textDe == b.textDe && a.isPositive == b.isPositive
        }
    }

    public let overall: Int
    public let dimensions: [Dimension]
    public let findings: [Finding]
    /// Geschätzte Dauer je Einheit in Minuten, gemittelt über die Trainingstage.
    public let estimatedMinutes: Int
    /// Harte Sätze pro Woche je Muskelgruppe.
    public let weeklySets: [MuscleCategory: Int]

    public var band: Band { Band(score: overall) }

    public func gradeLabel(_ lang: String) -> String {
        switch overall {
        case 90...: return lang == "en" ? "Excellent" : "Ausgezeichnet"
        case 80..<90: return lang == "en" ? "Strong" : "Stark"
        case 65..<80: return lang == "en" ? "Solid" : "Solide"
        case 50..<65: return lang == "en" ? "Workable" : "Brauchbar"
        default: return lang == "en" ? "Needs work" : "Überarbeiten"
        }
    }

    // MARK: - Richtwerte

    /// Wochensätze je Muskelgruppe: darunter zu wenig, darüber viel.
    public static let volumeFloor = 6
    public static let volumeTarget = 10
    public static let volumeCeiling = 22

    /// Arbeitszeit je Satz in Sekunden — grob, aber für ein Zeitbudget genug.
    private static let secondsPerSet = 40.0
    /// Umbauzeit zwischen zwei Übungen.
    private static let transitionSeconds = 60.0

    private static let pushCategories: Set<MuscleCategory> = [.chest, .shoulders, .triceps]
    private static let pullCategories: Set<MuscleCategory> = [.back, .biceps, .neck]
    private static let legCategories: Set<MuscleCategory> = [.legs, .glutes, .calves]

    // MARK: - Berechnung

    /*
      `targetMinutes` ist die Vorgabe des Nutzers. Ohne sie entfällt die
      Zeitbewertung, statt gegen einen erfundenen Wert zu messen.
    */
    public static func evaluate(
        plan: TrainingPlan,
        goal: TrainingGoal = .muscle,
        targetMinutes: Int? = nil
    ) -> PlanQualityScore {
        let days = plan.days
        guard !days.isEmpty else { return empty() }

        let cycle = 1
        let sets = weeklySetsPerCategory(days: days, cycle: cycle)
        let minutes = averageSessionMinutes(days: days, cycle: cycle)

        var findings: [Finding] = []

        let volume = scoreVolume(sets: sets, findings: &findings)
        let balance = scoreBalance(sets: sets, findings: &findings)
        let recovery = scoreRecovery(days: days, cycle: cycle, findings: &findings)
        let variety = scoreVariety(plan: plan, findings: &findings)
        let goalFit = scoreGoalFit(days: days, cycle: cycle, goal: goal, findings: &findings)
        let timeFit = scoreTimeFit(minutes: minutes, target: targetMinutes, findings: &findings)

        var dimensions = [volume, balance, recovery, variety, goalFit]
        if let timeFit { dimensions.append(timeFit) }

        let totalWeight = dimensions.reduce(0.0) { $0 + $1.weight }
        let weighted = dimensions.reduce(0.0) { $0 + Double($1.score) * $1.weight }
        let overall = totalWeight > 0 ? Int((weighted / totalWeight).rounded()) : 0

        return PlanQualityScore(
            overall: max(0, min(100, overall)),
            dimensions: dimensions,
            findings: Array(findings.prefix(6)),
            estimatedMinutes: minutes,
            weeklySets: sets
        )
    }

    private static func empty() -> PlanQualityScore {
        PlanQualityScore(overall: 0, dimensions: [], findings: [], estimatedMinutes: 0, weeklySets: [:])
    }

    // MARK: - Bausteine

    /*
      Sätze je Muskelgruppe und Woche.

      Eine Übung zählt auf alle Kategorien, die sie trifft — Hip Thrust also
      auf Gesäß, Beine und Rücken. Ganzkörperübungen werden mit halbem Gewicht
      verbucht: Burpees sind kein voller Satz für den Rücken.
    */
    public static func weeklySetsPerCategory(days: [DayPlan], cycle: Int) -> [MuscleCategory: Int] {
        var raw: [MuscleCategory: Double] = [:]

        for day in days {
            for slot in day.slots(forCycle: cycle) {
                let categories = slot.exercise.categories
                let isFullBody = categories.contains(.fullBody)

                for category in categories where category != .fullBody {
                    raw[category, default: 0] += Double(slot.sets)
                }

                if isFullBody {
                    for category in [MuscleCategory.legs, .back, .chest, .core] {
                        raw[category, default: 0] += Double(slot.sets) * 0.5
                    }
                }
            }
        }

        return raw.mapValues { Int($0.rounded()) }
    }

    /// Geschätzte Dauer je Einheit, gemittelt über alle Trainingstage.
    public static func averageSessionMinutes(days: [DayPlan], cycle: Int) -> Int {
        let durations: [Double] = days.map { day in
            let slots = day.slots(forCycle: cycle)
            guard !slots.isEmpty else { return 0 }

            let work = slots.reduce(0.0) { $0 + Double($1.sets) * secondsPerSet }
            // Zwischen den Sätzen wird pausiert, nach dem letzten nicht.
            let rest = slots.reduce(0.0) { $0 + Double(max(0, $1.sets - 1) * $1.restSeconds) }
            let transitions = Double(max(0, slots.count - 1)) * transitionSeconds
            let warmup = day.warmup.isEmpty ? 0.0 : 300.0

            return (work + rest + transitions + warmup) / 60.0
        }

        let active = durations.filter { $0 > 0 }
        guard !active.isEmpty else { return 0 }
        return Int((active.reduce(0, +) / Double(active.count)).rounded())
    }

    // MARK: - Einzelne Dimensionen

    private static func scoreVolume(
        sets: [MuscleCategory: Int],
        findings: inout [Finding]
    ) -> Dimension {
        /*
          Bewertet werden nur Gruppen, die im Plan überhaupt vorkommen. Wer
          bewusst einen reinen Oberkörpertag plant, soll keinen Abzug für
          fehlende Waden bekommen.
        */
        let trained = sets.filter { $0.value > 0 }
        guard !trained.isEmpty else {
            return Dimension(
                id: "volume", titleDe: "Volumen", titleEn: "Volume",
                score: 0, weight: 1.3,
                detailDe: "Keine Sätze im Plan.", detailEn: "No sets in this plan.",
                icon: "chart.bar.fill"
            )
        }

        /*
          Je Muskelgruppe eine eigene Note, danach der Mittelwert.

          Vorher war es eine Summe von Abzügen auf 100. Das war zu milde: Ein
          Plan mit einem einzigen Satz kam damit auf 80 von 100 und stand als
          „stark“ da. Anteilig gerechnet ergibt derselbe Fall 17 — was er auch
          verdient. Über der Obergrenze bleibt der Abzug weicher: zu viel
          Volumen ist ein Regenerationsproblem, kein wirkungsloser Plan.
        */
        var perCategory: [Double] = []
        var tooLow: [MuscleCategory] = []
        var tooHigh: [MuscleCategory] = []

        for (category, count) in trained {
            if count < volumeFloor {
                perCategory.append(100.0 * Double(count) / Double(volumeFloor))
                tooLow.append(category)
            } else if count > volumeCeiling {
                let excess = Double(count - volumeCeiling)
                perCategory.append(max(40.0, 100.0 - excess * 5.0))
                tooHigh.append(category)
            } else {
                perCategory.append(100.0)
            }
        }

        let average = perCategory.reduce(0, +) / Double(perCategory.count)
        let score = max(0, min(100, Int(average.rounded())))

        if let worst = tooLow.sorted(by: { (sets[$0] ?? 0) < (sets[$1] ?? 0) }).first {
            let count = sets[worst] ?? 0
            findings.append(Finding(
                textDe: "\(worst.localizedDe) bekommt nur \(count) Sätze pro Woche. Für Aufbau sind \(volumeTarget)–\(volumeCeiling) üblich.",
                textEn: "\(worst.localizedEn) only gets \(count) sets per week. \(volumeTarget)–\(volumeCeiling) is the usual range for growth.",
                isPositive: false
            ))
        }
        if let worst = tooHigh.sorted(by: { (sets[$0] ?? 0) > (sets[$1] ?? 0) }).first {
            let count = sets[worst] ?? 0
            findings.append(Finding(
                textDe: "\(worst.localizedDe) liegt bei \(count) Sätzen pro Woche — das ist viel und kann die Regeneration überholen.",
                textEn: "\(worst.localizedEn) sits at \(count) sets per week — high enough to outrun recovery.",
                isPositive: false
            ))
        }
        if tooLow.isEmpty && tooHigh.isEmpty {
            findings.append(Finding(
                textDe: "Alle trainierten Muskelgruppen liegen im sinnvollen Wochenvolumen.",
                textEn: "Every trained muscle group sits in a sensible weekly volume.",
                isPositive: true
            ))
        }

        let detailDe = tooLow.isEmpty && tooHigh.isEmpty
            ? "\(trained.count) Muskelgruppen, alle im Zielbereich \(volumeFloor)–\(volumeCeiling) Sätze."
            : "\(tooLow.count) Gruppe(n) unter \(volumeFloor), \(tooHigh.count) über \(volumeCeiling) Sätzen."
        let detailEn = tooLow.isEmpty && tooHigh.isEmpty
            ? "\(trained.count) muscle groups, all within \(volumeFloor)–\(volumeCeiling) sets."
            : "\(tooLow.count) group(s) below \(volumeFloor), \(tooHigh.count) above \(volumeCeiling) sets."

        return Dimension(
            id: "volume", titleDe: "Volumen", titleEn: "Volume",
            score: score, weight: 1.3,
            detailDe: detailDe, detailEn: detailEn,
            icon: "chart.bar.fill"
        )
    }

    private static func scoreBalance(
        sets: [MuscleCategory: Int],
        findings: inout [Finding]
    ) -> Dimension {
        let push = sets.filter { pushCategories.contains($0.key) }.values.reduce(0, +)
        let pull = sets.filter { pullCategories.contains($0.key) }.values.reduce(0, +)
        let legs = sets.filter { legCategories.contains($0.key) }.values.reduce(0, +)
        let upper = push + pull

        var score = 100
        var notes: [String] = []

        /*
          Drücken gegen Ziehen. Ein Übergewicht des Drückens ist der häufigste
          Fehler in selbstgebauten Plänen und geht auf Dauer auf die Schultern.
        */
        if push > 0 && pull > 0 {
            let ratio = Double(push) / Double(pull)
            if ratio > 1.6 {
                score -= min(35, Int((ratio - 1.6) * 40))
                notes.append("push")
                findings.append(Finding(
                    textDe: "Drücken überwiegt deutlich (\(push) zu \(pull) Sätzen). Mehr Zugarbeit schützt die Schultern.",
                    textEn: "Pushing dominates (\(push) vs \(pull) sets). More pulling protects the shoulders.",
                    isPositive: false
                ))
            } else if ratio < 0.55 {
                score -= min(25, Int((0.55 - ratio) * 40))
                notes.append("pull")
            }
        } else if push > 0 || pull > 0 {
            score -= 20
        }

        // Oberkörper gegen Beine — nur bewerten, wenn beides vorkommt.
        if upper > 0 && legs > 0 {
            let ratio = Double(upper) / Double(legs)
            if ratio > 3.0 {
                score -= min(30, Int((ratio - 3.0) * 12))
                findings.append(Finding(
                    textDe: "Die Beine kommen mit \(legs) Sätzen gegenüber \(upper) für den Oberkörper zu kurz.",
                    textEn: "Legs get \(legs) sets against \(upper) for the upper body — thin by comparison.",
                    isPositive: false
                ))
            }
        }

        score = max(0, min(100, score))

        if score >= 85 && notes.isEmpty {
            findings.append(Finding(
                textDe: "Drücken, Ziehen und Beine stehen in einem gesunden Verhältnis.",
                textEn: "Push, pull and legs are in a healthy ratio.",
                isPositive: true
            ))
        }

        return Dimension(
            id: "balance", titleDe: "Balance", titleEn: "Balance",
            score: score, weight: 1.2,
            detailDe: "Drücken \(push) · Ziehen \(pull) · Beine \(legs) Sätze pro Woche.",
            detailEn: "Push \(push) · pull \(pull) · legs \(legs) sets per week.",
            icon: "scalemass.fill"
        )
    }

    /*
      Regeneration: dieselbe Muskelgruppe an zwei aufeinanderfolgenden Tagen
      schwer zu belasten, kostet Punkte. Gezählt wird über echte
      Wochentagsabstände, nicht über die Reihenfolge im Array — Mo und Mi sind
      benachbart in der Liste, aber nicht im Kalender.
    */
    private static func scoreRecovery(
        days: [DayPlan],
        cycle: Int,
        findings: inout [Finding]
    ) -> Dimension {
        guard days.count > 1 else {
            return Dimension(
                id: "recovery", titleDe: "Regeneration", titleEn: "Recovery",
                score: 100, weight: 1.1,
                detailDe: "Ein Trainingstag pro Woche — Regeneration ist unkritisch.",
                detailEn: "One training day per week — recovery is not a concern.",
                icon: "moon.zzz.fill"
            )
        }

        let order = Weekdays.all
        let sorted = days.compactMap { day -> (index: Int, day: DayPlan)? in
            guard let index = order.firstIndex(of: day.weekday) else { return nil }
            return (index, day)
        }.sorted { $0.index < $1.index }

        guard sorted.count > 1 else {
            return Dimension(
                id: "recovery", titleDe: "Regeneration", titleEn: "Recovery",
                score: 90, weight: 1.1,
                detailDe: "Zu wenige zuordenbare Tage für eine Aussage.",
                detailEn: "Too few identifiable days to judge.",
                icon: "moon.zzz.fill"
            )
        }

        var collisions = 0
        var worstPair: (String, MuscleCategory)?

        for i in 0..<(sorted.count - 1) {
            let a = sorted[i]
            let b = sorted[i + 1]
            guard b.index - a.index == 1 else { continue }   // nur echte Folgetage

            let aHeavy = heavyCategories(a.day, cycle: cycle)
            let bHeavy = heavyCategories(b.day, cycle: cycle)
            let shared = aHeavy.intersection(bHeavy)

            if let first = shared.first {
                collisions += shared.count
                if worstPair == nil { worstPair = (b.day.weekday, first) }
            }
        }

        // Auch der Sprung von Sonntag auf Montag ist ein Folgetag.
        if let first = sorted.first, let last = sorted.last,
           first.index == 0, last.index == order.count - 1 {
            let shared = heavyCategories(last.day, cycle: cycle)
                .intersection(heavyCategories(first.day, cycle: cycle))
            collisions += shared.count
        }

        let score = max(0, 100 - collisions * 14)

        if let (weekday, category) = worstPair {
            findings.append(Finding(
                textDe: "\(category.localizedDe) wird an zwei Tagen hintereinander schwer belastet (bis \(weekday)). Ein Ruhetag dazwischen bringt mehr.",
                textEn: "\(category.localizedEn) is loaded hard on back-to-back days (through \(weekday)). A rest day between would do more.",
                isPositive: false
            ))
        } else if score >= 90 {
            findings.append(Finding(
                textDe: "Keine Muskelgruppe wird an aufeinanderfolgenden Tagen schwer belastet.",
                textEn: "No muscle group is loaded hard on consecutive days.",
                isPositive: true
            ))
        }

        return Dimension(
            id: "recovery", titleDe: "Regeneration", titleEn: "Recovery",
            score: score, weight: 1.1,
            detailDe: collisions == 0
                ? "Saubere Verteilung über die Woche."
                : "\(collisions) Überschneidung(en) an Folgetagen.",
            detailEn: collisions == 0
                ? "Cleanly spread across the week."
                : "\(collisions) overlap(s) on consecutive days.",
            icon: "moon.zzz.fill"
        )
    }

    /// Muskelgruppen, die an diesem Tag mit mindestens 3 Sätzen vorkommen.
    private static func heavyCategories(_ day: DayPlan, cycle: Int) -> Set<MuscleCategory> {
        var counts: [MuscleCategory: Int] = [:]
        for slot in day.slots(forCycle: cycle) {
            for category in slot.exercise.categories where category != .fullBody {
                counts[category, default: 0] += slot.sets
            }
        }
        return Set(counts.filter { $0.value >= 3 }.keys)
    }

    private static func scoreVariety(
        plan: TrainingPlan,
        findings: inout [Finding]
    ) -> Dimension {
        let allSlots = plan.days.flatMap { $0.slots(forCycle: 1) }
        guard !allSlots.isEmpty else {
            return Dimension(
                id: "variety", titleDe: "Abwechslung", titleEn: "Variety",
                score: 0, weight: 0.8,
                detailDe: "Keine Übungen.", detailEn: "No exercises.",
                icon: "shuffle"
            )
        }

        let distinct = Set(allSlots.map(\.exercise.name)).count
        let ratio = Double(distinct) / Double(allSlots.count)
        var score = Int(ratio * 100)

        // Ein echter zweiter Zyklus ist Abwechslung und zählt positiv.
        if plan.hasTwoCycles { score = min(100, score + 12) }

        score = max(0, min(100, score))

        if ratio < 0.7 {
            findings.append(Finding(
                textDe: "Nur \(distinct) verschiedene Übungen auf \(allSlots.count) Plätze — es wiederholt sich viel.",
                textEn: "Only \(distinct) distinct exercises across \(allSlots.count) slots — a lot of repetition.",
                isPositive: false
            ))
        }

        return Dimension(
            id: "variety", titleDe: "Abwechslung", titleEn: "Variety",
            score: score, weight: 0.8,
            detailDe: plan.hasTwoCycles
                ? "\(distinct) verschiedene Übungen, zwei Zyklen im Wechsel."
                : "\(distinct) verschiedene Übungen auf \(allSlots.count) Plätzen.",
            detailEn: plan.hasTwoCycles
                ? "\(distinct) distinct exercises across two alternating cycles."
                : "\(distinct) distinct exercises across \(allSlots.count) slots.",
            icon: "shuffle"
        )
    }

    /*
      Passt das Satz- und Wiederholungsschema zum Ziel? Für Maximalkraft
      niedrige Wiederholungen, für Aufbau der mittlere Bereich, fürs Abnehmen
      höhere Wiederholungen und kurze Pausen.
    */
    private static func scoreGoalFit(
        days: [DayPlan],
        cycle: Int,
        goal: TrainingGoal,
        findings: inout [Finding]
    ) -> Dimension {
        let slots = days.flatMap { $0.slots(forCycle: cycle) }
        guard !slots.isEmpty else {
            return Dimension(
                id: "goal", titleDe: "Zielausrichtung", titleEn: "Goal fit",
                score: 0, weight: 1.0,
                detailDe: "Keine Übungen.", detailEn: "No exercises.",
                icon: "target"
            )
        }

        let reps = slots.compactMap { midpointReps($0.reps) }
        guard !reps.isEmpty else {
            return Dimension(
                id: "goal", titleDe: "Zielausrichtung", titleEn: "Goal fit",
                score: 70, weight: 1.0,
                detailDe: "Wiederholungen nicht auswertbar.",
                detailEn: "Rep scheme could not be read.",
                icon: "target"
            )
        }

        let average = reps.reduce(0, +) / Double(reps.count)
        let averageRest = slots.reduce(0) { $0 + $1.restSeconds } / slots.count

        let (low, high): (Double, Double)
        switch goal {
        case .strength:   (low, high) = (3, 8)
        case .muscle:     (low, high) = (6, 15)
        case .definition: (low, high) = (8, 18)
        case .weightLoss: (low, high) = (10, 22)
        case .fitness:    (low, high) = (8, 20)
        }

        var score = 100
        if average < low {
            score -= min(45, Int((low - average) * 9))
        } else if average > high {
            score -= min(45, Int((average - high) * 6))
        }

        // Beim Abnehmen sind lange Pausen ein Ziel-Widerspruch.
        if goal == .weightLoss && averageRest > 100 {
            score -= 12
            findings.append(Finding(
                textDe: "Für das Ziel Abnehmen sind \(averageRest) s Satzpause lang — kürzere Pausen halten den Puls oben.",
                textEn: "\(averageRest)s rest is long for a fat-loss goal — shorter rests keep the heart rate up.",
                isPositive: false
            ))
        }
        if goal == .strength && averageRest < 90 {
            score -= 10
        }

        score = max(0, min(100, score))

        if score < 70 {
            findings.append(Finding(
                textDe: "Im Schnitt \(Int(average)) Wiederholungen — für \(goal.titleDe) sind \(Int(low))–\(Int(high)) passender.",
                textEn: "Averaging \(Int(average)) reps — \(Int(low))–\(Int(high)) fits \(goal.titleEn) better.",
                isPositive: false
            ))
        }

        return Dimension(
            id: "goal", titleDe: "Zielausrichtung", titleEn: "Goal fit",
            score: score, weight: 1.0,
            detailDe: "Ø \(Int(average)) Wdh · \(averageRest) s Pause · Ziel \(goal.titleDe).",
            detailEn: "Avg \(Int(average)) reps · \(averageRest)s rest · goal \(goal.titleEn).",
            icon: "target"
        )
    }

    private static func scoreTimeFit(
        minutes: Int,
        target: Int?,
        findings: inout [Finding]
    ) -> Dimension? {
        guard let target, target > 0, minutes > 0 else { return nil }

        let deviation = Double(minutes - target) / Double(target)
        var score = 100

        if deviation > 0.15 {
            score -= min(60, Int((deviation - 0.15) * 220))
            findings.append(Finding(
                textDe: "Die Einheiten dauern geschätzt \(minutes) statt \(target) Minuten. Weniger Sätze oder kürzere Pausen bringen sie in den Rahmen.",
                textEn: "Sessions run an estimated \(minutes) minutes instead of \(target). Fewer sets or shorter rests bring them back.",
                isPositive: false
            ))
        } else if deviation < -0.25 {
            score -= min(35, Int((abs(deviation) - 0.25) * 120))
            findings.append(Finding(
                textDe: "Die Einheiten sind mit \(minutes) Minuten deutlich kürzer als die geplanten \(target). Da wäre Luft für mehr Volumen.",
                textEn: "At \(minutes) minutes the sessions are well under the planned \(target). There is room for more volume.",
                isPositive: false
            ))
        } else {
            findings.append(Finding(
                textDe: "Die Einheiten passen mit rund \(minutes) Minuten in deinen Zeitrahmen.",
                textEn: "Sessions land around \(minutes) minutes, inside your time budget.",
                isPositive: true
            ))
        }

        return Dimension(
            id: "time", titleDe: "Zeitrahmen", titleEn: "Time fit",
            score: max(0, min(100, score)), weight: 1.0,
            detailDe: "Geschätzt \(minutes) Min pro Einheit, geplant \(target) Min.",
            detailEn: "Estimated \(minutes) min per session, planned \(target) min.",
            icon: "clock.fill"
        )
    }

    /*
      Die Mitte einer Wiederholungsangabe. Sie kommt in allen Formen vor:
      "8-12", "10", "12 Wdh", "30 Sek". Zeitangaben werden übersprungen —
      Sekunden sind keine Wiederholungen und würden den Schnitt sprengen.
    */
    public static func midpointReps(_ raw: String) -> Double? {
        let lower = raw.lowercased()
        if lower.contains("sek") || lower.contains("sec") || lower.contains("min") || lower.contains("s)") {
            return nil
        }

        let numbers = lower
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Double($0) }
            .filter { $0 > 0 && $0 <= 100 }

        guard !numbers.isEmpty else { return nil }
        if numbers.count == 1 { return numbers[0] }
        return (numbers[0] + numbers[1]) / 2.0
    }
}
