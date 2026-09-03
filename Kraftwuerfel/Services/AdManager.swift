import Foundation
import SwiftUI
import Combine

/*
  AdManager — Intelligente Werbelogik für Free-User & Schutz für Pro-User.

  Features:
  1. KI-Coach 3-Video-Unlock: Free-User schauen 3 Videos an, um 1 KI-Plan zu generieren.
  2. Live-Session Exercise Transition Ad: Bei Workouts mit >= 6 Übungen wird beim
     Übergang zur nächsten Übung eine Ad gezeigt.
  3. Würfel-Generator Ad: Dezente Interstitial Ads beim Neugenerieren (mit Cooldown).
  4. Spotify Pre-Roll Ad: Kurze Ad vor dem Starten der Spotify-Playlist.
  5. Banner Ads: Anzeige am Bildschirmrand nur für Free-User.
  6. Automatische 100% Werbefreiheit für Pro-User (`StoreKitManager.shared.isProUnlocked`).
*/
@MainActor
public final class AdManager: ObservableObject {
    public static let shared = AdManager()

    // MARK: - Hauptschalter

    /*
      An, sobald eine AdMob-App-ID in der Info.plist steht.

      Hier stand eine feste `false` — und das war richtig, solange „Werbung"
      eine eigene Ansicht mit der Aufschrift „SPONSOR AD" und einem Zähler
      war, hinter dem nichts steckte. Das ist Platzhalterinhalt
      (App-Store-Richtlinie 2.1) und ein sicherer Ablehnungsgrund; beim
      KI-Coach erschwerend, weil eine Funktion hinter dem Ansehen dieser
      Platzhalter freigeschaltet wurde.

      Jetzt steckt das Google-Mobile-Ads-SDK dahinter (GoogleAdsService), und
      der Schalter fragt schlicht, ob es eingerichtet ist. Fehlt die App-ID,
      bleibt alles wie vorher aus: keine Banner, keine Einblendungen, und
      `requiredRewardedVideos` ist 0 — eine Schranke, die sich auf dem
      beworbenen Weg nicht öffnen lässt, wäre schlimmer als gar keine.
    */
    public static var adsEnabled: Bool { GoogleAdsService.isConfigured }

    // MARK: - Konfiguration
    /*
      Zwei Videos für eine KI-Analyse — aber nur, wenn es überhaupt Videos gibt.

      Zwei Bedingungen, und beide aus demselben Grund: Eine Schranke, die sich
      auf dem beworbenen Weg nicht öffnen lässt, ist schlimmer als gar keine.

      - Ohne eingeschaltetes Werbenetz: 0.
      - Ohne belohnten Anzeigenblock: ebenfalls 0. In der AdMob-Konsole ist
        bisher nur ein Banner und eine Vollbild-Einblendung angelegt; solange
        kein belohnter Block dazukommt, gäbe es nichts anzusehen, und der
        KI-Coach wäre für Gratis-Nutzer verschlossen statt kostenpflichtig.

      Sobald der Block existiert und `KWAdUnitRewarded` in der Info.plist
      steht, greift die Schranke von selbst.
    */
    public var requiredRewardedVideos: Int {
        Self.adsEnabled && GoogleAdsService.hasRewardedUnit ? 2 : 0
    }

    // MARK: - Zustand
    @Published public var rewardedVideosWatched: Int = 0
    @Published public var isShowingAdModal: Bool = false
    @Published public var adModalTitle: String = ""
    @Published public var adModalSubtitle: String = ""
    @Published public var adCountdown: Int = 5
    @Published public var isAdPlaying: Bool = false

    private var lastInterstitialTime: Date = Date.distantPast
    private let interstitialCooldownSeconds: TimeInterval = 180 // 3 Minuten Cooldown
    private var onAdCompletedCallback: (() -> Void)?

    private init() {}

    public func resetCooldown() {
        lastInterstitialTime = Date.distantPast
    }

