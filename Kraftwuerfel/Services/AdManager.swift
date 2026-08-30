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
      AUS, und das muss so bleiben, bis ein echtes Werbenetz eingebunden ist.

      Was dieser Manager anzeigt, ist keine Werbung: `startAdPlayback` blendet
      eine eigene Ansicht mit der Aufschrift „SPONSOR AD“ und einem
      5-Sekunden-Zähler ein, hinter dem nichts steckt — kein SDK, kein
      Inventar, kein Werbetreibender. Für die App-Prüfung ist das
      Platzhalterinhalt (Richtlinie 2.1) und ein sicherer Ablehnungsgrund.
      Beim KI-Coach kommt erschwerend dazu, dass eine Funktion hinter dem
      Ansehen dieser Platzhalter freigeschaltet wurde.

      Solange der Schalter aus ist:
      - Banner und Vollbild-Einblendung zeichnen nichts,
      - alle `trigger…`-Aufrufe kehren sofort zurück,
      - `requiredRewardedVideos` ist 0, die Freischaltung fällt also auf statt
        zu — eine Bezahlschranke, die sich auf dem beworbenen Weg nicht öffnen
        lässt, wäre schlimmer als gar keine.

      Beim Einschalten sind zusätzlich fällig: ATT-Abfrage samt
      NSUserTrackingUsageDescription, NSPrivacyTrackingDomains im
      Datenschutzmanifest, die Werbe-Datentypen in den App-Datenschutzangaben
      und der Satz „Wir setzen keine Werbe-SDKs“ in der Datenschutzerklärung.
    */
    public static let adsEnabled = false

    // MARK: - Konfiguration
    public var requiredRewardedVideos: Int { Self.adsEnabled ? 3 : 0 }

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
            duration: 5
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
            duration: 5
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

    private func startAdPlayback(title: String, subtitle: String, duration: Int, onDone: (() -> Void)?) {
        // Letzte Sperre: auch ein vergessener Aufruf zeigt nichts an.
        guard Self.adsEnabled else {
            onDone?()
            return
        }

        activeAdTimer?.invalidate()
        activeAdTimer = nil

        self.adModalTitle = title
        self.adModalSubtitle = subtitle
        self.adCountdown = duration
        self.isAdPlaying = true
        self.isShowingAdModal = true
        self.onAdCompletedCallback = onDone

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        activeAdTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            Task { @MainActor in
                if self.adCountdown > 1 {
                    self.adCountdown -= 1
                } else {
                    timer.invalidate()
                    self.activeAdTimer = nil
                    self.isAdPlaying = false
                    self.isShowingAdModal = false
                    self.onAdCompletedCallback?()
                    self.onAdCompletedCallback = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
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
