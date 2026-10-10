import SwiftUI
import UIKit
import PhotosUI
import Foundation

struct PeopleListView: View {
    @EnvironmentObject private var store: GiftCompassStore
    @State private var query = ""

    private var filteredPeople: [GiftPerson] {
        let people = query.isEmpty
            ? store.people
            : store.people.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.relationship.localizedCaseInsensitiveContains(query) }
        return people.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    if filteredPeople.isEmpty {
                        EmptyStateCard(
                            title: query.isEmpty ? "No people yet" : "No matches",
                            subtitle: query.isEmpty ? "Add someone to begin saving thoughtful gift ideas." : "Try another name or relationship.",
                            symbol: query.isEmpty ? "person.badge.plus" : "magnifyingglass"
                        )
                    }
                    ForEach(filteredPeople) { person in
                        NavigationLink {
                            PersonProfileView(person: person)
                        } label: {
                            PersonRow(person: person)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .contentMargins()
            }
            .searchable(text: $query, prompt: "Search people")
            .background(PremiumBackground())
            .navigationTitle("People")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AddPersonView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct PersonProfileView: View {
    @EnvironmentObject private var store: GiftCompassStore
    @Environment(\.dismiss) private var dismiss
    let person: GiftPerson
    @State private var showSurprise = false
    @State private var isEditing = false
    @State private var confirmsDeletion = false

    private var currentPerson: GiftPerson {
        store.people.first { $0.id == person.id } ?? person
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                PersonHero(person: currentPerson)

                HStack(spacing: 12) {
                    StatPill(value: "\(currentPerson.gifts.count)", label: "gifts")
                    StatPill(value: "\(currentPerson.ideas.count)", label: "ideas")
                    StatPill(value: "\(currentPerson.wishes.count)", label: "wishes")
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    NavigationLinkCard(title: "Gift History", subtitle: "Timeline", symbol: "timeline.selection", tint: GCColor.primary) {
                        GiftHistoryView(person: currentPerson)
                    }
                    NavigationLinkCard(title: "Wishlist", subtitle: "What they want", symbol: "heart.fill", tint: GCColor.success) {
                        WishlistView(person: currentPerson)
                    }
                    NavigationLinkCard(title: "Idea Vault", subtitle: "Private ideas", symbol: "lightbulb.fill", tint: GCColor.accent) {
                        IdeaVaultView(person: currentPerson)
                    }
                    NavigationLinkCard(title: "Add Gift", subtitle: "Track reaction", symbol: "plus.circle.fill", tint: GCColor.gold) {
                        AddGiftView(person: currentPerson)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "Favorite brands", action: nil)
                        if currentPerson.brands.isEmpty {
                            Text("No favorite brands saved yet.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(GCColor.text.opacity(0.5))
                        } else {
                            TagWrap(tags: currentPerson.brands, tint: GCColor.primary)
                        }
                        SectionHeader(title: "Favorite sizes", action: nil)
                        if currentPerson.sizes.isEmpty {
                            Text("No sizes saved yet.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(GCColor.text.opacity(0.5))
                        } else {
                            VStack(spacing: 8) {
                            ForEach(currentPerson.sizes, id: \.0) { item in
                                KeyValueRow(key: item.0, value: item.1)
                            }
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Dream gifts", action: nil)
                        if currentPerson.dreamGifts.isEmpty {
                            Text("No gift notes saved yet.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(GCColor.text.opacity(0.5))
                        }
                        ForEach(currentPerson.dreamGifts, id: \.self) { quote in
                            Label(quote, systemImage: "quote.opening")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(GCColor.text.opacity(0.78))
                        }
                    }
                }

                Button {
                    haptic(.heavy)
                    showSurprise.toggle()
                } label: {
                    Label("Surprise Me", systemImage: "gift.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(GCColor.accent, in: Capsule())
            }
            .contentMargins()
        }
        .scrollIndicators(.hidden)
        .background(PremiumBackground())
        .navigationTitle(currentPerson.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showSurprise) {
            SurpriseSheet(person: currentPerson)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isEditing) {
            EditPersonView(person: currentPerson)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit Person", systemImage: "pencil") { isEditing = true }
                    Button("Delete Person", systemImage: "trash", role: .destructive) { confirmsDeletion = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Delete \(currentPerson.name)?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Delete Person", role: .destructive) {
                store.deletePerson(personID: currentPerson.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Their wishes, ideas, gifts and saved photos will also be removed.")
        }
    }
}
