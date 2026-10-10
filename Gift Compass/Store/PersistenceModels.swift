import SwiftUI
import UIKit
import PhotosUI
import Foundation

struct StoredPerson: Codable {
    let id: UUID
    let name: String
    let relationship: String
    let birthday: String
    let tintKey: String
    let imageFileName: String?
    let gifts: [StoredGift]
    let ideas: [StoredIdea]
    let wishes: [String]
    let brands: [String]
    let sizes: [StoredSize]
    let dreamGifts: [String]
    let relationshipTimeline: [StoredTimelineMoment]
    let birthdayDate: Date?

    init(person: GiftPerson) {
        id = person.id
        name = person.name
        relationship = person.relationship
        birthday = person.birthday
        tintKey = person.tintKey
        imageFileName = person.imageFileName
        gifts = person.gifts.map(StoredGift.init(gift:))
        ideas = person.ideas.map(StoredIdea.init(idea:))
        wishes = person.wishes
        brands = person.brands
        sizes = person.sizes.map { StoredSize(key: $0.0, value: $0.1) }
        dreamGifts = person.dreamGifts
        relationshipTimeline = person.relationshipTimeline.map(StoredTimelineMoment.init(moment:))
        birthdayDate = person.birthdayDate
    }

    var person: GiftPerson {
        GiftPerson(
            id: id,
            name: name,
            relationship: relationship,
            birthday: birthday,
            tint: ColorToken.color(for: tintKey),
            tintKey: tintKey,
            imageFileName: imageFileName,
            gifts: gifts.map(\.gift),
            ideas: ideas.map(\.idea),
            wishes: wishes,
            brands: brands,
            sizes: sizes.map { ($0.key, $0.value) },
            dreamGifts: dreamGifts,
            relationshipTimeline: relationshipTimeline.map(\.moment),
            birthdayDate: birthdayDate ?? Self.parseBirthday(birthday)
        )
    }

    private static func parseBirthday(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d yyyy"
        let year = Calendar.current.component(.year, from: Date())
        return formatter.date(from: "\(value) \(year)")
    }
}

struct StoredGift: Codable {
    let id: UUID
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
    let tintKey: String
    let imageFileName: String?
    let category: String?
    let createdAt: Date?

    init(gift: GiftRecord) {
        id = gift.id
        year = gift.year
        title = gift.title
        price = gift.price
        store = gift.store
        occasion = gift.occasion
        reaction = gift.reaction
        comment = gift.comment
        score = gift.score
        doNotRepeat = gift.doNotRepeat
        symbol = gift.symbol
        tintKey = gift.tintKey
        imageFileName = gift.imageFileName
        category = gift.category
        createdAt = gift.createdAt
    }

    var gift: GiftRecord {
        GiftRecord(
            id: id,
            year: year,
            title: title,
            price: price,
            store: store,
            occasion: occasion,
            reaction: reaction,
            comment: comment,
            score: score,
            doNotRepeat: doNotRepeat,
            symbol: symbol,
            tint: ColorToken.color(for: tintKey),
            tintKey: tintKey,
            imageFileName: imageFileName,
            category: category ?? "Other",
            createdAt: createdAt ?? Date.distantPast
        )
    }
}

struct StoredIdea: Codable {
    let id: UUID
    let title: String
    let price: String
    let numericPrice: Double
    let store: String
    let reason: String
    let tags: [String]
    let status: String
    let symbol: String
    let tintKey: String
    let imageFileName: String?
    let category: String?
    let createdAt: Date?

    init(idea: GiftIdea) {
        id = idea.id
        title = idea.title
        price = idea.price
        numericPrice = idea.numericPrice
        store = idea.store
        reason = idea.reason
        tags = idea.tags
        status = idea.status
        symbol = idea.symbol
        tintKey = idea.tintKey
        imageFileName = idea.imageFileName
        category = idea.category
        createdAt = idea.createdAt
    }

    var idea: GiftIdea {
        GiftIdea(
            id: id,
            title: title,
            price: price,
            numericPrice: numericPrice,
            store: store,
            reason: reason,
            tags: tags,
            status: status,
            symbol: symbol,
            tint: ColorToken.color(for: tintKey),
            tintKey: tintKey,
            imageFileName: imageFileName,
            category: category ?? tags.first(where: { SampleData.categories.contains($0) }) ?? "Other",
            createdAt: createdAt ?? Date.distantPast
        )
    }
}

struct StoredSize: Codable {
    let key: String
    let value: String
}

struct StoredTimelineMoment: Codable {
    let year: String
    let title: String

    init(moment: TimelineMoment) {
        year = moment.year
        title = moment.title
    }

    var moment: TimelineMoment {
        TimelineMoment(year: year, title: title)
    }
}

// MARK: - App Flow
