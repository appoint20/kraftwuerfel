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
    @ObservedObject private var ads = GoogleAdsService.shared
    @State private var showPro = false
    @State private var bannerLoaded = false

    public init() {}

    /*
      Feste Breite statt GeometryReader: Beim ersten Layout-Durchlauf kann
      GeometryReader die Breite 0 melden — der Banner wurde dann mit einer
      ungültigen Größe angefordert und blieb leer. 14+14 Rand, 10 Abstand,
      rund 72 für den „WERBEFREI"-Knopf.
    */
    private var bannerWidth: CGFloat { UIScreen.main.bounds.width - 110 }

    public var body: some View {
        /*
          Der Banner wird erst angelegt, wenn das SDK gestartet ist UND die
          UMP-Zustimmung vorliegt. Vorher wurde er sofort beim Erscheinen
          geladen — vor Zustimmung und SDK-Start — und danach nie wieder.
          Ergebnis in der Live-App: ein leerer Streifen statt Werbung.

          Platz bekommt er erst, wenn Google tatsächlich eine Anzeige
          geliefert hat; bis dahin (oder ohne Fill) ist er 0 Punkte hoch.
        */
        if AdManager.adsEnabled && !storeKit.isProUnlocked,
           ads.isReady, ads.hasConsent,
           let unit = GoogleAdsService.bannerUnitId {
            HStack(spacing: 10) {
                AdMobBanner(unitId: unit, width: bannerWidth) { loaded in
                    withAnimation(.easeOut(duration: 0.2)) { bannerLoaded = loaded }
                }
                .frame(width: bannerWidth, height: AdMobBanner.height(forWidth: bannerWidth))

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
            .padding(.vertical, bannerLoaded ? 6 : 0)
            .padding(.bottom, bannerLoaded ? 2 : 0)
            .frame(height: bannerLoaded ? nil : 0, alignment: .top)
            .opacity(bannerLoaded ? 1 : 0)
            .clipped()
            .sheet(isPresented: $showPro) {
                ProSubscriptionView()
            }
        }
    }
}
