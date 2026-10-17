import Foundation
import SwiftUI
import Combine

@MainActor
protocol RewardedAdPresenting {
    var isRewardedConfigured: Bool { get }
    /// Completion is true only after an SDK-earned reward and dismissal.
    func showRewarded(onCompletion: @escaping (Bool) -> Void) -> Bool
}

/*
  AdManager — Intelligente Werbelogik für Free-User & Schutz für Pro-User.

  Features:
  1. KI-Coach: zwei vollständig angesehene Videos für einen kostenlosen Plan.
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

    /// Ordinary ads require a configured SDK. The AI reward requirement
    /// stays at two even when configuration or inventory is unavailable.
    public static var adsEnabled: Bool { GoogleAdsService.isConfigured }

    // An unavailable ad must not become a completed video.
    public let requiredRewardedVideos = 2

    // MARK: - Zustand
    @Published public private(set) var rewardedVideosWatched: Int = 0
    @Published public private(set) var isRewardedVideoInProgress = false
    @Published public private(set) var rewardedVideoFailure: RewardedVideoFailure?
    public enum RewardedVideoFailure { case unavailable, incomplete }
    @Published public var isShowingAdModal: Bool = false
    @Published public var adModalTitle: String = ""
    @Published public var adModalSubtitle: String = ""
    @Published public var adCountdown: Int = 5
    @Published public var isAdPlaying: Bool = false

    private var lastInterstitialTime: Date = Date.distantPast
    private let interstitialCooldownSeconds: TimeInterval = 180 // 3 Minuten Cooldown
    private let rewardedPresenter: RewardedAdPresenting
    private let proProvider: () -> Bool
    private var activeRewardRequest: UUID?

    init(rewardedPresenter: RewardedAdPresenting? = nil, proProvider: (() -> Bool)? = nil) {
        self.rewardedPresenter = rewardedPresenter ?? GoogleAdsService.shared
        self.proProvider = proProvider ?? { StoreKitManager.shared.isProUnlocked }
    }

    public func resetCooldown() {
        lastInterstitialTime = Date.distantPast
    }

    public var isAIPlanUnlockedForFree: Bool {
        rewardedVideosWatched >= requiredRewardedVideos
    }

    public var isPro: Bool {
        proProvider()
    }

    // MARK: - Rewarded Video für KI-Plan

    public func watchRewardedVideoForAIPlan(onCompleted: @escaping (Bool) -> Void) {
        guard !isPro else {
            onCompleted(true)
            return
        }
        watchRewarded { [weak self] completed in
            if completed, let self {
                self.rewardedVideosWatched = min(self.requiredRewardedVideos, self.rewardedVideosWatched + 1)
            }
            onCompleted(completed)
        }
    }

    private func watchRewarded(onCompleted: @escaping (Bool) -> Void) {
        guard !isRewardedVideoInProgress else { onCompleted(false); return }
        rewardedVideoFailure = nil
        guard rewardedPresenter.isRewardedConfigured else {
            rewardedVideoFailure = .unavailable
            onCompleted(false)
            return
        }
        let request = UUID()
        activeRewardRequest = request
        isRewardedVideoInProgress = true
        let shown = rewardedPresenter.showRewarded { [weak self] completed in
            guard let self, self.activeRewardRequest == request else { return }
            self.activeRewardRequest = nil
            self.isRewardedVideoInProgress = false
            self.rewardedVideoFailure = completed ? nil : .incomplete
            onCompleted(completed)
        }
        if !shown, activeRewardRequest == request {
            activeRewardRequest = nil
            isRewardedVideoInProgress = false
            rewardedVideoFailure = .unavailable
            onCompleted(false)
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
        guard !isPro else {
            onCompleted(true)
            return
        }

        watchRewarded { [weak self] completed in
            if completed { self?.historyUnlockedUntil = Date().addingTimeInterval(86400) }
            onCompleted(completed)
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

    /// Optional interstitials must not block a workout or music playback.
    /// Rewarded unlocks use the separate, SDK-confirmed completion path.
    private func showRealAd(onDone: (() -> Void)?) -> Bool {
        let ads = GoogleAdsService.shared
        let shown = ads.showInterstitial()
        if shown { onDone?() }
        return shown
    }

    private func startAdPlayback(
        title: String,
        subtitle: String,
        duration: Int,
        onDone: (() -> Void)?
    ) {
        // Letzte Sperre: auch ein vergessener Aufruf zeigt nichts an.
        guard Self.adsEnabled else {
            onDone?()
            return
        }

        // An unavailable interstitial can be skipped. It grants no reward.
        if !showRealAd(onDone: onDone) {
            onDone?()
        }
    }

    public func skipAd() {
        activeAdTimer?.invalidate()
        activeAdTimer = nil
        isAdPlaying = false
        isShowingAdModal = false
        // Closing UI never earns a reward. Only the SDK lifecycle can do so.
    }
}
