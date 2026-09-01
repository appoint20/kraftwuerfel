import SwiftUI

@main
struct KraftwuerfelApp: App {
    @State private var isShowingSplash = true

    init() {
        // Force dark mode appearance across navigation bars and UI elements
        UIView.appearance().overrideUserInterfaceStyle = .dark

        // Die einzige Stelle, an der KraftAPI und AuthService voneinander
        // wissen: läuft ein Plan-Aufruf auf ein 401, holt sich KraftAPI hier
        // einen frischen Token, statt den Nutzer erneut anzumelden.
        KraftAPI.shared.tokenRefresher = { await AuthService.shared.refreshAccessToken() }

        /*
          Die Audiositzung einmal richtig stellen. Ohne das lief die App auf
          `.soloAmbient` und jeder eigene Ton — Countdown-Ping, „Los!" am
          Pausenende — stoppte die Musik des Nutzers.
        */
        AudioSessionManager.configureForWorkout()

        /*
          Der alte Debug-Schalter lag in den Voreinstellungen und überlebte
          jeden Neustart. Wer ihn einmal an hatte, lief sonst weiter mit
          dauerhaft freigeschaltetem Pro — ohne dass irgendwo stünde, warum.
        */
        UserDefaults.standard.removeObject(forKey: "kraftwuerfel:debugPro")
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .preferredColorScheme(.dark)
                    .background(Theme.bg.ignoresSafeArea())

                if isShowingSplash {
                    SplashScreenView {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            isShowingSplash = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }
}
