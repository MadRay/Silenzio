import SwiftUI

enum SilenzioTheme {
    // MARK: - Semantic accents (Wonder designs)

    static let liveGreen = Color(light: Color(hex: 0x34C759), dark: Color(hex: 0x32D74B))
    static let liveGreenSoft = Color(light: Color(hex: 0x34C759).opacity(0.12), dark: Color(hex: 0x32D74B).opacity(0.12))
    static let liveGreenBorder = Color(light: Color(hex: 0x34C759).opacity(0.45), dark: Color(hex: 0x32D74B).opacity(0.28))
    static let liveGreenText = Color(light: Color(hex: 0x248A3D), dark: Color(hex: 0x5FDD7F))
    static let liveGreenIcon = Color(light: .white, dark: Color(hex: 0x0A2410))

    static let muteRed = Color(hex: 0xFF453A)
    static let muteRedSoft = Color(hex: 0xFF453A).opacity(0.16)
    static let muteRedBorder = Color(hex: 0xFF453A).opacity(0.40)
    static let muteRedText = Color(hex: 0xFF8A80)
    static let muteBadgeText = Color(hex: 0xFF6961)

    static let accentBlue = Color(light: Color(hex: 0x007AFF), dark: Color(hex: 0x0A84FF))

    static let popoverBackground = Color(light: Color(hex: 0xF5F5F7).opacity(0.85), dark: Color(hex: 0x1C1C1E).opacity(0.95))
    static let preferencesBackground = Color(light: Color(hex: 0xECECEC).opacity(0.95), dark: Color(hex: 0x1E1E1E).opacity(0.97))
    static let surface = Color(light: .white, dark: Color.white.opacity(0.06))
    static let surfaceElevated = Color(light: Color.black.opacity(0.04), dark: Color.white.opacity(0.06))
    static let border = Color(light: Color.black.opacity(0.08), dark: Color.white.opacity(0.10))
    static let separator = Color(light: Color.black.opacity(0.08), dark: Color.white.opacity(0.08))
    static let secondaryLabel = Color(light: Color(hex: 0x8E8E93), dark: Color(hex: 0x98989D))
    static let tertiaryLabel = Color(light: Color(hex: 0x8E8E93), dark: Color(hex: 0x6E6E73))
    static let primaryLabel = Color(light: Color(hex: 0x1C1C1E), dark: .white)
    static let meterIdle = Color(light: Color(hex: 0xD1D1D6), dark: Color(hex: 0x3A3A3C))
    static let meterFlat = Color(light: Color(hex: 0xC7C7CC), dark: Color(hex: 0x2C2C2E))
    static let chipBackground = Color(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.08))
    static let chipBorder = Color(light: Color.black.opacity(0.10), dark: Color.white.opacity(0.10))
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(dark)
                : NSColor(light)
        }))
    }
}
