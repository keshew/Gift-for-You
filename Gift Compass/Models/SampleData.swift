import SwiftUI
import UIKit
import PhotosUI
import Foundation

enum SampleData {
    static let categories = ["Tech", "Home", "Travel", "Books", "Fashion", "Experiences", "DIY", "Luxury"]
    static let occasions = ["Birthday", "Christmas", "Wedding", "Graduation", "Anniversary", "Housewarming", "Baby Shower", "Valentine's"]

    static let people: [GiftPerson] = [
        GiftPerson(
            name: "Emma Stone",
            relationship: "Friend",
            birthday: "Apr 12",
            tint: GCColor.accent,
            gifts: [
                GiftRecord(year: "2020", title: "Watch", price: "$120", store: "Nordstrom", occasion: "Birthday", reaction: "Loved it", comment: "Still wears it often.", score: 5, doNotRepeat: false, symbol: "applewatch", tint: GCColor.primary),
                GiftRecord(year: "2022", title: "Perfume", price: "$86", store: "Sephora", occasion: "Christmas", reaction: "Maybe", comment: "Too floral. Don't repeat.", score: 2, doNotRepeat: true, symbol: "drop.fill", tint: GCColor.accent),
                GiftRecord(year: "2024", title: "Headphones", price: "$179", store: "Apple", occasion: "Birthday", reaction: "Loved it", comment: "Best reaction of the year.", score: 5, doNotRepeat: false, symbol: "headphones", tint: GCColor.success)
            ],
            ideas: [
                GiftIdea(title: "Cooking Class", price: "$68", numericPrice: 68, store: "Local Studio", reason: "She keeps saving pasta videos.", tags: ["Experience", "Weekend", "Perfect"], status: "Perfect", symbol: "fork.knife", tint: GCColor.accent),
                GiftIdea(title: "Leather Wallet", price: "$54", numericPrice: 54, store: "Etsy", reason: "Matches her favorite brown tote.", tags: ["Fashion", "Daily"], status: "Great", symbol: "wallet.pass.fill", tint: GCColor.primary),
                GiftIdea(title: "Coffee Set", price: "$42", numericPrice: 42, store: "Blue Bottle", reason: "She loves slow mornings.", tags: ["Coffee", "Home"], status: "Maybe", symbol: "cup.and.saucer.fill", tint: GCColor.gold)
            ],
            wishes: ["Nintendo Switch", "Coffee Machine", "Sneakers"],
            brands: ["Nike", "Apple", "LEGO", "IKEA"],
            sizes: [("Shoes", "42"), ("T-shirt", "L"), ("Ring", "17")],
            dreamGifts: ["I want a projector someday.", "I've always wanted a piano.", "I wish I had AirPods Max."],
            relationshipTimeline: [
                TimelineMoment(year: "2018", title: "First Birthday"),
                TimelineMoment(year: "2019", title: "Christmas"),
                TimelineMoment(year: "2020", title: "Trip"),
                TimelineMoment(year: "2021", title: "Wedding"),
                TimelineMoment(year: "2025", title: "Anniversary")
            ]
        ),
        GiftPerson(
            name: "Mom",
            relationship: "Family",
            birthday: "Sep 8",
            tint: GCColor.success,
            gifts: [
                GiftRecord(year: "2021", title: "Book Collection", price: "$45", store: "Bookshop", occasion: "Birthday", reaction: "Loved it", comment: "Asked for volume two.", score: 5, doNotRepeat: false, symbol: "books.vertical.fill", tint: GCColor.gold),
                GiftRecord(year: "2023", title: "Spa", price: "$110", store: "Wellness Club", occasion: "Anniversary", reaction: "Loved it", comment: "Very relaxing.", score: 5, doNotRepeat: false, symbol: "sparkles", tint: GCColor.accent)
            ],
            ideas: [
                GiftIdea(title: "Garden Tools", price: "$35", numericPrice: 35, store: "IKEA", reason: "She started balcony herbs.", tags: ["Home", "DIY"], status: "Great", symbol: "leaf.fill", tint: GCColor.success),
                GiftIdea(title: "Silk Scarf", price: "$74", numericPrice: 74, store: "Local Boutique", reason: "Favorite color is warm gold.", tags: ["Fashion", "Luxury"], status: "Perfect", symbol: "scissors", tint: GCColor.gold)
            ],
            wishes: ["Coffee Machine", "Travel backpack"],
            brands: ["IKEA", "Uniqlo", "Zara Home"],
            sizes: [("Shoes", "39"), ("T-shirt", "M")],
            dreamGifts: ["A quiet weekend near the lake.", "A small greenhouse would be lovely."],
            relationshipTimeline: [
                TimelineMoment(year: "2019", title: "Mother's Day"),
                TimelineMoment(year: "2021", title: "Birthday"),
                TimelineMoment(year: "2023", title: "Anniversary")
            ]
        ),
        GiftPerson(
            name: "Alex Chen",
            relationship: "Coworker",
            birthday: "Jan 23",
            tint: GCColor.primary,
            gifts: [
                GiftRecord(year: "2023", title: "Mug", price: "$18", store: "Office Store", occasion: "Secret Santa", reaction: "Polite", comment: "Too generic.", score: 2, doNotRepeat: true, symbol: "mug.fill", tint: GCColor.primary)
            ],
            ideas: [
                GiftIdea(title: "Desk Lamp", price: "$49", numericPrice: 49, store: "Muji", reason: "New desk setup.", tags: ["Home", "Work"], status: "Great", symbol: "lamp.desk.fill", tint: GCColor.primary),
                GiftIdea(title: "Puzzle Box", price: "$28", numericPrice: 28, store: "Amazon", reason: "Likes mechanical puzzles.", tags: ["Funny", "Desk"], status: "Maybe", symbol: "shippingbox.fill", tint: GCColor.accent)
            ],
            wishes: ["Mechanical keyboard", "Noise cancelling earbuds"],
            brands: ["Logitech", "Apple", "Muji"],
            sizes: [("T-shirt", "M")],
            dreamGifts: ["Someday I want a proper espresso grinder."],
            relationshipTimeline: [
                TimelineMoment(year: "2022", title: "Project Launch"),
                TimelineMoment(year: "2023", title: "Secret Santa")
            ]
        )
    ]

