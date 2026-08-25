import XCTest
@testable import Kraftwuerfel

/*
  Wochentags-Reihenfolge (src/lib/planOrder.test.js).

  Die App rechnet in Mo-zuerst-Notation, `Calendar` liefert So = 1. Diese
  Umrechnung ist die Stelle, an der ein Off-by-one niemandem auffällt, bis die
  Favoritenliste am falschen Tag beginnt.
*/
final class WeekdayOrderTests: XCTestCase {

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testHeutigerTagInMoZuerstNotation() {
        let expected: [(Date, String)] = [
            (date(2026, 1, 5), "Mo"),
            (date(2026, 1, 6), "Di"),
            (date(2026, 1, 7), "Mi"),
            (date(2026, 1, 8), "Do"),
            (date(2026, 1, 9), "Fr"),
            (date(2026, 1, 10), "Sa"),
            (date(2026, 1, 11), "So"),
        ]
        for (day, label) in expected {
            XCTAssertEqual(Weekdays.today(day), label)
        }
    }

    func testFavoritenlisteBeginntBeimHeutigenTag() {
        XCTAssertEqual(Weekdays.rotatedFromToday(date(2026, 1, 8)).first, "Do")
        XCTAssertEqual(Weekdays.rotatedFromToday(date(2026, 1, 11)).first, "So")
    }

    func testWocheLaeuftNachHeuteNormalWeiter() {
        XCTAssertEqual(
            Weekdays.rotatedFromToday(date(2026, 1, 8)),
            ["Do", "Fr", "Sa", "So", "Mo", "Di", "Mi"]
        )
    }

    func testEnthaeltImmerAlleSiebenTageGenauEinmal() {
        for offset in 0..<14 {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            let day = calendar.date(byAdding: .day, value: offset, to: date(2026, 1, 5))!
            let rotated = Weekdays.rotatedFromToday(day)

            XCTAssertEqual(rotated.count, 7)
            XCTAssertEqual(Set(rotated), Set(Weekdays.all))
        }
    }

    /// Wer Fr, Mo, Mi anklickt, soll Mo, Mi, Fr sehen — nicht seine
    /// Klickreihenfolge.
    func testTageWerdenNachWochentagSortiertNichtNachAuswahl() {
        XCTAssertEqual(Weekdays.sorted(["Fr", "Mo", "Mi"]), ["Mo", "Mi", "Fr"])
        XCTAssertEqual(Weekdays.sorted(["So", "Sa"]), ["Sa", "So"])
        XCTAssertEqual(Weekdays.sorted(Set(Weekdays.all)), Weekdays.all)
        XCTAssertEqual(Weekdays.sorted([]), [])
    }
}
