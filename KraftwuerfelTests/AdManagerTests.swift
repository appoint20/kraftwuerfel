import XCTest
@testable import Kraftwuerfel

/*
  Diese Tests haben die Seiten gewechselt.

  Vorher hielten sie den 3-Video-Ablauf fest: Der KI-Coach war gesperrt, bis
  drei „Rewarded Videos“ gelaufen waren. Hinter diesen Videos steckte nie ein
  Werbenetz — `startAdPlayback` zeigte eine selbstgebaute Ansicht mit der
  Aufschrift „SPONSOR AD“ und einem Zähler, sonst nichts. Platzhalterinhalt
  also, und eine Funktion, die dahinter eingeschlossen war: in der App-Prüfung
  ein Ablehnungsgrund (Richtlinie 2.1).

  `AdManager.adsEnabled` steht deshalb auf `false`. Diese Tests halten jetzt
  fest, dass in diesem Zustand nichts angezeigt wird und keine Funktion mehr
  hinter etwas hängt, das es nicht gibt. Wird ein echtes SDK eingebunden und
  der Schalter umgelegt, müssen sie wieder umgeschrieben werden — dann
  zusammen mit ATT, Datenschutzmanifest und Datenschutzerklärung.
*/
@MainActor
final class AdManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AdManager.shared.consumeAIPlanReward()
        AdManager.shared.resetCooldown()
    }

    // MARK: - Der Hauptschalter

    func testWerbungIstAus() {
        XCTAssertFalse(
            AdManager.adsEnabled,
            "Ohne eingebundenes Werbenetz darf die App keine Platzhalter-Werbung zeigen (Richtlinie 2.1)."
        )
    }

    func testOhneWerbungWirdKeinVideoVerlangt() {
        XCTAssertEqual(AdManager.shared.requiredRewardedVideos, 0)
    }

    // MARK: - Keine Funktion hängt hinter Platzhaltern

    func testDerKICoachIstNichtHinterVideosEingeschlossen() {
        let adManager = AdManager.shared
        adManager.consumeAIPlanReward()

        XCTAssertTrue(
            adManager.isAIPlanUnlockedForFree,
            "Eine Schranke, die sich nur über nicht vorhandene Videos öffnen lässt, wäre unpassierbar."
        )
    }

    func testDasTrainingsarchivIstNichtHinterVideosEingeschlossen() {
        let adManager = AdManager.shared
        adManager.historyUnlockedUntil = nil

        XCTAssertTrue(adManager.isHistoryArchiveUnlocked)
    }

    func testRewardedVideoSchaltetSofortFreiOhneEtwasAnzuzeigen() {
        let adManager = AdManager.shared
        var kamAn = false

        adManager.watchRewardedVideoForAIPlan { erfolg in
            XCTAssertTrue(erfolg)
            kamAn = true
        }

        XCTAssertTrue(kamAn, "Der Rückruf muss trotzdem kommen, sonst hängt der Aufrufer")
        XCTAssertFalse(adManager.isShowingAdModal)
    }

    func testArchivFreischaltungLaeuftDurchOhneEinblendung() {
        let adManager = AdManager.shared
        var kamAn = false

        adManager.watchRewardedVideoForHistoryArchive { erfolg in
            XCTAssertTrue(erfolg)
            kamAn = true
        }

        XCTAssertTrue(kamAn)
        XCTAssertFalse(adManager.isShowingAdModal)
        XCTAssertTrue(adManager.isHistoryArchiveUnlocked)
    }

    func testMusikStartWirdNichtAufgehalten() {
        let adManager = AdManager.shared
        var gestartet = false

        adManager.triggerSpotifyPreRollAd { gestartet = true }

        XCTAssertTrue(gestartet, "Die Playlist muss sofort starten, wenn es keine Vorschaltwerbung gibt")
        XCTAssertFalse(adManager.isShowingAdModal)
    }

    // MARK: - Keine Einblendung, egal woher der Aufruf kommt

    func testKeineEinblendungInDerLiveSession() {
        let adManager = AdManager.shared
        #if DEBUG
        StoreKitManager.shared.debugProOverride = false
        #endif

        adManager.triggerLiveSessionExerciseTransitionAd(exerciseCount: 5)
        XCTAssertFalse(adManager.isShowingAdModal)

        adManager.triggerLiveSessionExerciseTransitionAd(exerciseCount: 12)
        XCTAssertFalse(adManager.isShowingAdModal)
    }

    func testKeineEinblendungImFortschrittUndAmWuerfel() {
        let adManager = AdManager.shared
        #if DEBUG
        StoreKitManager.shared.debugProOverride = false
        #endif

        adManager.triggerProgressAnalyticsAd()
        XCTAssertFalse(adManager.isShowingAdModal)

        adManager.resetCooldown()
        adManager.triggerDiceGeneratorAd()
        XCTAssertFalse(adManager.isShowingAdModal)
    }

    /*
      Die letzte Sperre sitzt in `startAdPlayback` selbst. Auch ein Aufruf,
      den jemand später vergisst abzusichern, darf nichts anzeigen.
    */
    func testAuchDirekteWiedergabeZeigtNichts() {
        let adManager = AdManager.shared
        adManager.resetCooldown()

        for _ in 0..<5 {
            adManager.triggerDiceGeneratorAd()
            adManager.triggerProgressAnalyticsAd()
            adManager.resetCooldown()
        }

        XCTAssertFalse(adManager.isShowingAdModal)
        XCTAssertFalse(adManager.isAdPlaying)
    }
}
