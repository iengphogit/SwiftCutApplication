import SwiftUI
import UIKit

enum AppTheme {
    static let accentRed = Color(red: 210 / 255, green: 61 / 255, blue: 57 / 255)
    static let accentBlue = Color(red: 13 / 255, green: 108 / 255, blue: 242 / 255)
    static let neonLight = Color(red: 56 / 255, green: 238 / 255, blue: 255 / 255)
    static let background = Color(
        light: Color(red: 245 / 255, green: 247 / 255, blue: 248 / 255),
        dark: Color(red: 16 / 255, green: 23 / 255, blue: 34 / 255)
    )
    static let surface = Color(
        light: .white,
        dark: Color(red: 24 / 255, green: 36 / 255, blue: 52 / 255)
    )
    static let surfaceBorder = Color(
        light: Color(red: 226 / 255, green: 231 / 255, blue: 239 / 255),
        dark: Color(red: 49 / 255, green: 72 / 255, blue: 104 / 255)
    )
    static let heroBase = Color(
        light: Color(red: 18 / 255, green: 26 / 255, blue: 42 / 255),
        dark: Color(red: 12 / 255, green: 18 / 255, blue: 28 / 255)
    )
    static let textPrimary = Color(
        light: Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255),
        dark: .white
    )
    static let textSecondary = Color(
        light: Color(red: 107 / 255, green: 114 / 255, blue: 128 / 255),
        dark: Color(red: 155 / 255, green: 164 / 255, blue: 178 / 255)
    )
    static let surfaceDark = Color(
        light: Color(red: 232 / 255, green: 236 / 255, blue: 242 / 255),
        dark: Color(red: 26 / 255, green: 36 / 255, blue: 51 / 255)
    )
}

extension Color {
    init(light: Color, dark: Color) {
        self = Color(
            UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor(dark)
                default:
                    return UIColor(light)
                }
            }
        )
    }
}
