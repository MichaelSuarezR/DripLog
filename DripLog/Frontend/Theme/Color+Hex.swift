import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

enum AppColor {
    static let cream = Color(hex: 0xF2EEE9)
    static let loadingBlue = Color(hex: 0x4597B7)
    static let lavender = Color(hex: 0x8B8FBF)
    static let accentOrange = Color(hex: 0xD94A2F)
    static let placeholderBlue = Color(hex: 0x96ADD6)
    static let aiChipTint = Color(hex: 0xE9A497)
}

enum AppFont {
    static func logo(size: CGFloat) -> Font {
        .custom("GoodKitty", size: size)
    }

    static func uiBold(size: CGFloat) -> Font {
        if let name = firstAvailableFont(baseNames: ["Coolvetica-Bold", "CoolveticaRg-Bold"], size: size) {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: .bold)
    }

    static func uiRegular(size: CGFloat) -> Font {
        if let name = firstAvailableFont(baseNames: ["CoolveticaBk-Regular", "Coolvetica-Regular", "CoolveticaRg-Regular"], size: size) {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: .regular)
    }

    static func uiLight(size: CGFloat) -> Font {
        if let name = firstAvailableFont(baseNames: ["CoolveticaRg-Light", "Coolvetica-Light", "CoolveticaBk-Regular"], size: size) {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: .light)
    }

    private static func firstAvailableFont(baseNames: [String], size: CGFloat) -> String? {
        for base in baseNames where UIFont(name: base, size: size) != nil {
            return base
        }
        return nil
    }
}

enum AppAnimation {
    static let standardSpring = Animation.spring(response: 0.4, dampingFraction: 0.82)
    static let accordionSpring = Animation.spring(response: 0.35, dampingFraction: 0.85)
}
