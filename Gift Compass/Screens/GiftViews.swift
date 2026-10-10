import SwiftUI
import UIKit
import PhotosUI
import Foundation

struct AddPersonView: View {
    @EnvironmentObject private var store: GiftCompassStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var birthday = Date()
    @State private var relationship = "Friend"
    @State private var color = "Blue"
    @State private var notes = ""
    @State private var brands = ""
    @State private var sizes = ""
    @State private var imageData: Data?

    var body: some View {
        FormShell(title: "Add Person") {
            PhotoPickerCard(symbol: "person.crop.circle.badge.plus", title: "Person photo", imageData: $imageData)
            FieldCard("Name", text: $name, placeholder: "Emma")
            DateFieldCard(title: "Birthday", date: $birthday)
            PickerCard(title: "Relationship", selection: $relationship, options: ["Friend", "Family", "Coworker", "Partner"])
            PickerCard(title: "Favorite Color", selection: $color, options: ["Blue", "Green", "Gold", "Black", "Pink"])
            FieldCard("Favorite Brands", text: $brands, placeholder: "Apple, LEGO, Nike")
            NotesCard(title: "Sizes", text: $sizes, placeholder: "Shoes: 42\nT-shirt: L")
            NotesCard(title: "Gift Notes", text: $notes, placeholder: "Hobbies, hints and no-repeat rules...")
            PrimaryActionButton(title: "Save Person", symbol: "checkmark", isEnabled: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                store.addPerson(name: name, birthday: birthday, relationship: relationship, favoriteColor: color, notes: notes, brandsText: brands, sizesText: sizes, imageData: imageData)
                dismiss()
            }
        }
    }
}

struct EditPersonView: View {
    @EnvironmentObject private var store: GiftCompassStore
    @Environment(\.dismiss) private var dismiss
    let person: GiftPerson
    @State private var name: String
    @State private var birthday: Date
    @State private var relationship: String
    @State private var color: String
    @State private var notes: String
    @State private var brands: String
    @State private var sizes: String
    @State private var replacementImageData: Data?
    @State private var removesExistingImage = false

    init(person: GiftPerson) {
        self.person = person
        self._name = State(initialValue: person.name)
        self._birthday = State(initialValue: person.birthdayDate ?? Date())
        self._relationship = State(initialValue: person.relationship)
        self._color = State(initialValue: Self.colorName(for: person.tintKey))
        self._notes = State(initialValue: person.dreamGifts.first ?? "")
        self._brands = State(initialValue: person.brands.joined(separator: ", "))
        self._sizes = State(initialValue: person.sizes.map { "\($0.0): \($0.1)" }.joined(separator: "\n"))
    }

    var body: some View {
        NavigationStack {
            FormShell(title: "Edit Person") {
                PhotoPickerCard(
                    symbol: "person.crop.circle.badge.plus",
                    title: "Person photo",
                    imageData: $replacementImageData,
                    existingImageFileName: person.imageFileName,
                    removesExistingImage: $removesExistingImage
                )
                FieldCard("Name", text: $name, placeholder: "Name")
                DateFieldCard(title: "Birthday", date: $birthday)
                PickerCard(title: "Relationship", selection: $relationship, options: ["Friend", "Family", "Coworker", "Partner"])
                PickerCard(title: "Favorite Color", selection: $color, options: ["Blue", "Green", "Gold", "Black", "Pink"])
                FieldCard("Favorite Brands", text: $brands, placeholder: "Apple, LEGO, Nike")
                NotesCard(title: "Sizes", text: $sizes, placeholder: "Shoes: 42\nT-shirt: L")
                NotesCard(title: "Notes", text: $notes, placeholder: "Favorite brands, sizes and gift hints")
                PrimaryActionButton(title: "Save Changes", symbol: "checkmark", isEnabled: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    store.updatePerson(
                        personID: person.id,
                        name: name,
                        birthday: birthday,
                        relationship: relationship,
                        favoriteColor: color,
                        notes: notes,
                        brandsText: brands,
                        sizesText: sizes,
                        replacementImageData: replacementImageData,
                        removeImage: removesExistingImage
                    )
                    dismiss()
                }
            }
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
    }

    private static func colorName(for key: String) -> String {
        switch key {
        case "success": return "Green"
        case "gold": return "Gold"
        case "ink": return "Black"
        case "accent": return "Pink"
        default: return "Blue"
        }
    }
}

struct GiftHistoryView: View {
    @EnvironmentObject private var store: GiftCompassStore
    let person: GiftPerson
    private var currentPerson: GiftPerson {
        store.people.first { $0.id == person.id } ?? person
    }

