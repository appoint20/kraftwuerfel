import AppTrackingTransparency
import Foundation
import GoogleMobileAds
import SwiftUI
import UserMessagingPlatform

/// SDK reward and full-screen dismissal are separate events. Neither a tap,
/// a failed presentation nor a dismissal alone completes a rewarded video.
@MainActor
final class RewardedAdCompletion {
    private var completion: ((Bool) -> Void)?
    private var earnedReward = false

    init(completion: @escaping (Bool) -> Void) { self.completion = completion }
    func didEarnReward() { if completion != nil { earnedReward = true } }
    func didDismiss() { finish(earnedReward) }
    func didFail() { finish(false) }

    private func finish(_ completed: Bool) {
        let callback = completion
        completion = nil
        callback?(completed)
    }
}

/*
  Google AdMob — echte Werbung statt Platzhalter.

  Was hier vorher stand, war keine Werbung: eine eigene Ansicht mit der
  Aufschrift „SPONSOR AD" und einem Zähler, hinter dem nichts steckte. Für
  die App-Prüfung ist das Platzhalterinhalt (Richtlinie 2.1) und ein sicherer
  Ablehnungsgrund — erschwerend, weil beim KI-Coach eine Funktion hinter dem
  Ansehen dieser Platzhalter freigeschaltet wurde.

  Die Reihenfolge beim Start ist nicht beliebig, sie ist rechtlich
  vorgegeben:

    1. UMP-Zustimmung einholen (DSGVO/TCF). Erst danach darf überhaupt
       etwas geladen werden.
    2. ATT-Abfrage (Apple). Ohne sie gibt es nur nicht-personalisierte
       Werbung — das ist erlaubt, bringt aber weniger.
    3. SDK starten und den ersten Vorrat laden.

  Wer 2 vor 1 stellt, fragt nach dem Tracking, bevor der Nutzer der
  Datenverarbeitung überhaupt zugestimmt hat.
*/
@MainActor
public final class GoogleAdsService: NSObject, ObservableObject, RewardedAdPresenting {

    public static let shared = GoogleAdsService()

    // MARK: - Anzeigenblöcke

    /*
      Die Test-IDs von Google sind der VORGABEWERT, nicht die echten.

      Das ist Absicht: Mit echten IDs im Entwicklungsbuild erzeugt jeder
      Testlauf ungültige Impressionen, und Google sperrt dafür Konten. Die
      echten IDs kommen aus der Info.plist und werden erst beim Ausliefern
      gesetzt — bis dahin läuft alles gegen Googles Testinventar, das sich
      identisch verhält.
    */
    private enum TestUnit {
        static let rewarded = "ca-app-pub-3940256099942544/1712485313"
        /// Googles Testblock für Rewarded Interstitial — anderes Format,
        /// andere Kennung.
        static let rewardedInterstitial = "ca-app-pub-3940256099942544/6978759866"
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"
        static let banner = "ca-app-pub-3940256099942544/2934735716"
    }

