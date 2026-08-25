import SwiftUI

@main
struct KraftwuerfelApp: App {
    init() {
        // Force dark mode appearance across navigation bars and UI elements
        UIView.appearance().overrideUserInterfaceStyle = .dark

        // Die einzige Stelle, an der KraftAPI und AuthService voneinander
        // wissen: läuft ein Plan-Aufruf auf ein 401, holt sich KraftAPI hier
        // einen frischen Token, statt den Nutzer erneut anzumelden.
        KraftAPI.shared.tokenRefresher = { await AuthService.shared.refreshAccessToken() }
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
                .background(Theme.bg.ignoresSafeArea())
        }
    }
}
