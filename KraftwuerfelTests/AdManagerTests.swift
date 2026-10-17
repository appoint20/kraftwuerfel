import XCTest
@testable import Kraftwuerfel

/*
  Rewarded unlocks require a real SDK reward and completed presentation.
  Missing inventory, failed presentation, early dismissal and UI taps grant
  no credit. Optional interstitials can be skipped without blocking a workout.
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
        XCTAssertEqual(AdManager.shared.requiredRewardedVideos, 2)
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

    // MARK: - Unavailable ads grant no credit
    func testUnavailableVideoDoesNotUnlockTheCoach() {
        let presenter = FakeRewardedAdPresenter()
        let manager = AdManager(rewardedPresenter: presenter, proProvider: { false })
        manager.watchRewardedVideoForAIPlan { XCTAssertFalse($0) }
        manager.watchRewardedVideoForAIPlan { XCTAssertFalse($0) }
        XCTAssertEqual(manager.rewardedVideosWatched, 0)
        XCTAssertFalse(manager.isAIPlanUnlockedForFree)
        XCTAssertFalse(manager.isShowingAdModal)
    }

    func testDasTrainingsarchivBleibtOhneWerbungOffen() {
        let adManager = AdManager.shared
        adManager.historyUnlockedUntil = nil

        if !AdManager.adsEnabled {
            XCTAssertTrue(adManager.isHistoryArchiveUnlocked)
        }
    }

    /// Unavailable inventory reports failure rather than a fabricated reward.
    func testUnavailableVideoCompletesWithFailure() {
        let presenter = FakeRewardedAdPresenter()
        let manager = AdManager(rewardedPresenter: presenter, proProvider: { false })
        var result: Bool?
        manager.watchRewardedVideoForAIPlan { result = $0 }
        XCTAssertEqual(result, false)
        XCTAssertEqual(manager.rewardedVideosWatched, 0)
        XCTAssertFalse(manager.isRewardedVideoInProgress)
    }

    func testUnavailableArchiveVideoDoesNotEarnAnUnlock() {
        let presenter = FakeRewardedAdPresenter()
        let manager = AdManager(rewardedPresenter: presenter, proProvider: { false })
        var result: Bool?
        manager.watchRewardedVideoForHistoryArchive { result = $0 }
        XCTAssertEqual(result, false)
        XCTAssertNil(manager.historyUnlockedUntil)
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
private final class FakeRewardedAdPresenter: RewardedAdPresenting {
    var isRewardedConfigured = true
    var shouldPresent = false
    private(set) var presentationCount = 0
    private(set) var sessions: [RewardedAdCompletion] = []

    func showRewarded(onCompletion: @escaping (Bool) -> Void) -> Bool {
        presentationCount += 1
        guard shouldPresent else { return false }
        sessions.append(RewardedAdCompletion(completion: onCompletion))
        return true
    }
}

@MainActor
final class AIPlanGateTests: XCTestCase {
    private var presenter: FakeRewardedAdPresenter!
    private var manager: AdManager!

    override func setUp() {
        super.setUp()
        presenter = FakeRewardedAdPresenter()
        presenter.shouldPresent = true
        manager = AdManager(rewardedPresenter: presenter, proProvider: { false })
    }

    private func completeVideo() {
        manager.watchRewardedVideoForAIPlan { XCTAssertTrue($0) }
        let session = presenter.sessions.last!
        session.didEarnReward()
        session.didDismiss()
    }

    func testMissingConfigurationCannotMakeTheGateFree() {
        presenter.isRewardedConfigured = false
        var result: Bool?
        manager.watchRewardedVideoForAIPlan { result = $0 }
        XCTAssertEqual(result, false)
        XCTAssertEqual(manager.requiredRewardedVideos, 2)
        XCTAssertEqual(manager.rewardedVideosWatched, 0)
        XCTAssertFalse(manager.isAIPlanUnlockedForFree)
        XCTAssertEqual(presenter.presentationCount, 0)
    }

    func testEarnedRewardDoesNotCountUntilTheVideoIsDismissed() {
        var result: Bool?
        manager.watchRewardedVideoForAIPlan { result = $0 }
        let session = presenter.sessions.last!
        session.didEarnReward()
        XCTAssertNil(result)
        XCTAssertEqual(manager.rewardedVideosWatched, 0)
        XCTAssertTrue(manager.isRewardedVideoInProgress)
        session.didDismiss()
        XCTAssertEqual(result, true)
        XCTAssertEqual(manager.rewardedVideosWatched, 1)
        XCTAssertFalse(manager.isRewardedVideoInProgress)
        XCTAssertFalse(manager.isAIPlanUnlockedForFree)
    }

    func testExactlyTwoCompletedSdkVideosUnlockOnePlan() {
        completeVideo()
        XCTAssertEqual(manager.rewardedVideosWatched, 1)
        XCTAssertFalse(manager.isAIPlanUnlockedForFree)
        completeVideo()
        XCTAssertEqual(manager.rewardedVideosWatched, 2)
        XCTAssertTrue(manager.isAIPlanUnlockedForFree)
        manager.consumeAIPlanReward()
        XCTAssertEqual(manager.rewardedVideosWatched, 0)
        XCTAssertFalse(manager.isAIPlanUnlockedForFree)
    }

    func testEarlyDismissalFailureAndSkipDoNotEarnCredit() {
        var completions: [Bool] = []
        manager.watchRewardedVideoForAIPlan { completions.append($0) }
        manager.skipAd()
        XCTAssertTrue(completions.isEmpty)
        XCTAssertEqual(manager.rewardedVideosWatched, 0)
        presenter.sessions.last!.didDismiss()
        XCTAssertEqual(completions, [false])
        manager.watchRewardedVideoForAIPlan { completions.append($0) }
        presenter.sessions.last!.didFail()
        XCTAssertEqual(completions, [false, false])
        XCTAssertEqual(manager.rewardedVideosWatched, 0)
        XCTAssertFalse(manager.isAIPlanUnlockedForFree)
    }

    func testRepeatedTapAndDuplicateOrLateCallbacksDoNotDoubleCount() {
        var first: [Bool] = []
        manager.watchRewardedVideoForAIPlan { first.append($0) }
        manager.watchRewardedVideoForAIPlan { XCTAssertFalse($0) }
        XCTAssertEqual(presenter.presentationCount, 1)
        let firstSession = presenter.sessions.last!
        firstSession.didEarnReward()
        firstSession.didEarnReward()
        firstSession.didDismiss()
        firstSession.didDismiss()
        firstSession.didFail()
        XCTAssertEqual(first, [true])
        XCTAssertEqual(manager.rewardedVideosWatched, 1)
        manager.watchRewardedVideoForAIPlan { XCTAssertFalse($0) }
        firstSession.didEarnReward()
        XCTAssertEqual(manager.rewardedVideosWatched, 1)
        presenter.sessions.last!.didDismiss()
        XCTAssertEqual(manager.rewardedVideosWatched, 1)
    }

    func testFailedVideoPreservesAlreadyEarnedProgress() {
        completeVideo()
        presenter.shouldPresent = false
        manager.watchRewardedVideoForAIPlan { XCTAssertFalse($0) }
        manager.watchRewardedVideoForAIPlan { XCTAssertFalse($0) }
        XCTAssertEqual(manager.rewardedVideosWatched, 1)
        XCTAssertFalse(manager.isAIPlanUnlockedForFree)
    }

    func testProBypassesAdsWithoutFabricatingWatchedVideos() {
        let proManager = AdManager(rewardedPresenter: presenter, proProvider: { true })
        proManager.watchRewardedVideoForAIPlan { XCTAssertTrue($0) }
        XCTAssertEqual(presenter.presentationCount, 0)
        XCTAssertEqual(proManager.rewardedVideosWatched, 0)
        XCTAssertTrue(proManager.isPro)
    }
}

/*
  Production ad-unit configuration must stay separate from Debug test units.
  An unavailable rewarded unit never removes the two-video requirement.
*/
@MainActor
final class AdUnitConfigurationTests: XCTestCase {

