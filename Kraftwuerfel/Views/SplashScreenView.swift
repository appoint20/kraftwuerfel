import SwiftUI

/*
  Splash- und Ladebildschirm beim App-Start.
  Zeigt das App-Logo und den App-Namen, während initiale API-Aufrufe
  (Warm-up, Katalog-Aktualisierung, StoreKit-Initialisierung) vorgeladen werden.
*/
public struct SplashScreenView: View {
    @ObservedObject private var i18n = I18n.shared
    public var onFinished: () -> Void

    @State private var isPulsing = false
    @State private var progress: CGFloat = 0.0

    public init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    public var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                /*
                  Die Würfel aus Dice.json — ohne Kachel darunter. Vorher lag
                  hier ein mintgrünes Quadrat mit dem Logo; die Animation auf
                  eine Fläche zu setzen hätte den Eindruck zerstört, dass die
                  Würfel aus dem Hintergrund der App steigen.
                */
                DiceLoaderView(size: 160)
                    .padding(.bottom, 6)

                // App-Name und Untertitel
                VStack(spacing: 6) {
                    Text("KRAFTWÜRFEL")
                        .font(KraftFont.bebas(36))
                        .tracking(2.5)
                        .foregroundColor(Theme.text)

                    Text(i18n.t("app.subtitle"))
                        .font(KraftFont.inter(13.5, .medium))
                        .foregroundColor(Theme.muted)
                        .tracking(0.5)
                }

                Spacer()

                // Dezenter Ladebalken unten
                VStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.surface2)
                            .frame(width: 160, height: 3)

                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: max(160 * progress, 12), height: 3)
                    }
                }
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
            withAnimation(.easeOut(duration: 1.2)) {
                progress = 1.0
            }
        }
        .task {
            // Paralleles Vorladen der Initial-Daten
            async let warmUp: Void = Task { KraftAPI.shared.warmUp() }.value
            async let refreshExercises: Void = ExerciseDatabase.refreshFromAPI()
            async let fetchStoreKit: Void = StoreKitManager.shared.fetchProducts()
            async let refreshStoreKit: Void = StoreKitManager.shared.refreshEntitlements()
            async let minDelay: Void = {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            }()

            _ = await (warmUp, refreshExercises, fetchStoreKit, refreshStoreKit, minDelay)

            withAnimation(.easeInOut(duration: 0.35)) {
                onFinished()
            }
        }
    }
}