    public var isAIPlanUnlockedForFree: Bool {
        rewardedVideosWatched >= requiredRewardedVideos
    }

    public var isPro: Bool {
        StoreKitManager.shared.isProUnlocked
    }

    // MARK: - Rewarded Video für KI-Plan

    public func watchRewardedVideoForAIPlan(onCompleted: @escaping (Bool) -> Void) {
        guard Self.adsEnabled else {
            onCompleted(true)
            return
        }
        guard !isPro else {
            onCompleted(true)
            return
        }

        startAdPlayback(
            title: "Sponsor Video (\(rewardedVideosWatched + 1)/\(requiredRewardedVideos))",
            subtitle: "Schau das Video an, um deinen KI-Plan kostenlos freizuschalten.",
            duration: 5,
            // Freischalten nur gegen ein belohntes Video: Nur dort bestätigt
            // Google, dass der Nutzer es wirklich zu Ende gesehen hat.
            isRewarded: true
        ) { [weak self] in
            guard let self else { return }
            self.rewardedVideosWatched = min(self.requiredRewardedVideos, self.rewardedVideosWatched + 1)
            onCompleted(true)
        }
    }

    public func consumeAIPlanReward() {
        rewardedVideosWatched = 0
    }

    // MARK: - Live Workout Transition Ad (>= 6 Übungen)

    public func triggerLiveSessionExerciseTransitionAd(exerciseCount: Int) {
        guard Self.adsEnabled else { return }
        guard !isPro else { return }
        guard exerciseCount >= 6 else { return }

        // Nur alle paar Minuten während der Satzpause einblenden
        let now = Date()
        guard now.timeIntervalSince(lastInterstitialTime) >= 90 else { return }
        lastInterstitialTime = now

        startAdPlayback(
            title: "Satzpause & Sponsor",
            subtitle: "Kurze Werbepause vor der nächsten Übung.",
            duration: 5,
            onDone: nil
        )
    }

    // MARK: - Fortschritt & Progress Analytics Ad

    public func triggerProgressAnalyticsAd() {
        guard Self.adsEnabled else { return }
        guard !isPro else { return }
        let now = Date()
        guard now.timeIntervalSince(lastInterstitialTime) >= interstitialCooldownSeconds else { return }
        lastInterstitialTime = now

        startAdPlayback(
            title: "Fortschritts-Analyse",
            subtitle: "Detaillierte Trainingskurven geladen. Unterstütze Kraftwürfel mit dieser kurzen Einblendung.",
            duration: 5,
            onDone: nil
        )
    }

    // MARK: - History Archive Rewarded Video Unlock (24h)

    @Published public var historyUnlockedUntil: Date?

    public var isHistoryArchiveUnlocked: Bool {
        // Ohne Werbung gibt es nichts anzusehen, wodurch sich das Archiv
        // freischalten liesse — dann ist es offen.
        if !Self.adsEnabled { return true }
        if isPro { return true }
        guard let until = historyUnlockedUntil else { return false }
        return until > Date()
    }

    public func watchRewardedVideoForHistoryArchive(onCompleted: @escaping (Bool) -> Void) {
        guard Self.adsEnabled else {
            onCompleted(true)
            return
        }
        guard !isPro else {
            onCompleted(true)
            return
        }

        startAdPlayback(
            title: "Trainingsarchiv Freischaltung",
            subtitle: "Schau ein kurzes Video an, um dein gesamtes Tagebuch-Archiv für 24h freizuschalten.",
            duration: 5,
            isRewarded: true
        ) { [weak self] in
            guard let self else { return }
            self.historyUnlockedUntil = Date().addingTimeInterval(86400) // 24 Stunden
            onCompleted(true)
        }
    }

    // MARK: - Würfel Generator Ad

    public func triggerDiceGeneratorAd() {
        guard Self.adsEnabled else { return }
        guard !isPro else { return }
        let now = Date()
        guard now.timeIntervalSince(lastInterstitialTime) >= interstitialCooldownSeconds else { return }
        lastInterstitialTime = now

        startAdPlayback(
            title: "Kraftwuerfel Sponsor",
            subtitle: "Unterstütze die Weiterentwicklung mit einer kurzen Einblendung.",
            duration: 5,
            onDone: nil
        )
    }

