import XCTest
@testable import Kraftwuerfel

/*
  Wochen- und Zyklusrechnung (src/lib/progress.js, dateUtils.js).

  Alle Daten hier sind fest gesetzt statt aus `Date()` abgeleitet — sonst
  schlagen die Tests je nach Wochentag des Testlaufs unterschiedlich aus.
*/
final class PlanProgressTests: XCTestCase {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// 5. Januar 2026 ist ein Montag — Ausgangspunkt für alle Rechnungen hier.
    private var monday: Date { date(2026, 1, 5) }

    // MARK: - Woche und Zyklus

    func testWochenZaehlenAbEinsUndZyklenAlternieren() {
        let cases: [(offsetDays: Int, week: Int, cycle: Int)] = [
            (0, 1, 0),    // Starttag
            (6, 1, 0),    // Ende Woche 1
            (7, 2, 1),    // Woche 2 -> Zyklus 2
            (13, 2, 1),
            (14, 3, 0),   // Woche 3 -> zurück zu Zyklus 1
            (21, 4, 1),
        ]

        for c in cases {
            let day = calendar.date(byAdding: .day, value: c.offsetDays, to: monday)!
            let info = PlanProgress.weekInfo(for: day, start: monday)
            XCTAssertEqual(info.weekIdx, c.week, "Tag +\(c.offsetDays): Woche")
            XCTAssertEqual(info.cycleIdx, c.cycle, "Tag +\(c.offsetDays): Zyklus")
        }
    }

    /// Die Uhrzeit darf nichts verschieben: 23:59 am Starttag ist noch Woche 1.
    func testUhrzeitVerschiebtDieWocheNicht() {
        let lateOnStartDay = calendar.date(byAdding: .hour, value: 23, to: monday)!
        XCTAssertEqual(PlanProgress.weekInfo(for: lateOnStartDay, start: monday).weekIdx, 1)
    }

    // MARK: - Wochentagssuche

    func testLetzterUndNaechsterWochentag() {
        let thursday = date(2026, 1, 8)   // Donnerstag

        // Der letzte Montag vor/an diesem Donnerstag ist der 5.
        XCTAssertEqual(
            PlanProgress.mostRecentWeekday(onOrBefore: thursday, "Mo"),
            PlanProgress.normalize(monday)
        )
        // Derselbe Tag zählt als "heute", nicht als "vor sieben Tagen".
        XCTAssertEqual(
            PlanProgress.mostRecentWeekday(onOrBefore: thursday, "Do"),
            PlanProgress.normalize(thursday)
        )
        // Der nächste Montag ab Donnerstag ist der 12.
        XCTAssertEqual(
            PlanProgress.nextWeekday(onOrAfter: thursday, "Mo"),
            PlanProgress.normalize(date(2026, 1, 12))
        )
        XCTAssertEqual(
            PlanProgress.nextWeekday(onOrAfter: thursday, "Do"),
            PlanProgress.normalize(thursday)
        )
    }

    // MARK: - Fortschritt

    private func plan(durationWeeks: Int, days: [String]) -> ActivePlan {
        ActivePlan(
            startDate: monday,
            duration: durationWeeks,
            days: days,
            split: SplitType.fullBody.rawValue,
            method: .standard,
            count: 5,
            restTime: 60,
            dayPlans: [:]
        )
    }

    func testTrainingstagWirdErkannt() {
        let p = plan(durationWeeks: 4, days: ["Mo", "Mi", "Fr"])

        let onMonday = PlanProgress.progress(for: p, today: monday)
        XCTAssertTrue(onMonday.isTrainingDay)
        XCTAssertEqual(onMonday.todayLabel, "Mo")
        XCTAssertFalse(onMonday.finished)

        let onTuesday = PlanProgress.progress(for: p, today: date(2026, 1, 6))
        XCTAssertFalse(onTuesday.isTrainingDay)
        XCTAssertEqual(onTuesday.todayLabel, "Di")
    }

    func testPlanEndetNachSeinerDauer() {
        let p = plan(durationWeeks: 2, days: ["Mo"])

        // Woche 2 läuft noch.
        let inWeek2 = PlanProgress.progress(for: p, today: date(2026, 1, 12))
        XCTAssertFalse(inWeek2.finished)
        XCTAssertEqual(inWeek2.weekIdx, 2)

        // Woche 3 gibt es bei zwei Wochen Dauer nicht mehr.
        let inWeek3 = PlanProgress.progress(for: p, today: date(2026, 1, 19))
        XCTAssertTrue(inWeek3.finished)
        XCTAssertFalse(inWeek3.isTrainingDay, "beendeter Plan hat keine Trainingstage")
    }

    func testVerbleibendeTageWerdenNieNegativ() {
        let p = plan(durationWeeks: 1, days: ["Mo"])
        let longAfter = PlanProgress.progress(for: p, today: date(2026, 6, 1))
        XCTAssertEqual(longAfter.daysLeftTotal, 0)
    }

    /// Liegt der letzte passende Wochentag noch vor dem Start, ist es kein
    /// vergangenes Training, sondern das erste kommende.
    func testTagVorDemStartZaehltAlsBevorstehend() {
        let p = plan(durationWeeks: 4, days: ["Mo", "Fr"])
        // Dienstag, 6.1. — der letzte Freitag (2.1.) liegt vor dem Start.
        let result = PlanProgress.lastTrained(for: p, day: "Fr", today: date(2026, 1, 6))
        XCTAssertTrue(result.upcoming)
        XCTAssertEqual(result.inDays, 3)   // Di -> Fr
    }

    func testVergangenerTrainingstagWirdGezaehlt() {
        let p = plan(durationWeeks: 4, days: ["Mo", "Fr"])
        // Mittwoch, 7.1. — der letzte Montag war vorgestern.
        let result = PlanProgress.lastTrained(for: p, day: "Mo", today: date(2026, 1, 7))
        XCTAssertFalse(result.upcoming)
        XCTAssertEqual(result.daysAgo, 2)
        XCTAssertEqual(result.weekIdx, 1)
        XCTAssertFalse(result.isToday)
    }
}
