import SwiftUI

/*
  DiceThrowOverlay — Home-Challenge Generierungs-Overlay mit Viktor Cubes Lottie Animation.

  Wenn der Fragebogen der Home-Challenge abgeschickt wird, zeigt dieses Overlay
  die native Viktor Cubes Lottie-Animation (60 FPS, rotierende Würfel aus dem
  leuchtenden Bodenportal) zusammen mit den dynamischen Statusstufen, während
  der Server die Challenge und den 7-Tage-Ernährungsplan generiert.
*/

public struct DiceThrowOverlay: View {
    @ObservedObject private var i18n = I18n.shared

    /// Solange `true`, läuft die Generierung weiter.
    public let isLoading: Bool
    /// Wird aufgerufen, sobald die Challenge fertig generiert ist.
    public let onLandingFinished: () -> Void

    @State private var elapsed: Double = 0
    @State private var stageTimer: Timer?
    @State private var isLanding: Bool = false
    @State private var contentOpacity: Double = 0.0

    public init(isLoading: Bool, onLandingFinished: @escaping () -> Void) {
        self.isLoading = isLoading
        self.onLandingFinished = onLandingFinished
    }

    public var body: some View {
        ZStack {
            // Hintergrund: Tiefschwarz mit dezentem, pulsierendem Accent-Glow
            RadialGradient(
                colors: [
                    Theme.accent.opacity(0.14),
                    Theme.bg.opacity(0.98),
                    Color.black.opacity(0.99),
                ],
                center: .center,
                startRadius: 30,
                endRadius: 480
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 20)

                // 1. Hero Lottie Viktor Cubes Animation
                VStack(spacing: 8) {
                    DiceLoaderView(size: 200, tint: Theme.accent, showGlow: true)
                        .scaleEffect(isLanding ? 1.08 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isLanding)
                }

                // 2. Statusblock & Stufen-Fortschritt
                statusBlock
                    .padding(.top, 10)

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 28)
            .opacity(contentOpacity)
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) {
                contentOpacity = 1.0
            }
            startStageClock()
            if !isLoading {
                land()
            }
        }
        .onDisappear {
            stopTimers()
        }
        .onChange(of: isLoading) { stillLoading in
            if !stillLoading {
                land()
            }
        }
    }

    // MARK: - Statusblock & Stufenanzeige

    private var statusBlock: some View {
        VStack(spacing: 14) {
            Text(headline)
                .font(KraftFont.bebas(24))
                .tracking(1.5)
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.center)

            Text(stageText)
                .font(KraftFont.inter(13, .medium))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .id(stageText)
                .transition(.opacity)

            // Fortschrittsbalken
            VStack(spacing: 6) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.surface2)
                        .frame(width: 180, height: 4)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent, Theme.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(18, min(180, CGFloat(elapsed / 18.0) * 180.0)), height: 4)
                        .animation(.linear(duration: 0.5), value: elapsed)
                }
            }
            .padding(.top, 4)
        }
    }

    private var headline: String {
        if isLanding {
            return i18n.lang == "en" ? "YOUR CHALLENGE IS READY!" : "DEINE CHALLENGE STEHT!"
        }
        return i18n.lang == "en" ? "ROLLING YOUR CHALLENGE" : "DEINE CHALLENGE WIRD GEWÜRFELT"
    }

    private var stageText: String {
        let en = i18n.lang == "en"
        if isLanding {
            return en ? "Challenge generated. Opening your plan…" : "Challenge steht. Dein Plan wird geöffnet…"
        }

        if elapsed < 3.5 {
            return en ? "Reading your profile and biometrics…" : "Deine Antworten und Körperdaten werden gelesen…"
        } else if elapsed < 8.0 {
            return en ? "Selecting home exercises that fit your minutes…" : "Home-Übungen für deine Minuten werden gewählt…"
        } else if elapsed < 13.0 {
            return en ? "Configuring sets, reps and progression…" : "Sätze, Wiederholungen und Pausen werden gesetzt…"
        } else if elapsed < 18.0 {
            return en ? "Building your 7-day personalized meal guide…" : "Dein 7-Tage-Ernährungsplan wird berechnet…"
        } else {
            return en ? "Almost there — finalizing your challenge…" : "Gleich geschafft — die Challenge wird finalisiert…"
        }
    }

    // MARK: - Ablauf & Animation

    private func land() {
        guard !isLanding else { return }
        isLanding = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            stopTimers()
            onLandingFinished()
        }
    }

    private func startStageClock() {
        stageTimer?.invalidate()
        elapsed = 0
        stageTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                elapsed += 0.5
            }
        }
    }

    private func stopTimers() {
        stageTimer?.invalidate()
        stageTimer = nil
    }
}
