import SwiftUI

/*
  Der Werbebanner am unteren Rand — für Gratis-Nutzer, für Pro unsichtbar.

  Hier stand bis zuletzt keine Werbung, sondern eine nachgebaute: eine Zeile
  mit „AD" und dem Text „Anzeige · Trainiere smarter mit Kraftwuerfel". Das
  ist Platzhalterinhalt (App-Store-Richtlinie 2.1) und wäre mit
  eingeschalteter Werbung tatsächlich so ausgeliefert worden.

  Jetzt lädt hier ein echter AdMob-Banner. Der Knopf „WERBEFREI" daneben
  bleibt — er ist unsere eigene Oberfläche, keine vorgetäuschte Anzeige, und
  die naheliegendste Stelle, an der jemand über das Abo nachdenkt.
*/
public struct AdBannerView: View {
    @ObservedObject private var storeKit = StoreKitManager.shared
    @ObservedObject private var i18n = I18n.shared
    @State private var showPro = false

    public init() {}

    public var body: some View {
        if AdManager.adsEnabled && !storeKit.isProUnlocked, let unit = GoogleAdsService.bannerUnitId {
            HStack(spacing: 10) {
                /*
                  Die Breite kommt vom Layout, weil die empfohlene Höhe daran
                  hängt. Ohne feste Höhe zieht der Banner die ganze Ansicht
                  auf oder wird abgeschnitten.
                */
                GeometryReader { geo in
                    AdMobBanner(unitId: unit, width: geo.size.width)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(height: AdMobBanner.height(forWidth: UIScreen.main.bounds.width - 76))

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
                .fixedSize()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .padding(.bottom, 2)
            .sheet(isPresented: $showPro) {
                ProSubscriptionView()
            }
        }
    }
}
