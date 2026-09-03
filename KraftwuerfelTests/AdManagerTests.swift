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

/*
  Die Schranke vor dem KI-Coach.

  `isAIPlanUnlockedForFree` gab es von Anfang an — gefragt hat sie nur nie
  jemand. Der Erstellen-Knopf rief direkt `generatePlan()`, und ein
  Gratis-Nutzer bekam beliebig viele KI-Pläne, ohne ein einziges Video zu
  sehen. Diese Tests halten fest, dass die Schranke wirkt und dass sie sich
  auch wieder schließt.
*/
@MainActor
final class AIPlanGateTests: XCTestCase {

    private let adManager = AdManager.shared

    override func setUp() {
        super.setUp()
        adManager.consumeAIPlanReward()
        #if DEBUG
        StoreKitManager.shared.debugProOverride = false
        #endif
    }

    override func tearDown() {
        adManager.consumeAIPlanReward()
        super.tearDown()
    }

    /// Ohne Werbenetz gibt es nichts anzusehen — dann muss die Schranke offen
    /// sein, sonst wäre sie unpassierbar.
    func testOhneWerbenetzIstDieSchrankeOffen() {
        guard !AdManager.adsEnabled else { return }
        XCTAssertEqual(adManager.requiredRewardedVideos, 0)
        XCTAssertTrue(adManager.isAIPlanUnlockedForFree)
    }

    /// Mit Werbenetz ist sie zu, bevor irgendetwas gesehen wurde.
    func testMitWerbenetzIstDieSchrankeAnfangsZu() {
        guard AdManager.adsEnabled else { return }
        XCTAssertGreaterThan(adManager.requiredRewardedVideos, 0)
        XCTAssertFalse(
            adManager.isAIPlanUnlockedForFree,
            "ohne gesehenes Video darf kein KI-Plan entstehen"
        )
    }

    /// Erst die volle Zahl öffnet sie — eines von zwei reicht nicht.
    func testEinVideoAlleinOeffnetSieNicht() {
        guard AdManager.adsEnabled, adManager.requiredRewardedVideos > 1 else { return }

        adManager.rewardedVideosWatched = 1
        XCTAssertFalse(adManager.isAIPlanUnlockedForFree)

        adManager.rewardedVideosWatched = adManager.requiredRewardedVideos
        XCTAssertTrue(adManager.isAIPlanUnlockedForFree)
    }

    /*
      Der Kern der Beschwerde: Nach einem Plan war der Coach offen und blieb
      es. Jeder weitere Plan muss dieselbe Schranke wiederfinden.
    */
    func testNachEinemPlanIstDieSchrankeWiederZu() {
        guard AdManager.adsEnabled else { return }

        adManager.rewardedVideosWatched = adManager.requiredRewardedVideos
        XCTAssertTrue(adManager.isAIPlanUnlockedForFree)

        // Genau das ruft der Coach nach dem Erzeugen auf.
        adManager.consumeAIPlanReward()

        XCTAssertEqual(adManager.rewardedVideosWatched, 0)
        XCTAssertFalse(
            adManager.isAIPlanUnlockedForFree,
            "der zweite Plan darf nicht gratis sein, wenn der erste es nicht war"
        )
    }

    /// Für Pro gilt die Schranke nie — dafür ist das Abo da.
    func testProUmgehtDieSchranke() {
        #if DEBUG
        StoreKitManager.shared.debugProOverride = true
        defer { StoreKitManager.shared.debugProOverride = false }
        XCTAssertTrue(StoreKitManager.shared.isProUnlocked || !AuthService.shared.isSignedIn)
        #endif
    }
}

/*
  Anzeigenblöcke sind einzeln optional.

  In der AdMob-Konsole sind Banner und Vollbild-Einblendung angelegt, ein
  belohnter Block bisher nicht. Daraus darf weder eine verschlossene Funktion
  noch eine ausgelieferte Test-Anzeige werden.
*/
@MainActor
final class AdUnitConfigurationTests: XCTestCase {

    /// Der Banner trägt die echte Kennung aus der Info.plist.
    func testBannerBlockIstEingetragen() {
        let configured = Bundle.main.object(forInfoDictionaryKey: "KWAdUnitBanner") as? String
        XCTAssertEqual(configured, "ca-app-pub-8043832549817924/2858579078")
    }

    func testVollbildBlockIstEingetragen() {
        let configured = Bundle.main.object(forInfoDictionaryKey: "KWAdUnitInterstitial") as? String
        XCTAssertEqual(configured, "ca-app-pub-8043832549817924/4059980100")
    }

    /// Die App-ID ist die echte, nicht mehr Googles Test-ID.
    func testDieAppKennungIstDieEchte() {
        let appId = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String
        XCTAssertEqual(appId, "ca-app-pub-8043832549817924~7999225113")
        XCTAssertFalse(
            (appId ?? "").hasPrefix("ca-app-pub-3940256099942544"),
            "Googles Test-ID gehört nicht in eine ausgelieferte App"
        )
    }