    static let upcoming: [UpcomingEvent] = [
        UpcomingEvent(when: "Tomorrow", person: "Emma", occasion: "Birthday", symbol: "birthday.cake.fill", tint: GCColor.gold),
        UpcomingEvent(when: "5 days", person: "Mom", occasion: "Anniversary", symbol: "heart.fill", tint: GCColor.accent),
        UpcomingEvent(when: "2 weeks", person: "Alex", occasion: "Graduation", symbol: "graduationcap.fill", tint: GCColor.primary)
    ]

    static let myGifts = [
        GiftRecord(year: "2022", title: "Fountain Pen", price: "$38", store: "Gifted", occasion: "Birthday", reaction: "Loved it", comment: "Use it every week.", score: 5, doNotRepeat: false, symbol: "pencil.tip.crop.circle.fill", tint: GCColor.primary),
        GiftRecord(year: "2024", title: "Trip Album", price: "$0", store: "Handmade", occasion: "Holiday", reaction: "Loved it", comment: "Emotional and personal.", score: 5, doNotRepeat: false, symbol: "photo.stack.fill", tint: GCColor.success)
    ]

    static let collections: [GiftCollection] = [
        GiftCollection(title: "For Coffee Lovers", ideas: ["Coffee Set", "Espresso Grinder", "Ceramic Cups"], symbol: "cup.and.saucer.fill", tint: GCColor.gold),
        GiftCollection(title: "For Gamers", ideas: ["Nintendo Switch", "Controller Dock", "Game Pass"], symbol: "gamecontroller.fill", tint: GCColor.primary),
        GiftCollection(title: "For Travelers", ideas: ["Packing Cubes", "Weekend Bag", "City Pass"], symbol: "airplane", tint: GCColor.success),
        GiftCollection(title: "For Kids", ideas: ["LEGO Set", "Science Kit", "Story Book"], symbol: "balloon.2.fill", tint: GCColor.accent),
        GiftCollection(title: "Luxury Gifts", ideas: ["Silk Scarf", "Spa Day", "Leather Wallet"], symbol: "crown.fill", tint: GCColor.gold),
        GiftCollection(title: "Funny Gifts", ideas: ["Puzzle Box", "Custom Socks", "Desk Sign"], symbol: "theatermasks.fill", tint: GCColor.accent)
    ]

    static func categorySymbol(_ title: String) -> String {
        switch title {
        case "Tech": return "desktopcomputer"
        case "Home": return "house.fill"
        case "Travel": return "airplane"
        case "Books": return "books.vertical.fill"
        case "Fashion": return "tshirt.fill"
        case "Experiences": return "ticket.fill"
        case "DIY": return "hammer.fill"
        default: return "crown.fill"
        }
    }

    static func categoryTint(_ title: String) -> Color {
        switch title {
        case "Tech": return GCColor.primary
        case "Home": return GCColor.success
        case "Travel": return GCColor.accent
        case "Books": return GCColor.gold
        case "Fashion": return GCColor.accent
        case "Experiences": return GCColor.primary
        case "DIY": return GCColor.success
        default: return GCColor.gold
        }
    }

    static func occasionSymbol(_ title: String) -> String {
        switch title {
        case "Birthday": return "birthday.cake.fill"
        case "Christmas": return "snowflake"
        case "Wedding": return "heart.circle.fill"
        case "Graduation": return "graduationcap.fill"
        case "Anniversary": return "sparkles"
        case "Housewarming": return "house.fill"
        case "Baby Shower": return "figure.and.child.holdinghands"
        default: return "heart.fill"
        }
    }
}
