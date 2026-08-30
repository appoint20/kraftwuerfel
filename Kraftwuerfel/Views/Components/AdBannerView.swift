import SwiftUI

/*
  AdBannerView — Diskreter Werbebanner für Free-User mit Upgrade-Option.
  Wird für Pro-User (`isProUnlocked == true`) komplett ausgeblendet.
*/
public struct AdBannerView: View {
    @ObservedObject private var storeKit = StoreKitManager.shared
    @ObservedObject private var i18n = I18n.shared
    @State private var showPro = false

    public init() {}

    public var body: some View {
        if AdManager.adsEnabled && !storeKit.isProUnlocked {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Text("AD")
                        .font(KraftFont.mono(9, .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Theme.muted.opacity(0.3))
                        .foregroundColor(Theme.muted)
                        .cornerRadius(4)

                    Text(i18n.lang == "en" ? "Sponsored · Train smarter with Kraftwuerfel" : "Anzeige · Trainiere smarter mit Kraftwuerfel")
                        .font(KraftFont.inter(11, .medium))
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showPro = true
                }) {
                    Text(i18n.lang == "en" ? "NO ADS" : "WERBEFREI")
                        .font(KraftFont.mono(10, .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.accentDim)
                        .foregroundColor(Theme.accent)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.surface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
            .sheet(isPresented: $showPro) {
                ProSubscriptionView()
            }
        }
    }
}