    private static func configuredUnit(_ key: String) -> String? {
        let value = ((Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        #if !DEBUG
        guard !value.hasPrefix("ca-app-pub-3940256099942544") else { return nil }
        #endif
        return value
    }

    /*
      Der belohnte Block ist eine Rewarded INTERSTITIAL, keine klassische
      Rewarded-Anzeige — so ist er in der AdMob-Konsole angelegt.

      Der Unterschied ist nicht kosmetisch: `GADRewardedAd.load` lehnt eine
      Rewarded-Interstitial-Kennung ab, weil das Format nicht passt. Geladen
      wird deshalb über `GADRewardedInterstitialAd`.

      Ohne echte Kennung liefert Release keine Anzeige. Das zählt nicht als
      angesehenes Video. Debug verwendet ausschließlich Googles Testinventar.
    */
    public static var rewardedUnitId: String? {
        #if DEBUG
        return TestUnit.rewardedInterstitial
        #else
        return configuredUnit("KWAdUnitRewarded")
        #endif
    }

    private static var interstitialUnitId: String? {
        #if DEBUG
        return TestUnit.interstitial
        #else
        return configuredUnit("KWAdUnitInterstitial")
        #endif
    }

    /// Der Banner unten am Bildschirm für Gratis-Nutzer.
    public static var bannerUnitId: String? {
        #if DEBUG
        return TestUnit.banner
        #else
        return configuredUnit("KWAdUnitBanner")
        #endif
    }

    /// Ob der KI-Coach überhaupt Videos verlangen kann.
    public static var hasRewardedUnit: Bool { rewardedUnitId != nil }

    /// Googles öffentliche Test-App-ID. Steht sie im Release-Build, ist die
    /// echte schlicht vergessen worden.
    private static let testAppId = "ca-app-pub-3940256099942544~1458002511"

    /*
      Ohne App-ID in der Info.plist startet das SDK gar nicht erst — und im
      Release-Build zählt Googles Test-ID ausdrücklich NICHT als eingerichtet.

      Ein ausgeliefertes Programm mit Test-ID zeigt Anzeigen mit der
      Aufschrift „Test Ad", bringt keinen Cent und verstößt gegen Googles
      Richtlinien. Das ist genau die Sorte Fehler, die niemandem auffällt,
      weil in der Entwicklung alles funktioniert: Dort IST die Test-ID die
      richtige.

      Lieber gar keine Werbung ausliefern als eine, die nichts einbringt und
      das AdMob-Konto gefährdet. Im Debug-Build bleibt die Test-ID gültig,
      sonst ließe sich die Werbung nie ausprobieren.
    */
    public static var isConfigured: Bool {
        let id = (Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String) ?? ""
        guard !id.isEmpty else { return false }
        #if DEBUG
        return true
        #else
        return id != testAppId
        #endif
    }

    // MARK: - Zustand

    @Published public private(set) var isReady = false
    @Published public private(set) var hasConsent = false

    private var rewardedAd: GADRewardedInterstitialAd?
    private var interstitialAd: GADInterstitialAd?
    private var isStarting = false
    private var isLoadingRewarded = false
    private var presentedRewardedAd: GADRewardedInterstitialAd?

    /// Wird nach einem belohnten Video aufgerufen — aber nur, wenn der Nutzer
    /// es wirklich zu Ende gesehen hat.
    private var pendingReward: RewardedAdCompletion?
    var isRewardedConfigured: Bool { Self.isConfigured && Self.hasRewardedUnit }

    private override init() { super.init() }

    // MARK: - Start

    public func startIfNeeded() async {
        guard Self.isConfigured, !isStarting else { return }
        if isReady && hasConsent { await preload(); return }
        isStarting = true
        defer { isStarting = false }

        if !hasConsent { await requestConsent() }
        guard hasConsent else {
            NSLog("[Ads] Keine Werbung: UMP canRequestAds = false (Zustimmung fehlt oder keine Mitteilung in AdMob veröffentlicht)")
            return
        }
        if !isReady {
            await requestTrackingAuthorization()
            _ = await GADMobileAds.sharedInstance().start()
            isReady = true
        }

        await preload()
    }

    /*
      Die Zustimmung nach DSGVO über Googles User Messaging Platform.

      Ohne sie darf in der EU keine personalisierte Werbung ausgeliefert
      werden — und ohne Formular auch keine nicht-personalisierte, wenn
      Google für die Region eines verlangt.
    */
    private func requestConsent() async {
        let parameters = UMPRequestParameters()
        parameters.tagForUnderAgeOfConsent = false

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { [weak self] error in
                if let error {
                    // Häufigste Ursache: In AdMob ist unter „Datenschutz & Mitteilungen"
                    // keine DSGVO-Mitteilung veröffentlicht. Dann bleibt canRequestAds
                    // in der EU false und es wird KEINE Anzeige geladen.
                    NSLog("[Ads] UMP-Zustimmung konnte nicht abgefragt werden: %@", error.localizedDescription)
                }
                guard let self else { return continuation.resume() }
                Task { @MainActor in
                    if let root = Self.topViewController() {
                        UMPConsentForm.loadAndPresentIfRequired(from: root) { _ in
                            Task { @MainActor in
                                self.hasConsent = UMPConsentInformation.sharedInstance.canRequestAds
                                continuation.resume()
                            }
                        }
                    } else {
                        self.hasConsent = UMPConsentInformation.sharedInstance.canRequestAds
                        continuation.resume()
                    }
                }
            }
        }
    }

    /*
      Apples Tracking-Abfrage. Sie kommt NACH der UMP-Zustimmung und erst,
      wenn die App im Vordergrund ist — sonst zeigt iOS das Blatt nicht und
      der Status bleibt für immer „notDetermined".
    */
    private func requestTrackingAuthorization() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    // MARK: - Nachladen

    public func preload() async {
        await loadRewarded()
        await loadInterstitial()
    }

    private func loadRewarded() async {
        guard isReady, hasConsent, !isLoadingRewarded,
              rewardedAd == nil, presentedRewardedAd == nil,
              let unit = Self.rewardedUnitId else { return }
        isLoadingRewarded = true
        defer { isLoadingRewarded = false }
        rewardedAd = try? await GADRewardedInterstitialAd.load(withAdUnitID: unit, request: GADRequest())
    }

    private func loadInterstitial() async {
        guard isReady, hasConsent, interstitialAd == nil, let unit = Self.interstitialUnitId else { return }
        interstitialAd = try? await GADInterstitialAd.load(withAdUnitID: unit, request: GADRequest())
    }

    // MARK: - Zeigen

    public var isRewardedReady: Bool { rewardedAd != nil }
    public var isInterstitialReady: Bool { interstitialAd != nil }

    /*
      `onCompletion(true)` requires Google's earned-reward event and the
      subsequent dismissal. Closing early or presentation failure returns
      false; merely requesting an unavailable ad earns nothing.

      Google verlangt für Rewarded Interstitials einen Hinweis VOR der
      Anzeige. Den liefert die Aufruferseite: Der KI-Coach zeigt eine Karte
      mit „Video ansehen" und dem Fortschritt, angetippt wird also bewusst.
    */
    @discardableResult
    public func showRewarded(onCompletion: @escaping (Bool) -> Void) -> Bool {
        guard isRewardedConfigured, hasConsent, presentedRewardedAd == nil,
              let ad = rewardedAd, let root = Self.topViewController() else {
            Task {
                if !isReady || !hasConsent { await startIfNeeded() }
                else { await loadRewarded() }
            }
            return false
        }

        let completion = RewardedAdCompletion(completion: onCompletion)
        pendingReward = completion
        presentedRewardedAd = ad
        rewardedAd = nil
        ad.fullScreenContentDelegate = self
        ad.present(fromRootViewController: root) { [weak completion] in
            completion?.didEarnReward()
        }
        return true
    }

    private func finishRewardedPresentation(_ ad: GADFullScreenPresentingAd, failed: Bool) {
        guard let presentedRewardedAd, (ad as AnyObject) === presentedRewardedAd else { return }
        let completion = pendingReward
        pendingReward = nil
        self.presentedRewardedAd = nil
        if failed { completion?.didFail() }
        else { completion?.didDismiss() }
    }

    @discardableResult
    public func showInterstitial() -> Bool {
        guard let ad = interstitialAd, let root = Self.topViewController() else { return false }
        ad.fullScreenContentDelegate = self
        ad.present(fromRootViewController: root)
        interstitialAd = nil
        Task { await loadInterstitial() }
        return true
    }

    // MARK: - Wurzelansicht

    /*
      AdMob braucht einen UIViewController zum Einblenden. In einer reinen
      SwiftUI-App gibt es keinen offensichtlichen — deshalb der Weg über die
      aktive Szene bis zum obersten dargestellten Controller. Ohne das
      „oberste" würde die Werbung hinter einem offenen Blatt landen und
      niemals erscheinen.
    */
    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

extension GoogleAdsService: GADFullScreenContentDelegate {

    /// Kommt die Werbung nicht zustande, darf das Training nicht hängen —
    /// nachladen und weiter.
    public nonisolated func ad(
        _ ad: GADFullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        Task { @MainActor in
            finishRewardedPresentation(ad, failed: true)
            await preload()
        }
    }

    public nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            finishRewardedPresentation(ad, failed: false)
            await preload()
        }
    }
}


