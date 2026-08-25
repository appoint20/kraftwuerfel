import Foundation

/*
  Ein gestarteter Trainingsplan — entspricht dem `active_plans`-Eintrag im Web.

  Sobald einer läuft, zeigt der Trainingsplan-Tab nicht mehr das Formular,
  sondern den Fortschritt: welche Woche, welcher Zyklus, wann der nächste
  Trainingstag ist. Genau diese Ansicht fehlte nativ komplett.
*/
public struct ActivePlan: Identifiable, Codable, Hashable {
    public var id = UUID()
    public let startDate: Date
    public let duration: Int          // Wochen
    public let days: [String]         // "Mo", "Mi", …
    public let split: String
    public let method: TrainingMethod
    public let count: Int
    public let restTime: Int
    public let dayPlans: [String: [[ExerciseSlot]]]

    public init(
        startDate: Date,
        duration: Int,
        days: [String],
        split: String,
        method: TrainingMethod,
        count: Int,
        restTime: Int,
        dayPlans: [String: [[ExerciseSlot]]]
    ) {
        self.startDate = startDate
        self.duration = duration
        self.days = days
        self.split = split
        self.method = method
        self.count = count
        self.restTime = restTime
        self.dayPlans = dayPlans
    }
}

/*
  Portierung von src/lib/progress.js und den Datumshelfern aus dateUtils.js.

  Alle Rechnungen laufen über auf Mitternacht normalisierte Tage — sonst
  entscheidet die Uhrzeit darüber, ob "heute" noch heute ist.
*/
public enum PlanProgress {

    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    static func normalize(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        calendar.dateComponents([.day], from: normalize(a), to: normalize(b)).day ?? 0
    }

    /// Alternierender Zyklus: Woche 1 -> Zyklus 1, Woche 2 -> Zyklus 2, Woche 3 -> Zyklus 1 …
    public static func weekInfo(for date: Date, start: Date) -> (weekIdx: Int, cycleIdx: Int) {
        let diff = daysBetween(start, date)
        let weekIdx = Int(floor(Double(diff) / 7.0)) + 1
        return (weekIdx, weekIdx % 2 == 1 ? 0 : 1)
    }

    public struct Snapshot {
        public let weekIdx: Int
        public let cycleIdx: Int
        public let finished: Bool
        public let todayLabel: String
        public let isTrainingDay: Bool
        public let daysLeftTotal: Int
    }

    public static func progress(for plan: ActivePlan, today: Date = Date()) -> Snapshot {
        let info = weekInfo(for: today, start: plan.startDate)
        let finished = info.weekIdx > plan.duration
        let todayLabel = Weekdays.today(today)
        let daysLeft = plan.duration * 7 - daysBetween(plan.startDate, today) - 1

        return Snapshot(
            weekIdx: info.weekIdx,
            cycleIdx: info.cycleIdx,
            finished: finished,
            todayLabel: todayLabel,
            isTrainingDay: !finished && plan.days.contains(todayLabel),
            daysLeftTotal: max(0, daysLeft)
        )
    }

    /// Wochentag als 1 = Sonntag … 7 = Samstag, wie `Date.getDay()` im Web.
    private static func jsWeekdayIndex(_ label: String) -> Int {
        ["So": 1, "Mo": 2, "Di": 3, "Mi": 4, "Do": 5, "Fr": 6, "Sa": 7][label] ?? 2
    }

    static func mostRecentWeekday(onOrBefore ref: Date, _ label: String) -> Date {
        let target = jsWeekdayIndex(label)
        let current = calendar.component(.weekday, from: normalize(ref))
        let diff = (current - target + 7) % 7
        return calendar.date(byAdding: .day, value: -diff, to: normalize(ref))!
    }

    static func nextWeekday(onOrAfter ref: Date, _ label: String) -> Date {
        let target = jsWeekdayIndex(label)
        let current = calendar.component(.weekday, from: normalize(ref))
        let diff = (target - current + 7) % 7
        return calendar.date(byAdding: .day, value: diff, to: normalize(ref))!
    }

    public struct LastTrained {
        public let upcoming: Bool
        public let inDays: Int
        public let weekIdx: Int
        public let cycleIdx: Int
        public let daysAgo: Int
        public let isToday: Bool
        public let dateLabel: String
    }

    public static func lastTrained(for plan: ActivePlan, day: String, today: Date = Date()) -> LastTrained {
        let recent = mostRecentWeekday(onOrBefore: today, day)

        // Liegt der letzte solche Wochentag noch vor dem Start, ist er erst
        // einer, der kommt — dann zählt der nächste.
        if recent < normalize(plan.startDate) {
            let upcoming = nextWeekday(onOrAfter: today, day)
            return LastTrained(
                upcoming: true, inDays: daysBetween(today, upcoming),
                weekIdx: 0, cycleIdx: 0, daysAgo: 0, isToday: false, dateLabel: ""
            )
        }

        let info = weekInfo(for: recent, start: plan.startDate)
        let daysAgo = daysBetween(recent, today)

        let df = DateFormatter()
        df.locale = I18n.shared.locale
        df.setLocalizedDateFormatFromTemplate("ddMM")

        return LastTrained(
            upcoming: false, inDays: 0,
            weekIdx: info.weekIdx, cycleIdx: info.cycleIdx,
            daysAgo: daysAgo, isToday: daysAgo == 0,
            dateLabel: df.string(from: recent)
        )
    }
}
