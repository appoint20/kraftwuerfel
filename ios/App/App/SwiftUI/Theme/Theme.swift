import SwiftUI

public struct Theme {
    public static let bg = Color(hex: "0D0E10")
    public static let surface = Color(hex: "17181B")
    public static let surface2 = Color(hex: "1F2023")
    public static let border = Color(hex: "2B2D31")
    public static let text = Color(hex: "F2F2EF")
    public static let muted = Color(hex: "8B8D93")
    public static let accent = Color(hex: "26E1BE") // Mint / Cyan
    public static let accentDim = Color(hex: "26E1BE").opacity(0.14)
    public static let orange = Color(hex: "FF6B35")
    public static let red = Color(hex: "EF4444")
    public static let green = Color(hex: "22C55E")
}

extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

public struct KraftCardModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(Theme.surface)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

extension View {
    public func kraftCard() -> some View {
        self.modifier(KraftCardModifier())
    }
}