/*
  Der echte AdMob-Banner.

  Hier stand eine selbstgebaute Zeile mit der Aufschrift „Anzeige · Trainiere
  smarter mit Kraftwuerfel" — also eine nachgebaute Werbung ohne
  Werbetreibenden dahinter. Das ist Platzhalterinhalt
  (App-Store-Richtlinie 2.1) und wäre mit eingeschalteter Werbung tatsächlich
  ausgeliefert worden.

  Adaptiv statt fester 320×50: Der Banner nimmt die Breite des Geräts und
  bestimmt daraus die Höhe, die Google für diese Breite empfiehlt. Ein fester
  Banner sieht auf einem großen Telefon verloren aus.
*/
public struct AdMobBanner: UIViewRepresentable {
    private let unitId: String
    private let width: CGFloat
    private let onLoadStateChange: (Bool) -> Void

    public init(unitId: String, width: CGFloat, onLoadStateChange: @escaping (Bool) -> Void = { _ in }) {
        self.unitId = unitId
        self.width = width
        self.onLoadStateChange = onLoadStateChange
    }

    public func makeCoordinator() -> Coordinator { Coordinator(onLoadStateChange: onLoadStateChange) }

    /*
      Der Banner meldet, ob er wirklich eine Anzeige bekommen hat. Vorher
      wurde der Platz immer reserviert — kam keine Anzeige (kein Fill, keine
      Zustimmung, Konto noch nicht freigegeben), blieb ein leerer Streifen
      stehen, der in der Live-App wie ein Platzhalter aussah.
    */
    public final class Coordinator: NSObject, GADBannerViewDelegate {
        let onLoadStateChange: (Bool) -> Void
        init(onLoadStateChange: @escaping (Bool) -> Void) { self.onLoadStateChange = onLoadStateChange }

        public func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            onLoadStateChange(true)
        }

        public func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            // Sichtbar in der Konsole (Xcode / Console.app), auch im Release-Build.
            NSLog("[Ads] Banner %@ lieferte keine Anzeige: %@", bannerView.adUnitID ?? "-", error.localizedDescription)
            onLoadStateChange(false)
        }
    }

    public func makeUIView(context: Context) -> GADBannerView {
        let size = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(max(width, 1))
        let banner = GADBannerView(adSize: size)
        banner.adUnitID = unitId
        banner.delegate = context.coordinator
        banner.rootViewController = GoogleAdsService.topViewController()
        banner.load(GADRequest())
        return banner
    }

    public func updateUIView(_ banner: GADBannerView, context: Context) {
        // Die Wurzelansicht kann sich ändern (Blatt auf, Blatt zu).
        if banner.rootViewController == nil {
            banner.rootViewController = GoogleAdsService.topViewController()
        }
    }

    /// Die von Google empfohlene Höhe für diese Breite.
    public static func height(forWidth width: CGFloat) -> CGFloat {
        GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(max(width, 1)).size.height
    }
}