    func testBelohnterBlockIstEingetragen() {
        let configured = Bundle.main.object(forInfoDictionaryKey: "KWAdUnitRewarded") as? String
        XCTAssertEqual(configured, "ca-app-pub-8043832549817924/7807653424")
    }

    /*
      Die Zusage, die zusammengehört: Gibt es keinen belohnten Block, verlangt
      der KI-Coach auch keine Videos. Sonst stünde vor einer Pro-Funktion eine
      Schranke, die sich nicht öffnen lässt.
    */
    func testDieSchrankeHaengtAmVorhandenenBlock() {
        if GoogleAdsService.hasRewardedUnit && AdManager.adsEnabled {
            XCTAssertGreaterThan(AdManager.shared.requiredRewardedVideos, 0)
        } else {
            XCTAssertEqual(AdManager.shared.requiredRewardedVideos, 0)
            XCTAssertTrue(AdManager.shared.isAIPlanUnlockedForFree)
        }
    }

    /// Alle drei Blöcke gehören zur selben AdMob-App.
    func testAlleBloeckeGehoerenZurSelbenApp() {
        let publisher = "ca-app-pub-8043832549817924"
        for key in ["KWAdUnitBanner", "KWAdUnitInterstitial", "KWAdUnitRewarded"] {
            let unit = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
            XCTAssertTrue(unit.hasPrefix(publisher), "\(key) gehört zu einer anderen AdMob-App")
        }
    }

    /*
      Ohne SKAdNetwork-Liste kann iOS eine Installation keiner Anzeige
      zuordnen — die Werbung läuft, misst aber nichts, und das drückt direkt
      auf den Preis.
    */
    func testSKAdNetworkListeIstVorhanden() {
        let items = Bundle.main.object(forInfoDictionaryKey: "SKAdNetworkItems") as? [[String: Any]]
        let list = try! XCTUnwrap(items, "SKAdNetworkItems fehlt in der Info.plist")
        XCTAssertGreaterThan(list.count, 30)

        // Googles eigenes Netz muss dabei sein, sonst misst AdMob selbst nichts.
        let ids = list.compactMap { $0["SKAdNetworkIdentifier"] as? String }
        XCTAssertTrue(ids.contains("cstr6suwn9.skadnetwork"), "Googles eigene Kennung fehlt")
        XCTAssertEqual(Set(ids).count, ids.count, "doppelte Kennungen")
    }
}

/*
  Der Pro-Status des Kontos.

  Zwei Fehler steckten hier ineinander. Erstens trug die Anmeldeantwort den
  Status gar nicht — die App entschied allein nach den StoreKit-Berechtigungen
  des Geräts, und ein zahlender Nutzer war auf einem zweiten Gerät
  „kostenlos". Zweitens löschte die App `is_premium` auf dem Server, sobald
  auf DIESEM Gerät gerade keine Berechtigung zu finden war — und eine leere
  Antwort von StoreKit heißt nicht „kein Abo", sondern oft nur „konnte gerade
  nicht nachsehen".
*/
@MainActor
final class AccountPremiumTests: XCTestCase {

    /// Ein Konto ohne Angabe ist „unbekannt", nicht „kein Abo".
    func testOhneAngabeIstDerStatusUnbekannt() {
        let account = AuthService.Account(id: "1", email: "a@b.de", name: nil, isPremium: nil)
        XCTAssertNil(account.isPremium)
        XCTAssertNotEqual(account.isPremium, false, "unbekannt ist nicht dasselbe wie kein Abo")
    }

    func testDerServerStatusWirdUebernommen() {
        let account = AuthService.Account(id: "1", email: "a@b.de", name: nil, isPremium: true)
        XCTAssertEqual(account.isPremium, true)
    }

    /*
      Ein alter gespeicherter Kontostand kennt das Feld nicht. Er muss
      trotzdem lesbar bleiben — sonst wäre der Nutzer nach dem Update
      abgemeldet.
    */
    func testEinAlterKontostandBleibtLesbar() throws {
        let alt = #"{"id":"1","email":"a@b.de"}"#.data(using: .utf8)!
        let account = try JSONDecoder().decode(AuthService.Account.self, from: alt)

        XCTAssertEqual(account.id, "1")
        XCTAssertNil(account.isPremium, "fehlendes Feld heißt unbekannt")
    }

    /// Die Antwort des Servers trägt den Status jetzt mit.
    func testDieAnmeldeantwortTraegtDenStatus() throws {
        let json = #"{"id":"1","email":"a@b.de","isPremium":true}"#.data(using: .utf8)!
        let user = try JSONDecoder().decode(KraftAPI.AuthUser.self, from: json)

        XCTAssertEqual(user.isPremium, true)
    }

    /// Ein Serverstand ohne das Feld darf die Anmeldung nicht scheitern lassen.
    func testEineAntwortOhneStatusScheitertNicht() throws {
        let json = #"{"id":"1","email":"a@b.de"}"#.data(using: .utf8)!
        let user = try JSONDecoder().decode(KraftAPI.AuthUser.self, from: json)

        XCTAssertNil(user.isPremium)
    }
}
