import SwiftUI
import UIKit
import PhotosUI
import Foundation

enum GCColor {
    static let background = Color.adaptive(light: "F7F6F3", dark: "10131B")
    static let primary = Color.adaptive(light: "2E3A59", dark: "6076AD")
    static let action = Color(hex: "2E3A59")
    static let text = Color.adaptive(light: "2E3A59", dark: "F1F3FA")
    static let accent = Color.adaptive(light: "D98E73", dark: "F0A185")
    static let success = Color.adaptive(light: "77B28C", dark: "8DCCA1")
    static let gold = Color.adaptive(light: "C9A44C", dark: "E0BC62")
    static let ink = Color.adaptive(light: "17213A", dark: "0A0E16")
    static let champagne = Color.adaptive(light: "E9D8AE", dark: "74623E")
    static let porcelain = Color.adaptive(light: "FFFDF8", dark: "171B26")
    static let platinum = Color.adaptive(light: "D8DDE7", dark: "343B4D")
    static let rosewood = Color.adaptive(light: "9B5F55", dark: "B8786D")
    static let card = Color.adaptive(light: "FFFFFF", dark: "1D2230")
    static let cardHighlight = Color.adaptive(light: "FFFFFF", dark: "4B5369")
    static let softLine = Color.adaptive(light: "E8E8E8", dark: "343A49")
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum ColorToken {
    static func color(for key: String) -> Color {
        switch key {
        case "accent": return GCColor.accent
        case "success": return GCColor.success
        case "gold": return GCColor.gold
        case "ink": return GCColor.ink
        case "rosewood": return GCColor.rosewood
        default: return GCColor.primary
        }
    }

    static func key(for favoriteColor: String) -> String {
        switch favoriteColor {
        case "Green": return "success"
        case "Gold": return "gold"
        case "Black": return "ink"
        case "Pink": return "accent"
        default: return "primary"
        }
    }

    static func key(forCategory category: String) -> String {
        switch category {
        case "Home", "DIY": return "success"
        case "Travel", "Fashion": return "accent"
        case "Books", "Luxury": return "gold"
        default: return "primary"
        }
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }

    static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let scanner = Scanner(string: hex)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)
        self.init(
            red: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255,
            alpha: 1
        )
    }
}
