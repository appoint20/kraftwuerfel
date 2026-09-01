import XCTest
@testable import Kraftwuerfel

/*
  Diese Tests haben zum zweiten Mal die Seiten gewechselt.

  Zuerst hielten sie den Video-Ablauf fest. Dann — als klar wurde, dass
  hinter den „Rewarded Videos" nie ein Werbenetz stand, sondern eine
  selbstgebaute Ansicht mit der Aufschrift „SPONSOR AD" — hielten sie fest,
  dass gar nichts angezeigt wird und keine Funktion hinter Platzhaltern
  hängt (App-Store-Richtlinie 2.1).

  Jetzt steckt das Google-Mobile-Ads-SDK dahinter. Damit gilt eine dritte
  Zusage, und sie ist die wichtigste von allen:

      Es gibt echte Werbung oder gar keine — nie wieder eine nachgebaute.

  Und weil Werbung ausfallen kann (kein Netz, kein Inventar, Zustimmung
  abgelehnt), darf kein Rückruf davon abhängen, dass sie erscheint.
*/
@MainActor
final class AdManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AdManager.shared.consumeAIPlanReward()
        AdManager.shared.resetCooldown()
    }

    // MARK: - Der Hauptschalter

    /// Werbung läuft genau dann, wenn eine AdMob-App-ID eingetragen ist —
    /// nicht mehr an einer von Hand gepflegten Konstante.
    func testDerHauptschalterFolgtDerEinrichtung() {
        XCTAssertEqual(AdManager.adsEnabled, GoogleAdsService.isConfigured)
    }

    func testDieVideozahlPasstZumHauptschalter() {
        let erwartet = AdManager.adsEnabled ? 2 : 0
        XCTAssertEqual(AdManager.shared.requiredRewardedVideos, erwartet)
    }

    /*
      Die eine Zusage, die nicht brechen darf: Wenn keine echte Werbung
      vorliegt, wird KEINE nachgebaute gezeigt. Lieber gar keine.
    */
    func testEsWirdNiemalsEineNachgebauteWerbungGezeigt() {
        let adManager = AdManager.shared
        #if DEBUG
        StoreKitManager.shared.debugProOverride = false
        #endif

        adManager.watchRewardedVideoForAIPlan { _ in }
        XCTAssertFalse(adManager.isShowingAdModal, "keine Platzhalter-Anzeige")

        adManager.triggerLiveSessionExerciseTransitionAd(exerciseCount: 8)
        XCTAssertFalse(adManager.isShowingAdModal)

        adManager.resetCooldown()
        adManager.triggerDiceGeneratorAd()
        XCTAssertFalse(adManager.isShowingAdModal)
    }

    // MARK: - Keine Funktion hängt hinter Platzhaltern

    /*
      Ohne Werbenetz darf die Schranke nicht existieren — sie ließe sich
      sonst auf dem beworbenen Weg gar nicht öffnen. Mit Werbenetz darf sie
      existieren, aber nur mit einer erreichbaren Zahl.
    */
    func testDieKISchrankeIstImmerPassierbar() {
        let adManager = AdManager.shared
        adManager.consumeAIPlanReward()

        if AdManager.adsEnabled {
            XCTAssertGreaterThan(adManager.requiredRewardedVideos, 0)
            XCTAssertLessThanOrEqual(adManager.requiredRewardedVideos, 3, "mehr als drei Videos sieht niemand")
        } else {
            XCTAssertTrue(
                adManager.isAIPlanUnlockedForFree,
                "Eine Schranke, die sich nur über nicht vorhandene Videos öffnen lässt, wäre unpassierbar."
            )
        }
    }

    func testDasTrainingsarchivBleibtOhneWerbungOffen() {
        let adManager = AdManager.shared
        adManager.historyUnlockedUntil = nil

        if !AdManager.adsEnabled {
            XCTAssertTrue(adManager.isHistoryArchiveUnlocked)
        }
    }

    /// Ob Werbung erscheint oder nicht: Der Aufrufer darf nie hängen bleiben.
    func testRewardedVideoLaesstDenAufruferNieHaengen() {
        let adManager = AdManager.shared
        var kamAn = false

        adManager.watchRewardedVideoForAIPlan { erfolg in
            XCTAssertTrue(erfolg)
            kamAn = true
        }

        XCTAssertTrue(kamAn, "Der Rückruf muss kommen, auch wenn keine Werbung vorliegt")
        XCTAssertFalse(adManager.isShowingAdModal)
    }

    func testArchivFreischaltungLaesstDenAufruferNieHaengen() {
        let adManager = AdManager.shared
        var kamAn = false

        adManager.watchRewardedVideoForHistoryArchive { erfolg in
            XCTAssertTrue(erfolg)
            kamAn = true
        }

        XCTAssertTrue(kamAn)
        XCTAssertFalse(adManager.isShowingAdModal)
    }

    func testMusikStartWirdNichtAufgehalten() {
        let adManager = AdManager.shared
        var gestartet = false

        adManager.triggerSpotifyPreRollAd { gestartet = true }

        XCTAssertTrue(gestartet, "Die Playlist muss starten, auch wenn keine Vorschaltwerbung vorliegt")
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
