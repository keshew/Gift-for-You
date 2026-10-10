import SwiftUI
import UIKit
import PhotosUI
import Foundation

struct OccasionsView: View {
    @EnvironmentObject private var store: GiftCompassStore
    private let occasions = SampleData.occasions

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    NavigationLink {
                        UpcomingGiftsView()
                    } label: {
                        TimelinePreviewCard()
                    }
                    .buttonStyle(.plain)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(occasions, id: \.self) { occasion in
                            NavigationLink {
                                OccasionDetailView(occasion: occasion)
                            } label: {
                                OccasionCard(title: occasion)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .contentMargins()
            }
            .scrollIndicators(.hidden)
            .background(PremiumBackground())
            .navigationTitle("Occasions")
        }
    }
}

struct OccasionDetailView: View {
    @EnvironmentObject private var store: GiftCompassStore
    let occasion: String

    private var gifts: [OwnedGift] {
        store.people.flatMap { person in
            person.gifts.filter { $0.occasion == occasion }.map { OwnedGift(person: person, gift: $0) }
        }
    }

    var body: some View {
        DetailScroll(title: occasion) {
            if gifts.isEmpty {
                EmptyStateCard(title: "No \(occasion.lowercased()) gifts", subtitle: "Gifts saved for this occasion will appear here.", symbol: SampleData.occasionSymbol(occasion))
            }
            ForEach(gifts) { item in
                NavigationLink {
                    GiftDetailsView(personID: item.person.id, giftID: item.gift.id)
                } label: {
                    TimelineGiftRow(gift: item.gift)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct OwnedGift: Identifiable {
    var id: UUID { gift.id }
    let person: GiftPerson
    let gift: GiftRecord
}