    var body: some View {
        DetailScroll(title: "Gift History") {
            GiftRelationshipTimeline(person: currentPerson)
            if currentPerson.gifts.isEmpty {
                EmptyStateCard(title: "No gifts recorded", subtitle: "Add the first gift to remember what worked and what did not.", symbol: "gift")
            }
            ForEach(currentPerson.gifts) { gift in
                NavigationLink {
                    GiftDetailsView(personID: currentPerson.id, giftID: gift.id)
                } label: {
                    TimelineGiftRow(gift: gift)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct GiftDetailsView: View {
    @EnvironmentObject private var store: GiftCompassStore
    @Environment(\.dismiss) private var dismiss
    let personID: UUID
    let giftID: UUID
    @State private var isEditing = false
    @State private var confirmsDeletion = false

    private var gift: GiftRecord? {
        store.people.first { $0.id == personID }?.gifts.first { $0.id == giftID }
    }

    var body: some View {
        Group {
            if let gift {
                DetailScroll(title: gift.title) {
                    PhotoHeader(symbol: gift.symbol, tint: gift.tint, imageFileName: gift.imageFileName)
                    GlassCard {
                        VStack(spacing: 14) {
                            KeyValueRow(key: "Price", value: gift.price)
                            KeyValueRow(key: "Store", value: gift.store)
                            KeyValueRow(key: "Category", value: gift.category)
                            KeyValueRow(key: "Occasion", value: gift.occasion)
                            KeyValueRow(key: "Liked it?", value: gift.reaction)
                            KeyValueRow(key: "Gift Score", value: String(repeating: "★", count: gift.score))
                            KeyValueRow(key: "Comment", value: gift.comment)
                        }
                    }
                    if gift.doNotRepeat {
                        WarningCard(title: "Don't buy again", subtitle: "Marked as a no-repeat gift.")
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Edit Gift", systemImage: "pencil") { isEditing = true }
                            Button("Delete Gift", systemImage: "trash", role: .destructive) { confirmsDeletion = true }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
                .sheet(isPresented: $isEditing) {
                    EditGiftView(personID: personID, gift: gift)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
                .confirmationDialog("Delete this gift?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
                    Button("Delete Gift", role: .destructive) {
                        store.deleteGift(personID: personID, giftID: giftID)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("The gift and its saved photo will be removed.")
                }
            } else {
                EmptyStateCard(title: "Gift not found", subtitle: "It may have been removed.", symbol: "gift")
                    .padding()
            }
        }
    }
}

struct AddGiftView: View {
    @EnvironmentObject private var storeModel: GiftCompassStore
    @Environment(\.dismiss) private var dismiss
    let person: GiftPerson
    @State private var title = ""
    @State private var store = ""
    @State private var price = ""
    @State private var category = "Tech"
    @State private var occasion = "Birthday"
    @State private var reaction = "Loved it"
    @State private var imageData: Data?

    var body: some View {
        FormShell(title: "Add Gift") {
            PhotoPickerCard(symbol: "photo.badge.plus", title: "Gift photo", imageData: $imageData)
            FieldCard("Gift", text: $title, placeholder: "Noise-cancelling headphones")
            FieldCard("Store", text: $store, placeholder: "Where you bought it")
            FieldCard("Price", text: $price, placeholder: "$74", keyboardType: .decimalPad)
            PickerCard(title: "Category", selection: $category, options: SampleData.categories)
            PickerCard(title: "Occasion", selection: $occasion, options: SampleData.occasions)
            PickerCard(title: "Reaction", selection: $reaction, options: ["Loved it", "Liked it", "Maybe", "Never again"])
            PrimaryActionButton(title: "Save Gift for \(person.name)", symbol: "gift.fill", isEnabled: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                storeModel.addGift(personID: person.id, title: title, store: store, price: price, category: category, occasion: occasion, reaction: reaction, imageData: imageData)
                dismiss()
            }
        }
    }
}

struct EditGiftView: View {
    @EnvironmentObject private var storeModel: GiftCompassStore
    @Environment(\.dismiss) private var dismiss
    let personID: UUID
    let gift: GiftRecord
    @State private var title: String
    @State private var store: String
    @State private var price: String
    @State private var category: String
    @State private var occasion: String
    @State private var reaction: String
    @State private var replacementImageData: Data?
    @State private var removesExistingImage = false

    init(personID: UUID, gift: GiftRecord) {
        self.personID = personID
        self.gift = gift
        self._title = State(initialValue: gift.title)
        self._store = State(initialValue: gift.store)
        self._price = State(initialValue: gift.price)
        self._category = State(initialValue: gift.category == "Other" ? "Tech" : gift.category)
        self._occasion = State(initialValue: gift.occasion)
        self._reaction = State(initialValue: gift.reaction)
    }

    var body: some View {
        NavigationStack {
            FormShell(title: "Edit Gift") {
                PhotoPickerCard(
                    symbol: "photo.badge.plus",
                    title: "Gift photo",
                    imageData: $replacementImageData,
                    existingImageFileName: gift.imageFileName,
                    removesExistingImage: $removesExistingImage
                )
                FieldCard("Gift", text: $title, placeholder: "Gift name")
                FieldCard("Store", text: $store, placeholder: "Where you bought it")
                FieldCard("Price", text: $price, placeholder: "$74", keyboardType: .decimalPad)
                PickerCard(title: "Category", selection: $category, options: SampleData.categories)
                PickerCard(title: "Occasion", selection: $occasion, options: SampleData.occasions)
                PickerCard(title: "Reaction", selection: $reaction, options: ["Loved it", "Liked it", "Maybe", "Never again"])
                PrimaryActionButton(title: "Save Changes", symbol: "checkmark", isEnabled: !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                    storeModel.updateGift(
                        personID: personID,
                        giftID: gift.id,
                        title: title,
                        store: store,
                        price: price,
                        category: category,
                        occasion: occasion,
                        reaction: reaction,
                        replacementImageData: replacementImageData,
                        removeImage: removesExistingImage
                    )
                    dismiss()
                }
            }
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct UpcomingGiftsView: View {
    @EnvironmentObject private var store: GiftCompassStore

    private var sortedPeople: [GiftPerson] {
        store.people.sorted {
            ($0.nextBirthday ?? .distantFuture) < ($1.nextBirthday ?? .distantFuture)
        }
    }

    var body: some View {
        DetailScroll(title: "Birthdays") {
            if store.people.isEmpty {
                EmptyStateCard(title: "No birthdays yet", subtitle: "Add a person and their birthday will appear here.", symbol: "birthday.cake")
            }
            ForEach(sortedPeople) { person in
                SimpleItemCard(
                    title: person.name,
                    subtitle: "\(person.birthdayCountdown) • \(person.birthday)",
                    symbol: "birthday.cake.fill",
                    tint: person.tint
                )
            }
        }
    }
}

struct MyWishlistView: View {
    @EnvironmentObject private var store: GiftCompassStore
    @State private var isAdding = false
    @State private var newWish = ""
    @State private var editingIndex: Int?

    var body: some View {
        DetailScroll(title: "My Wishlist") {
            AddMiniCard(title: "Add Personal Wish", symbol: "plus") {
                isAdding = true
            }
            if store.myWishlist.isEmpty {
                EmptyStateCard(title: "Your wishlist is empty", subtitle: "Add something you would genuinely love to receive.", symbol: "star")
            }
            ForEach(Array(store.myWishlist.enumerated()), id: \.offset) { index, item in
                EditableTextRow(title: item, subtitle: "Personal wish", symbol: "star.fill", tint: GCColor.gold) {
                    newWish = item
                    editingIndex = index
                    isAdding = true
                } deleteAction: {
                    store.deleteMyWish(at: index)
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            NavigationStack {
                VStack(spacing: 16) {
                    FieldCard("Wish", text: $newWish, placeholder: "Projector")
                    PrimaryActionButton(title: "Save Personal Wish", symbol: "star.fill", isEnabled: !newWish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        if let editingIndex {
                            store.updateMyWish(at: editingIndex, title: newWish)
                        } else {
                            store.addMyWish(newWish)
                        }
                        newWish = ""
                        editingIndex = nil
                        isAdding = false
                    }
                    Spacer()
                }
                .contentMargins()
                .background(PremiumBackground())
                .navigationTitle("Add Wish")
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .onDisappear {
                newWish = ""
                editingIndex = nil
            }
        }
    }
}

struct FavoritesView: View {
    @EnvironmentObject private var store: GiftCompassStore

    var body: some View {
        DetailScroll(title: "Favorites") {
            let perfectIdeas = store.allIdeas.filter { $0.status == "Perfect" }
            if perfectIdeas.isEmpty {
                EmptyStateCard(title: "No favorites yet", subtitle: "Mark ideas as Perfect and they will appear here.", symbol: "pin.fill")
            } else {
                ForEach(perfectIdeas) { idea in
                    IdeaRow(idea: idea)
                }
            }
        }
    }
}