    /// Der Banner trägt die echte Kennung aus der Info.plist.
    func testBannerBlockIstEingetragen() {
        let configured = Bundle.main.object(forInfoDictionaryKey: "KWAdUnitBanner") as? String
        XCTAssertEqual(configured, "ca-app-pub-8043832549817924/4597977635")
    }

    func testVollbildBlockIstEingetragen() {
        let configured = Bundle.main.object(forInfoDictionaryKey: "KWAdUnitInterstitial") as? String
        XCTAssertEqual(configured, "ca-app-pub-8043832549817924/7754449009")
    }

    /// Die App-ID ist die echte, nicht mehr Googles Test-ID.
    func testDieAppKennungIstDieEchte() {
        let appId = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String
        XCTAssertEqual(appId, "ca-app-pub-8043832549817924~5833210284")
        XCTAssertFalse(
            (appId ?? "").hasPrefix("ca-app-pub-3940256099942544"),
            "Googles Test-ID gehört nicht in eine ausgelieferte App"
        )
    }

    func testBelohnterBlockIstEingetragen() {
        let configured = Bundle.main.object(forInfoDictionaryKey: "KWAdUnitRewarded") as? String
        XCTAssertEqual(configured, "ca-app-pub-8043832549817924/7639818809")
    }

    /// Missing configuration cannot silently unlock a free AI plan.
    func testMissingAdUnitNeverReducesTheRequiredVideoCount() {
        XCTAssertEqual(AdManager.shared.requiredRewardedVideos, 2)
        AdManager.shared.consumeAIPlanReward()
        XCTAssertFalse(AdManager.shared.isAIPlanUnlockedForFree)
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
