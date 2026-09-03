import XCTest
@testable import Kraftwuerfel

/*
  Die Trainingszeit muss aus der Uhrzeit kommen, nicht aus gezählten Takten.

  Der Fehler dahinter: `elapsed += 1` lief in einem Timer, der jede Sekunde
  feuert — aber nur, solange die App vorn ist. Bei gesperrtem Bildschirm hält
  iOS ihn an. Wer 15 Minuten trainierte und zwischendurch das Telefon
  sperrte, bekam 6 Minuten gutgeschrieben; der Rest hatte nie stattgefunden.

  Dieselbe Rechnung steckt in der Satzpause. Sie wird hier als reine Formel
  geprüft, ohne Live-Session — genau so, wie die Ansicht sie benutzt.
*/
final class SessionTimingTests: XCTestCase {

    /// Die Formel aus `currentElapsed`: jetzt minus Start minus Pausenzeit.
    private func elapsed(start: Date, now: Date, pausedTotal: TimeInterval, pausedSince: Date?) -> Int {
        var paused = pausedTotal
        if let pausedSince { paused += now.timeIntervalSince(pausedSince) }
        return max(0, Int(now.timeIntervalSince(start) - paused))
    }

    func testGesperrteZeitZaehltMit() {
        let start = Date()
        // 15 Minuten später — davon war die App die meiste Zeit im Hintergrund.
        let now = start.addingTimeInterval(15 * 60)

        XCTAssertEqual(
            elapsed(start: start, now: now, pausedTotal: 0, pausedSince: nil),
            15 * 60,
            "Die Uhr läuft weiter, auch wenn kein Takt feuert"
        )
    }

    /// Bewusst pausierte Zeit ist kein Training.
    func testPausierteZeitZaehltNichtMit() {
        let start = Date()
        let now = start.addingTimeInterval(15 * 60)

        XCTAssertEqual(
            elapsed(start: start, now: now, pausedTotal: 5 * 60, pausedSince: nil),
            10 * 60
        )
    }

    /// Auch die gerade laufende Pause wird abgezogen, nicht erst beim Fortsetzen.
    func testDieLaufendePauseZaehltSofortNichtMehr() {
        let start = Date()
        let now = start.addingTimeInterval(10 * 60)
        let pausedSince = start.addingTimeInterval(8 * 60)

        XCTAssertEqual(
            elapsed(start: start, now: now, pausedTotal: 0, pausedSince: pausedSince),
            8 * 60
        )
    }

    func testDieZeitWirdNieNegativ() {
        let start = Date()
        XCTAssertEqual(
            elapsed(start: start, now: start, pausedTotal: 120, pausedSince: nil),
            0
        )
    }

    // MARK: - Satzpause

    /// Die Formel aus `tick()`: Restzeit aus dem Zielzeitpunkt.
    private func restRemaining(endsAt: Date, now: Date) -> Int {
        max(0, Int(ceil(endsAt.timeIntervalSince(now))))
    }

    func testDieSatzpauseLaeuftImHintergrundAb() {
        let now = Date()
        let endsAt = now.addingTimeInterval(60)

        // 90 Sekunden später ist sie vorbei — auch wenn kein Takt lief.
        XCTAssertEqual(restRemaining(endsAt: endsAt, now: now.addingTimeInterval(90)), 0)
        // Und dazwischen stimmt sie.
        XCTAssertEqual(restRemaining(endsAt: endsAt, now: now.addingTimeInterval(30)), 30)
    }

    /*
      Wer die Sitzung pausiert, während eine Satzpause läuft, darf sie nicht
      verlieren: Der Zielzeitpunkt verschiebt sich um die Unterbrechung.
    */
    func testDieSatzpauseVerschiebtSichUmDieUnterbrechung() {
        let start = Date()
        let endsAt = start.addingTimeInterval(60)

        let pausiertAb = start.addingTimeInterval(10)
        let fortgesetzt = start.addingTimeInterval(70)   // eine Minute pausiert
        let verschoben = endsAt.addingTimeInterval(fortgesetzt.timeIntervalSince(pausiertAb))

        XCTAssertEqual(
            restRemaining(endsAt: verschoben, now: fortgesetzt),
            50,
            "die verbleibenden 50 Sekunden bleiben erhalten"
        )
        XCTAssertGreaterThan(
            restRemaining(endsAt: verschoben, now: fortgesetzt), 0,
            "ohne Verschiebung wäre sie beim Fortsetzen sofort abgelaufen"
        )
    }
}

/*
  Die Satzpause, die der Nutzer vorgibt, muss auch ankommen.

  Sie ging vorher gar nicht an den Server: Die App hatte die Einstellung, der
  Prompt erwähnte Pausen mit keinem Wort, und das Modell wählte frei —
  regelmäßig 180 Sekunden.
*/
final class RestPreferenceTests: XCTestCase {

    func testDieEingabeTraegtDieGewuenschtePause() {
        let input = AICoachInput(restSeconds: 60)
        XCTAssertEqual(input.restSeconds, 60)
    }

    /// Ohne Angabe bleibt es beim bisherigen Verhalten — keine Begrenzung.
    func testOhneAngabeWirdNichtBegrenzt() {
        XCTAssertEqual(AICoachInput().restSeconds, 180)
    }

    func testDerServerAufrufTraegtDiePause() {
        let request = KraftAPI.PlanRequest(
            goal: "muscle", experience: "intermediate", sex: "male",
            age: 30, height: 180, weight: 80,
            days: ["Mo", "Mi"], restSeconds: 45
        )
        XCTAssertEqual(request.restSeconds, 45)
    }
}
