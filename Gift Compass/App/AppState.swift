import SwiftUI
import UIKit
import PhotosUI
import Foundation

enum AppPhase {
    case splash
    case loading
    case onboarding
    case main
}

enum OnboardingStorage {
    static let completedKey = "giftCompass.onboarding.completed"
    private static let legacyCompletedKey = "giftCompass.hasCompletedOnboarding"

    static var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey) || UserDefaults.standard.bool(forKey: legacyCompletedKey)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
        UserDefaults.standard.set(true, forKey: legacyCompletedKey)
    }
}

enum ClientIdentity {
    private static let storageKey = "giftForYou.clientIdentifier"

    static var current: String {
        if let stored = UserDefaults.standard.string(forKey: storageKey), UUID(uuidString: stored) != nil {
            return stored
        }

        let generated = UUID().uuidString.lowercased()
        UserDefaults.standard.set(generated, forKey: storageKey)
        return generated
    }
}

enum GiftTab: String, CaseIterable {
    case home = "Home"
    case people = "People"
    case ideas = "Ideas"
    case occasions = "Occasions"
    case settings = "Settings"

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .people: return "person.2.fill"
        case .ideas: return "lightbulb.fill"
        case .occasions: return "calendar.badge.clock"
        case .settings: return "gearshape.fill"
        }
    }
}