    // MARK: - Spotify Pre-Roll Ad

    public func triggerSpotifyPreRollAd(onProceed: @escaping () -> Void) {
        guard Self.adsEnabled else {
            onProceed()
            return
        }
        guard !isPro else {
            onProceed()
            return
        }

        startAdPlayback(
            title: "Spotify Musik-Start",
            subtitle: "Deine Playlist startet nach diesem kurzen Clip.",
            duration: 5
        ) {
            onProceed()
        }
    }

    // MARK: - Ad Playback Controller

    private var activeAdTimer: Timer?

    /*
      Zeigt echte Werbung, wenn welche vorliegt.

      `isRewarded` entscheidet über die Art: Für das Freischalten muss es ein
      belohntes Video sein — nur dort bestätigt Google, dass der Nutzer es zu
      Ende gesehen hat. Für Übergänge genügt eine Vollbild-Einblendung.

      Liegt gerade keine Werbung bereit (kein Netz, kein Inventar), läuft
      `onDone` trotzdem. Ein Nutzer, der wegen eines leeren Werbeservers
      nicht weitertrainieren kann, ist der schlechtere Handel.
    */
    private func showRealAd(isRewarded: Bool, onDone: (() -> Void)?) -> Bool {
        let ads = GoogleAdsService.shared
        if isRewarded {
            return ads.showRewarded { onDone?() }
        }
        let shown = ads.showInterstitial()
        if shown { onDone?() }
        return shown
    }

    private func startAdPlayback(
        title: String,
        subtitle: String,
        duration: Int,
        isRewarded: Bool = false,
        onDone: (() -> Void)?
    ) {
        // Letzte Sperre: auch ein vergessener Aufruf zeigt nichts an.
        guard Self.adsEnabled else {
            onDone?()
            return
        }

        /*
          Entweder echte Werbung — oder gar keine.

          Hier stand kurzzeitig ein Rückfall auf die eigene „SPONSOR AD"-
          Ansicht, wenn das SDK nichts bereithielt. Das ist genau der
          Platzhalterinhalt, dessentwegen die Werbung ursprünglich
          abgeschaltet wurde (App-Store-Richtlinie 2.1): eine nachgebaute
          Anzeige ohne Werbetreibenden dahinter, und beim KI-Coach eine
          Funktion, die sich nur darüber öffnen ließ.

          Liegt nichts vor (kein Netz, kein Inventar, Zustimmung abgelehnt),
          bekommt der Nutzer den Vorteil eben umsonst. Das kostet ein paar
          Einblendungen; die Alternative kostet die Zulassung.
        */
        /*
          Entweder echte Werbung — oder gar keine.

          Hier stand die eigene „SPONSOR AD"-Ansicht mit einem Zähler, hinter
          dem nichts steckte. Genau dieser Platzhalterinhalt war der Grund,
          die Werbung ganz abzuschalten (App-Store-Richtlinie 2.1) — eine
          nachgebaute Anzeige ohne Werbetreibenden, und beim KI-Coach eine
          Funktion, die sich nur darüber öffnen ließ. Sie kommt mit dem
          echten SDK nicht zurück.

          Liegt nichts vor (kein Netz, kein Inventar, Zustimmung abgelehnt),
          bekommt der Nutzer den Vorteil eben umsonst. Das kostet ein paar
          Einblendungen; die Alternative kostet die Zulassung.
        */
        if !showRealAd(isRewarded: isRewarded, onDone: onDone) {
            onDone?()
        }
    }

    public func skipAd() {
        activeAdTimer?.invalidate()
        activeAdTimer = nil
        isAdPlaying = false
        isShowingAdModal = false
        onAdCompletedCallback?()
        onAdCompletedCallback = nil
    }
}
