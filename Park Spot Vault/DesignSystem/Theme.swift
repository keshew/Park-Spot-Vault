import SwiftUI

extension Color {
    static let vaultBackground = Color(hex: 0x090B11)
    static let vaultSurface = Color(hex: 0x141821)
    static let vaultCard = Color(hex: 0x1B202B)
    static let vaultAccent = Color(hex: 0x56C8FF)
    static let vaultSecondary = Color(hex: 0x72FFD2)
    static let vaultWarning = Color(hex: 0xFFB84D)
    static let vaultDanger = Color(hex: 0xFF6262)
    static let vaultMuted = Color(hex: 0x9CA7B7)

    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension LinearGradient {
    static let vaultAccent = LinearGradient(
        colors: [.vaultAccent, .vaultSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let vaultSecondary = LinearGradient(
        colors: [.vaultSecondary, .vaultAccent.opacity(0.75)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
