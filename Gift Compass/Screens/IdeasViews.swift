import SwiftUI
import UIKit
import PhotosUI
import Foundation

struct IdeasHubView: View {
    @EnvironmentObject private var store: GiftCompassStore
    @State private var isAddingIdea = false
    @State private var query = ""
    @State private var statusFilter = "All"
    @State private var personFilter: UUID?

    private var filteredIdeas: [OwnedIdea] {
        store.people.flatMap { person in
            person.ideas.compactMap { idea in
                let matchesQuery = query.isEmpty || idea.title.localizedCaseInsensitiveContains(query) || idea.reason.localizedCaseInsensitiveContains(query)
                let matchesStatus = statusFilter == "All" || idea.status == statusFilter
                let matchesPerson = personFilter == nil || person.id == personFilter
                return matchesQuery && matchesStatus && matchesPerson ? OwnedIdea(person: person, idea: idea) : nil
            }
        }
        .sorted { $0.idea.createdAt > $1.idea.createdAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    SurpriseBoxCard()

                    if store.people.isEmpty {
                        NavigationLink {
                            AddPersonView()
                        } label: {
                            SimpleItemCard(title: "Add a Person First", subtitle: "Ideas need someone to surprise", symbol: "person.badge.plus", tint: GCColor.primary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        AddMiniCard(title: "Save a New Idea", symbol: "plus") {
                            isAddingIdea = true
                        }
                    }

                    if let firstPerson = store.firstPerson {
                        FeatureGrid(items: [
                            FeatureItem("Idea Vault", "Great, Maybe, Perfect", "tray.full.fill", GCColor.accent, AnyView(IdeaVaultView(person: firstPerson))),
                            FeatureItem("Wishlist", "What they want", "heart.fill", GCColor.success, AnyView(WishlistView(person: firstPerson))),
                            FeatureItem("Budget Planner", "Ideas by price", "slider.horizontal.3", GCColor.primary, AnyView(BudgetPlannerView())),
                            FeatureItem("Categories", "Tech, Travel, Books", "square.grid.2x2.fill", GCColor.gold, AnyView(GiftCategoriesView()))
                        ])
                    } else {
                        NavigationLink {
                            AddPersonView()
                        } label: {
                            EmptyStateCard(title: "Add your first person", subtitle: "Ideas are organized privately around the people you care about.", symbol: "person.badge.plus")
                        }
                        .buttonStyle(.plain)
                    }

                    SectionHeader(title: "Your saved ideas", action: nil)
                    if !store.allIdeas.isEmpty {
                        SearchField(text: $query)
                        GlassCard {
                            VStack(spacing: 12) {
                                Picker("Status", selection: $statusFilter) {
                                    ForEach(["All", "Perfect", "Great", "Maybe"], id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.segmented)
                                Picker("Person", selection: $personFilter) {
                                    Text("Everyone").tag(UUID?.none)
                                    ForEach(store.people) { person in
                                        Text(person.name).tag(Optional(person.id))
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }
                    if store.allIdeas.isEmpty {
                        EmptyStateCard(title: "No ideas saved", subtitle: "Add a gift idea, attach a photo and keep it ready for the right moment.", symbol: "lightbulb")
                    } else if filteredIdeas.isEmpty {
                        EmptyStateCard(title: "No matching ideas", subtitle: "Try another person, status or search phrase.", symbol: "line.3.horizontal.decrease.circle")
                    } else {
                        ForEach(filteredIdeas) { item in
                            NavigationLink {
                                IdeaDetailsView(personID: item.person.id, ideaID: item.idea.id)
                            } label: {
                                IdeaRow(idea: item.idea, ownerName: item.person.name)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    SectionHeader(title: "Collections", action: nil)
                    ForEach(store.collections) { collection in
                        NavigationLink {
                            CollectionDetailView(collection: collection)
                        } label: {
                            CollectionRow(collection: collection)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .contentMargins()
            }
            .scrollIndicators(.hidden)
            .background(PremiumBackground())
            .navigationTitle("Ideas")
            .sheet(isPresented: $isAddingIdea) {
                AddIdeaSheet(person: store.people.first)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        GlobalSearchView()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
        }
    }
}

struct WishlistView: View {
    @EnvironmentObject private var store: GiftCompassStore
    let person: GiftPerson
    @State private var isAddingWish = false
    @State private var editingWish: IndexedWish?
    private var currentPerson: GiftPerson {
        store.people.first { $0.id == person.id } ?? person
    }

    var body: some View {
        DetailScroll(title: "Wishlist") {
            AddMiniCard(title: "Add Wish", symbol: "plus") {
                isAddingWish = true
            }
            if currentPerson.wishes.isEmpty {
                EmptyStateCard(title: "No wishes yet", subtitle: "Save something \(currentPerson.name) mentioned.", symbol: "heart")
            }
            ForEach(Array(currentPerson.wishes.enumerated()), id: \.offset) { index, wish in
                EditableTextRow(title: wish, subtitle: "Wanted by \(currentPerson.name)", symbol: "heart.fill", tint: GCColor.success) {
                    editingWish = IndexedWish(index: index, title: wish)
                } deleteAction: {
                    store.deleteWish(personID: currentPerson.id, index: index)
                }
            }
        }
        .sheet(isPresented: $isAddingWish) {
            AddWishSheet(person: currentPerson)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingWish) { wish in
            EditWishSheet(personID: currentPerson.id, wish: wish)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

struct IndexedWish: Identifiable {
    let index: Int
    let title: String
    var id: Int { index }
}

struct EditWishSheet: View {
    @EnvironmentObject private var store: GiftCompassStore
    @Environment(\.dismiss) private var dismiss
    let personID: UUID
    let wish: IndexedWish
    @State private var title: String

    init(personID: UUID, wish: IndexedWish) {
        self.personID = personID
        self.wish = wish
        self._title = State(initialValue: wish.title)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                FieldCard("Wish", text: $title, placeholder: "Something they mentioned")
                PrimaryActionButton(title: "Save Changes", symbol: "checkmark", isEnabled: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    store.updateWish(personID: personID, index: wish.index, title: title)
                    dismiss()
                }
                Spacer()
            }
            .contentMargins()
            .background(PremiumBackground())
            .navigationTitle("Edit Wish")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct IdeaVaultView: View {
    @EnvironmentObject private var store: GiftCompassStore
    let person: GiftPerson
    @State private var isAddingIdea = false
    private var currentPerson: GiftPerson {
        store.people.first { $0.id == person.id } ?? person
    }

    var body: some View {
        DetailScroll(title: "Idea Vault") {
            AddMiniCard(title: "Add Idea", symbol: "plus") {
                isAddingIdea = true
            }
            if currentPerson.ideas.isEmpty {
                EmptyStateCard(title: "No ideas for \(currentPerson.name)", subtitle: "Save the first idea and optionally attach a photo.", symbol: "lightbulb")
            }
            ForEach(currentPerson.ideas) { idea in
                NavigationLink {
                    IdeaDetailsView(personID: currentPerson.id, ideaID: idea.id)
                } label: {
                    IdeaRow(idea: idea)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $isAddingIdea) {
            AddIdeaSheet(person: currentPerson)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct IdeaDetailsView: View {
    @EnvironmentObject private var store: GiftCompassStore
    @Environment(\.dismiss) private var dismiss
    let personID: UUID
    let ideaID: UUID
    @State private var isEditing = false
    @State private var confirmsDeletion = false

    private var person: GiftPerson? {
        store.people.first { $0.id == personID }
    }

    private var idea: GiftIdea? {
        person?.ideas.first { $0.id == ideaID }
    }

    var body: some View {
        Group {
            if let idea {
                DetailScroll(title: idea.title) {
                    PhotoHeader(symbol: idea.symbol, tint: idea.tint, imageFileName: idea.imageFileName)
                    GlassCard {
                        VStack(spacing: 14) {
                            if let person {
                                KeyValueRow(key: "For", value: person.name)
                            }
                            KeyValueRow(key: "Price", value: idea.price)
                            KeyValueRow(key: "Where to buy", value: idea.store)
                            KeyValueRow(key: "Why it fits", value: idea.reason)
                            KeyValueRow(key: "Status", value: idea.status)
                            TagWrap(tags: idea.tags, tint: idea.tint)
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Edit Idea", systemImage: "pencil") { isEditing = true }
                            Button("Delete Idea", systemImage: "trash", role: .destructive) { confirmsDeletion = true }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: $isEditing) {
                    EditIdeaSheet(personID: personID, idea: idea)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
                .confirmationDialog("Delete this idea?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
                    Button("Delete Idea", role: .destructive) {
                        store.deleteIdea(personID: personID, ideaID: ideaID)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("The idea and its saved photo will be removed from this device.")
                }
            } else {
                EmptyStateCard(title: "Idea not found", subtitle: "It may have been removed.", symbol: "exclamationmark.triangle")
                    .padding()
            }
        }
    }
}

struct AddWishSheet: View {
    @EnvironmentObject private var store: GiftCompassStore
    @Environment(\.dismiss) private var dismiss
    let person: GiftPerson
    @State private var title = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                FieldCard("Wish", text: $title, placeholder: "Nintendo Switch")
                PrimaryActionButton(title: "Save Wish", symbol: "heart.fill", isEnabled: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    store.addWish(personID: person.id, title: title)
                    dismiss()
                }
                Spacer()
            }
            .contentMargins()
            .background(PremiumBackground())
            .navigationTitle("Add Wish")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct AddIdeaSheet: View {
    @EnvironmentObject private var store: GiftCompassStore
    @Environment(\.dismiss) private var dismiss
    let person: GiftPerson?
    @State private var selectedPersonID: UUID?
    @State private var title = ""
    @State private var price = ""
    @State private var place = ""
    @State private var reason = ""
    @State private var status = "Great"
    @State private var category = "Other"
    @State private var imageData: Data?

    init(person: GiftPerson? = nil) {
        self.person = person
        self._selectedPersonID = State(initialValue: person?.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    PhotoPickerCard(symbol: "photo.badge.plus", title: "Idea photo", imageData: $imageData)
                    if store.people.count > 1 {
                        GlassCard {
                            Picker("For", selection: $selectedPersonID) {
                                ForEach(store.people) { person in
                                    Text(person.name).tag(Optional(person.id))
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    FieldCard("Idea", text: $title, placeholder: "Leather Wallet")
                    FieldCard("Price", text: $price, placeholder: "$54", keyboardType: .decimalPad)
                    FieldCard("Where to buy", text: $place, placeholder: "Etsy")
                    NotesCard(title: "Why it fits", text: $reason, placeholder: "Matches saved preferences and past reactions.")
                    PickerCard(title: "Category", selection: $category, options: SampleData.categories + ["Other"])
                    PickerCard(title: "Status", selection: $status, options: ["Great", "Maybe", "Perfect"])
                    PrimaryActionButton(title: "Save Idea", symbol: "lightbulb.fill", isEnabled: selectedPersonID != nil && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        guard let selectedPersonID else { return }
                        store.addIdea(personID: selectedPersonID, title: title, price: price, store: place, reason: reason, status: status, category: category, imageData: imageData)
                        dismiss()
                    }
                }
                .contentMargins()
            }
            .background(PremiumBackground())
            .navigationTitle("Add Idea")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct EditIdeaSheet: View {
    @EnvironmentObject private var store: GiftCompassStore
    @Environment(\.dismiss) private var dismiss
    let personID: UUID
    let idea: GiftIdea
    @State private var title: String
    @State private var price: String
    @State private var place: String
    @State private var reason: String
    @State private var status: String
    @State private var category: String
    @State private var replacementImageData: Data?
    @State private var removesExistingImage = false

    init(personID: UUID, idea: GiftIdea) {
        self.personID = personID
        self.idea = idea
        self._title = State(initialValue: idea.title)
        self._price = State(initialValue: idea.price)
        self._place = State(initialValue: idea.store)
        self._reason = State(initialValue: idea.reason)
        self._status = State(initialValue: idea.status)
        self._category = State(initialValue: idea.category)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    PhotoPickerCard(
                        symbol: "photo.badge.plus",
                        title: "Idea photo",
                        imageData: $replacementImageData,
                        existingImageFileName: idea.imageFileName,
                        removesExistingImage: $removesExistingImage
                    )
                    FieldCard("Idea", text: $title, placeholder: "Leather Wallet")
                    FieldCard("Price", text: $price, placeholder: "$54", keyboardType: .decimalPad)
                    FieldCard("Where to buy", text: $place, placeholder: "Etsy")
                    NotesCard(title: "Why it fits", text: $reason, placeholder: "A reminder for your future self.")
                    PickerCard(title: "Category", selection: $category, options: SampleData.categories + ["Other"])
                    PickerCard(title: "Status", selection: $status, options: ["Great", "Maybe", "Perfect"])
                    PrimaryActionButton(title: "Save Changes", symbol: "checkmark", isEnabled: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        store.updateIdea(
                            personID: personID,
                            ideaID: idea.id,
                            title: title,
                            price: price,
                            store: place,
                            reason: reason,
                            status: status,
                            category: category,
                            replacementImageData: replacementImageData,
                            removeImage: removesExistingImage
                        )
                        dismiss()
                    }
                }
                .contentMargins()
            }
            .background(PremiumBackground())
            .navigationTitle("Edit Idea")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct GiftCategoriesView: View {
    @EnvironmentObject private var store: GiftCompassStore

    var body: some View {
        DetailScroll(title: "Categories") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(SampleData.categories, id: \.self) { category in
                    NavigationLink {
                        CategoryIdeasView(category: category)
                    } label: {
                        CategoryCard(title: category)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct CategoryIdeasView: View {
    @EnvironmentObject private var store: GiftCompassStore
    let category: String

    private var ideas: [OwnedIdea] {
        store.people.flatMap { person in
            person.ideas.filter { $0.category == category }.map { OwnedIdea(person: person, idea: $0) }
        }
    }

    var body: some View {
        DetailScroll(title: category) {
            if ideas.isEmpty {
                EmptyStateCard(title: "No \(category.lowercased()) ideas", subtitle: "Choose this category when saving a new idea.", symbol: SampleData.categorySymbol(category))
            }
            ForEach(ideas) { item in
                NavigationLink {
                    IdeaDetailsView(personID: item.person.id, ideaID: item.idea.id)
                } label: {
                    IdeaRow(idea: item.idea, ownerName: item.person.name)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct OwnedIdea: Identifiable {
    var id: UUID { idea.id }
    let person: GiftPerson
    let idea: GiftIdea
}

struct BudgetPlannerView: View {
    @EnvironmentObject private var store: GiftCompassStore
    @State private var budget = 74.0

    private var bracket: String {
        switch budget {
        case ..<20: return "Under $20"
        case ..<50: return "$20-50"
        case ..<100: return "$50-100"
        default: return "$100+"
        }
    }

    var body: some View {
        DetailScroll(title: "Budget Planner") {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(bracket)
                            .font(.title2.weight(.heavy))
                        Spacer()
                        Text("$\(Int(budget))")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(GCColor.accent)
                    }
                    Slider(value: $budget, in: 10...180, step: 1)
                    HStack {
                        Text("Under $20")
                        Spacer()
                        Text("$100+")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(GCColor.text.opacity(0.5))
                }
            }

            ForEach(store.people) { person in
                ForEach(person.ideas.filter { $0.numericPrice <= budget }) { idea in
                    NavigationLink {
                        IdeaDetailsView(personID: person.id, ideaID: idea.id)
                    } label: {
                        IdeaRow(idea: idea, ownerName: person.name)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct CollectionDetailView: View {
    let collection: GiftCollection

    var body: some View {
        DetailScroll(title: collection.title) {
            PhotoHeader(symbol: collection.symbol, tint: collection.tint)
            ForEach(collection.ideas, id: \.self) { idea in
                SimpleItemCard(title: idea, subtitle: collection.title, symbol: "lightbulb.fill", tint: collection.tint)
            }
        }
    }
}
