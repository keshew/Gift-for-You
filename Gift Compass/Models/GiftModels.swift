import SwiftUI
import UIKit
import PhotosUI
import Foundation

struct GiftPerson: Identifiable {
    var id: UUID = UUID()
    let name: String
    let relationship: String
    let birthday: String
    let tint: Color
    var tintKey: String = "primary"
    var imageFileName: String? = nil
    var gifts: [GiftRecord]
    var ideas: [GiftIdea]
    var wishes: [String]
    var brands: [String]
    var sizes: [(String, String)]
    var dreamGifts: [String]
    var relationshipTimeline: [TimelineMoment]
    var birthdayDate: Date? = nil
}

struct GiftRecord: Identifiable {
    var id: UUID = UUID()
    let year: String
    let title: String
    let price: String
    let store: String
    let occasion: String
    let reaction: String
    let comment: String
    let score: Int
    let doNotRepeat: Bool
    let symbol: String
    let tint: Color
    var tintKey: String = "primary"
    var imageFileName: String? = nil
    var category: String = "Other"
    var createdAt: Date = Date()
}

struct GiftIdea: Identifiable {
    var id: UUID = UUID()
    let title: String
    let price: String
    let numericPrice: Double
    let store: String
    let reason: String
    let tags: [String]
    let status: String
    let symbol: String
    let tint: Color
    var tintKey: String = "primary"
    var imageFileName: String? = nil
    var category: String = "Other"
    var createdAt: Date = Date()
}

struct TimelineMoment {
    let year: String
    let title: String
}

struct UpcomingEvent: Identifiable {
    let id = UUID()
    let when: String
    let person: String
    let occasion: String
    let symbol: String
    let tint: Color
}

struct GiftCollection: Identifiable {
    let id = UUID()
    let title: String
    let ideas: [String]
    let symbol: String
    let tint: Color
}

extension GiftPerson {
    var nextBirthday: Date? {
        guard let birthdayDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: birthdayDate)
        let currentYear = calendar.component(.year, from: Date())
        var nextComponents = DateComponents(year: currentYear, month: components.month, day: components.day)
        guard var next = calendar.date(from: nextComponents) else { return nil }
        if next < calendar.startOfDay(for: Date()) {
            nextComponents.year = currentYear + 1
            next = calendar.date(from: nextComponents) ?? next
        }
        return next
    }

    var birthdayCountdown: String {
        guard let nextBirthday else { return birthday }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: nextBirthday).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(days) days"
        }
    }
}
