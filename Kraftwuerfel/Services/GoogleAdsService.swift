import AppTrackingTransparency
import Foundation
import GoogleMobileAds
import SwiftUI
import UserMessagingPlatform

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
public final class GoogleAdsService: NSObject, ObservableObject {

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
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"
    }

    private var rewardedUnitId: String {
        Bundle.main.object(forInfoDictionaryKey: "KWAdUnitRewarded") as? String ?? TestUnit.rewarded
    }

    private var interstitialUnitId: String {
        Bundle.main.object(forInfoDictionaryKey: "KWAdUnitInterstitial") as? String ?? TestUnit.interstitial
    }

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

    private var rewardedAd: GADRewardedAd?
    private var interstitialAd: GADInterstitialAd?
    private var isStarting = false

    /// Wird nach einem belohnten Video aufgerufen — aber nur, wenn der Nutzer
    /// es wirklich zu Ende gesehen hat.
    private var pendingReward: (() -> Void)?

    private override init() { super.init() }

    // MARK: - Start

    public func startIfNeeded() async {
        guard Self.isConfigured, !isReady, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }

        await requestConsent()
        await requestTrackingAuthorization()

        _ = await GADMobileAds.sharedInstance().start()
        isReady = true

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
            UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { [weak self] _ in
                guard let self else { return continuation.resume() }
                Task { @MainActor in
                    if let root = Self.topViewController() {
                        UMPConsentForm.loadAndPresentIfRequired(from: root) { _ in
                            self.hasConsent = UMPConsentInformation.sharedInstance.canRequestAds
                            continuation.resume()
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
        guard isReady, rewardedAd == nil else { return }
        rewardedAd = try? await GADRewardedAd.load(withAdUnitID: rewardedUnitId, request: GADRequest())
    }

    private func loadInterstitial() async {
        guard isReady, interstitialAd == nil else { return }
        interstitialAd = try? await GADInterstitialAd.load(withAdUnitID: interstitialUnitId, request: GADRequest())
    }

    // MARK: - Zeigen

    public var isRewardedReady: Bool { rewardedAd != nil }
    public var isInterstitialReady: Bool { interstitialAd != nil }

    /*
      Belohntes Video. `onReward` läuft NUR, wenn Google die Belohnung
      bestätigt — also wenn das Video zu Ende gesehen wurde. Wer wegtippt,
      bekommt nichts; sonst wäre die Schranke keine.
    */
    @discardableResult
    public func showRewarded(onReward: @escaping () -> Void) -> Bool {
        guard let ad = rewardedAd, let root = Self.topViewController() else { return false }

        pendingReward = onReward
        ad.fullScreenContentDelegate = self
        ad.present(fromRootViewController: root) { [weak self] in
            guard let self else { return }
            let reward = self.pendingReward
            self.pendingReward = nil
            reward?()
        }
        rewardedAd = nil
        Task { await loadRewarded() }
        return true
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
            pendingReward = nil
            await preload()
        }
    }

    public nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in await preload() }
    }
}
