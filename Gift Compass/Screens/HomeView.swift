import SwiftUI
import UIKit
import PhotosUI
import Foundation

struct HomeView: View {
    @EnvironmentObject private var store: GiftCompassStore

    private var recentGiftLabel: String {
        for person in store.people {
            if let gift = person.gifts.first {
                return "\(gift.title) for \(person.name)"
            }
        }
        return "No gifts recorded yet"
    }

    private var recentGiftOwner: GiftPerson? {
        store.people.first { !$0.gifts.isEmpty } ?? store.firstPerson
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    HeroSummaryCard()

                    ExecutiveMetricsCard()

                    GiftIntelligenceCard()

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        NavigationLinkCard(title: "Birthdays", subtitle: "\(store.people.count) people tracked", symbol: "birthday.cake.fill", tint: GCColor.gold) {
                            UpcomingGiftsView()
                        }
                        if let firstPerson = store.firstPerson {
                            NavigationLinkCard(title: "Recently Added", subtitle: recentGiftLabel, symbol: "clock.fill", tint: GCColor.success) {
                                GiftHistoryView(person: recentGiftOwner ?? firstPerson)
                            }
                            NavigationLinkCard(title: "Gift Ideas", subtitle: "\(store.allIdeas.count) saved", symbol: "lightbulb.fill", tint: GCColor.accent) {
                                IdeaVaultView(person: firstPerson)
                            }
                        } else {
                            NavigationLinkCard(title: "Add Someone", subtitle: "Start your private gift list", symbol: "person.badge.plus", tint: GCColor.success) {
                                AddPersonView()
                            }
                            NavigationLinkCard(title: "Gift Ideas", subtitle: "Add a person first", symbol: "lightbulb.fill", tint: GCColor.accent) {
                                AddPersonView()
                            }
                        }
                        NavigationLinkCard(title: "Quick Add", subtitle: "Person, gift or idea", symbol: "plus.circle.fill", tint: GCColor.primary) {
                            QuickAddView()
                        }
                    }

                    SectionHeader(title: "Best gifts ever", action: "View all")
                    BestGiftsStrip()

                    SectionHeader(title: "Never again", action: nil)
                    NeverAgainStrip()
                }
                .contentMargins()
            }
            .scrollIndicators(.hidden)
            .background(PremiumBackground())
            .navigationTitle("Gift for You")
        }
    }
}
