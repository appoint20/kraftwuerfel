import SwiftUI

@main
struct KraftwuerfelApp: App {
    init() {
        // Force dark mode appearance across navigation bars and UI elements
        UIView.appearance().overrideUserInterfaceStyle = .dark
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
                .background(Theme.bg.ignoresSafeArea())
        }
    }
}
