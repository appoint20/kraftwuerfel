import XCTest
@testable import Kraftwuerfel

/*
  Die Trainingserinnerung um neun.

  Vorher stand dahinter ein wöchentlich wiederkehrender Auslöser je
  Wochentag. Der feuert unabänderlich: Wer montags früh im Studio war, bekam
  am nächsten Montag dieselbe Erinnerung. Ein einzelner wiederkehrender
  Auslöser lässt sich auch nicht für eine Woche abbestellen — ihn zu löschen
  löscht alle künftigen mit.

  Deshalb einzelne, datierte Termine. Die Regeln dafür stehen hier.
*/
final class ReminderScheduleTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }()

    /// Montag, 5. Januar 2026, 07:00 Ortszeit.
    private func montagFrueh() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 5; c.hour = 7; c.minute = 0
        return calendar.date(from: c)!
    }

    private func dates(
        days: [String],
        from now: Date,
        weeksAhead: Int = 4,
        trained: Set<Date> = []
    ) -> [Date] {
        NotificationManager.upcomingReminderDates(
            days: days, hour: 9, minute: 0, weeksAhead: weeksAhead,
            from: now, trainedDates: trained, calendar: calendar
        )
    }

    func testEsGibtEinenTerminJeTrainingstagUndWoche() {
        let termine = dates(days: ["Mo", "Mi", "Fr"], from: montagFrueh(), weeksAhead: 2)

        // Zwei Wochen à drei Tage — der heutige Montag um neun zählt mit,
        // weil es erst sieben Uhr ist.
        XCTAssertEqual(termine.count, 6)
        XCTAssertTrue(termine.allSatisfy { calendar.component(.hour, from: $0) == 9 })
        XCTAssertTrue(termine.allSatisfy { calendar.component(.minute, from: $0) == 0 })
    }

    func testNurTermineInDerZukunft() {
        // Derselbe Montag, aber schon zehn Uhr — neun Uhr ist vorbei.
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 5; c.hour = 10; c.minute = 0
        let montagSpaet = calendar.date(from: c)!

        let termine = dates(days: ["Mo"], from: montagSpaet, weeksAhead: 1)

        XCTAssertEqual(termine.count, 0, "der heutige Termin ist vorbei, nächste Woche liegt außerhalb")
        XCTAssertTrue(termine.allSatisfy { $0 > montagSpaet })
    }

    /*
      Der Kern der Änderung: An einem Tag, an dem das Training schon im
      Archiv steht, kommt keine Erinnerung mehr.
    */
    func testKeineErinnerungAnEinemTagAnDemSchonTrainiertWurde() {
        let start = montagFrueh()
        let heute = calendar.startOfDay(for: start)

        let ohne = dates(days: ["Mo"], from: start, weeksAhead: 1)
        XCTAssertEqual(ohne.count, 1)

        let mit = dates(days: ["Mo"], from: start, weeksAhead: 1, trained: [heute])
        XCTAssertEqual(mit.count, 0, "heute wurde schon trainiert")
    }

    func testEinTrainingsTagBetrifftNurSeinenEigenenTermin() {
        let start = montagFrueh()
        let heute = calendar.startOfDay(for: start)

        let termine = dates(days: ["Mo", "Mi"], from: start, weeksAhead: 1, trained: [heute])

        XCTAssertEqual(termine.count, 1, "der Mittwoch bleibt stehen")
        XCTAssertEqual(calendar.component(.weekday, from: termine[0]), 4, "Mittwoch")
    }

    func testOhneTrainingstageGibtEsKeineTermine() {
        XCTAssertTrue(dates(days: [], from: montagFrueh()).isEmpty)
        XCTAssertTrue(dates(days: ["Quatsch"], from: montagFrueh()).isEmpty)
    }

    /// iOS hält höchstens 64 offene Meldungen vor — sieben Tage die Woche
    /// über vier Wochen müssen darunter bleiben.
    func testDerVorratBleibtUnterDemSystemlimit() {
        let alle = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        let termine = dates(days: alle, from: montagFrueh(), weeksAhead: 4)

        XCTAssertLessThanOrEqual(termine.count, 64)
        XCTAssertEqual(termine.count, 28)
    }

    /// Jeder Tag trägt seinen eigenen Namen — nur so lässt sich ein einzelner
    /// zurückziehen, wenn das Training dieses Tages erledigt ist.
    func testJederTerminHatEinenEigenenNamenMitDatum() {
        let termine = dates(days: ["Mo", "Mi"], from: montagFrueh(), weeksAhead: 2)
        let namen = termine.map { NotificationManager.workoutReminderId(for: $0, calendar: calendar) }

        XCTAssertEqual(Set(namen).count, namen.count, "keine zwei Termine teilen sich einen Namen")
        XCTAssertTrue(namen.allSatisfy { $0.hasPrefix(NotificationManager.workoutReminderPrefix) })
        XCTAssertTrue(namen.contains { $0.hasSuffix("2026-01-05") }, "der Montag steht mit seinem Datum drin")
    }

    func testDieTermineStehenInZeitlicherReihenfolge() {
        let termine = dates(days: ["Mo", "Mi", "Fr"], from: montagFrueh(), weeksAhead: 3)
        XCTAssertEqual(termine, termine.sorted())
    }
}

/*
  Welche Tage als „schon trainiert" gelten. Der Archivspeicher liefert sie
  auf Mitternacht normalisiert, damit die Uhrzeit des Trainings nicht
  darüber entscheidet, ob der Tag als erledigt zählt.
*/
final class TrainedDatesTests: XCTestCase {

    func testDieUhrzeitDesTrainingsSpieltKeineRolle() {
        let store = WorkoutHistoryStore.shared
        store.wipe()
        defer { store.wipe() }

        _ = store.logSession(
            planTitle: "Test",
            durationSeconds: 600,
            peakHeartRate: nil,
            estimatedCalories: nil,
            exercises: [],
            motivationalQuote: ""
        )

        let heute = Calendar.current.startOfDay(for: Date())
        XCTAssertTrue(store.trainedDates().contains(heute))
    }

    func testOhneTrainingIstDieMengeLeer() {
        let store = WorkoutHistoryStore.shared
        store.wipe()
        defer { store.wipe() }

        XCTAssertTrue(store.trainedDates().isEmpty)
    }
}
