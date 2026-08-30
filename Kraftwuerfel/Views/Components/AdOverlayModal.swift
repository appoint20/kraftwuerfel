import SwiftUI

/*
  AdOverlayModal — Vollbild-Anzeige für Rewarded Videos & Interstitial Ads.
  Zeigt Countdown, Belohnung und Sponsor-Branding.
*/
public struct AdOverlayModal: View {
    @ObservedObject private var adManager = AdManager.shared
    @ObservedObject private var i18n = I18n.shared

    public init() {}

    public var body: some View {
        if AdManager.adsEnabled && adManager.isShowingAdModal {
            ZStack {
                Color.black.opacity(0.88).ignoresSafeArea()

                VStack(spacing: 24) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "play.rectangle.fill")
                                .foregroundColor(Theme.accent)
                            Text("SPONSOR AD")
                                .font(KraftFont.mono(11, .bold))
                                .foregroundColor(Theme.accent)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.accentDim)
                        .cornerRadius(8)

                        Spacer()

                        Text("\(adManager.adCountdown)s")
                            .font(KraftFont.mono(14, .bold))
                            .foregroundColor(Theme.text)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Circle().fill(Theme.surface))
                    }

                    Spacer()

                    VStack(spacing: 14) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.accent)
                            .shadow(color: Theme.accent.opacity(0.4), radius: 10)

                        Text(adManager.adModalTitle)
                            .font(KraftFont.bebas(26)).tracking(1.2)
                            .foregroundColor(Theme.text)
                            .multilineTextAlignment(.center)

                        Text(adManager.adModalSubtitle)
                            .font(KraftFont.inter(13, .medium))
                            .foregroundColor(Theme.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        ProgressView(value: Double(5 - adManager.adCountdown), total: 5.0)
                            .tint(Theme.accent)
                            .frame(maxWidth: 220)
                            .padding(.top, 8)
                    }

                    Spacer()

                    Text(i18n.lang == "en" ? "Ad will close automatically" : "Werbung schließt automatisch")
                        .font(KraftFont.mono(11, .medium))
                        .foregroundColor(Theme.muted.opacity(0.7))
                }
                .padding(24)
            }
            .transition(.opacity)
            .zIndex(999)
        }
    }
}
