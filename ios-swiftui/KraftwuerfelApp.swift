import SwiftUI

@main
struct KraftwuerfelApp: App {
    @State private var authState = AuthViewModel()
    @State private var healthKit = HealthKitManager.shared
    @State private var watchSync = WatchSyncManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(authState)
                .environment(healthKit)
                .environment(watchSync)
                .preferredColorScheme(.dark)
                .tint(Color.accentEmerald)
        }
    }
}

// MARK: - App Color System
extension Color {
    static let bgDark = Color(red: 0.05, green: 0.055, blue: 0.063) // #0D0E10
    static let surfaceDark = Color(red: 0.078, green: 0.082, blue: 0.094) // #141518
    static let surfaceElevated = Color(red: 0.118, green: 0.122, blue: 0.137) // #1E1F23
    static let borderSubtle = Color(red: 0.173, green: 0.176, blue: 0.192) // #2C2D31
    static let accentEmerald = Color(red: 0.149, green: 0.882, blue: 0.745) // #26E1BE
    static let accentEmeraldDim = Color(red: 0.149, green: 0.882, blue: 0.745).opacity(0.12)
    static let textSecondary = Color(red: 0.53, green: 0.54, blue: 0.58) // #888A94
}
