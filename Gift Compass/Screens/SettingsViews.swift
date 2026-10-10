import SwiftUI
import UIKit
import PhotosUI
import Foundation
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: GiftCompassStore

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    SettingsProfileCard()

                    AppearancePickerCard()

                    SettingsLink(title: "My Wishlist", subtitle: "Shareable ideas for friends", symbol: "star.fill", tint: GCColor.gold) {
                        MyWishlistView()
                    }
                    SettingsLink(title: "Favorites", subtitle: "Pinned ideas", symbol: "pin.fill", tint: GCColor.success) {
                        FavoritesView()
                    }
                    SettingsLink(title: "Statistics", subtitle: "People, ideas and budgets", symbol: "chart.pie.fill", tint: GCColor.primary) {
                        StatisticsView()
                    }
                    SettingsLink(title: "Export", subtitle: "PDF, CSV, JSON, backup", symbol: "square.and.arrow.up.fill", tint: GCColor.primary) {
                        ExportView()
                    }
                    BirthdayReminderCard()
                    SettingsLink(title: "Data & Backup", subtitle: "Import or erase local data", symbol: "externaldrive.badge.icloud", tint: GCColor.accent) {
                        DataManagementView()
                    }

                    GlassCard {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "lock.shield.fill")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(GCColor.success)
                                .frame(width: 48, height: 48)
                                .background(GCColor.success.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 5) {
                                Text("About Gift for You")
                                    .foregroundStyle(GCColor.text)
                                    .font(.headline.weight(.heavy))
                                Text("Your people, ideas and photos stay on this device. No account is required.")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(GCColor.text.opacity(0.56))
                                Text("Version 1.0")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(GCColor.text.opacity(0.42))
                            }
                        }
                    }
                }
                .contentMargins()
            }
            .scrollIndicators(.hidden)
            .background(PremiumBackground())
            .navigationTitle("Settings")
        }
    }
}

struct AppearancePickerCard: View {
    @AppStorage("giftForYou.appearance") private var appearance = AppTheme.system.rawValue

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Appearance", systemImage: "circle.lefthalf.filled")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(GCColor.text)
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

// MARK: - Detail Screens

struct ExportView: View {
    @EnvironmentObject private var store: GiftCompassStore

    var body: some View {
        DetailScroll(title: "Export") {
            ForEach(ExportKind.allCases, id: \.self) { kind in
                if let fileURL = store.exportURL(kind: kind) {
                    ShareLink(item: fileURL, preview: SharePreview("Gift for You \(kind.rawValue)")) {
                        SimpleItemCard(title: kind.rawValue, subtitle: kind.subtitle, symbol: kind.symbol, tint: GCColor.primary)
                    }
                    .buttonStyle(.plain)
                } else {
                    SimpleItemCard(title: kind.rawValue, subtitle: "Could not prepare this export", symbol: "exclamationmark.triangle.fill", tint: GCColor.accent)
                }
            }
        }
    }
}

struct QuickAddView: View {
    @EnvironmentObject private var store: GiftCompassStore

    var body: some View {
        DetailScroll(title: "Quick Add") {
            NavigationLink {
                AddPersonView()
            } label: {
                SimpleItemCard(title: "Person", subtitle: "Name, birthday, relationship", symbol: "person.badge.plus", tint: GCColor.primary)
            }
            .buttonStyle(.plain)

            if let firstPerson = store.firstPerson {
                NavigationLink {
                    AddGiftView(person: firstPerson)
                } label: {
                    SimpleItemCard(title: "Gift", subtitle: "Photo, price, reaction", symbol: "gift.fill", tint: GCColor.accent)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    IdeaVaultView(person: firstPerson)
                } label: {
                    SimpleItemCard(title: "Idea", subtitle: "Why it fits, tags, budget", symbol: "lightbulb.fill", tint: GCColor.gold)
                }
                .buttonStyle(.plain)
            }

            NavigationLink {
                OccasionsView()
            } label: {
                SimpleItemCard(title: "Occasion", subtitle: "Birthday, wedding, holiday", symbol: "calendar.badge.plus", tint: GCColor.success)
            }
            .buttonStyle(.plain)
        }
    }
}

struct BirthdayReminderCard: View {
    @EnvironmentObject private var store: GiftCompassStore
    @AppStorage(NotificationManager.settingKey) private var isEnabled = false
    @State private var isRequesting = false

    var body: some View {
        GlassCard {
            Toggle(isOn: Binding(
                get: { isEnabled },
                set: { newValue in
                    if newValue {
                        isRequesting = true
                        Task {
                            let granted = await NotificationManager.requestAndSchedule(for: store.people)
                            isEnabled = granted
                            isRequesting = false
                        }
                    } else {
                        isEnabled = false
                        NotificationManager.disable()
                    }
                }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Birthday Reminders")
                            .font(.headline.weight(.heavy))
                        Text(isRequesting ? "Requesting permission…" : "One day before at 10:00")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GCColor.text.opacity(0.52))
                    }
                } icon: {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(GCColor.accent)
                }
            }
            .disabled(isRequesting || store.people.isEmpty)
            .tint(GCColor.success)
        }
    }
}

struct DataManagementView: View {
    @EnvironmentObject private var store: GiftCompassStore
    @State private var isImporting = false
    @State private var confirmsReset = false
    @State private var resultMessage: String?

    var body: some View {
        DetailScroll(title: "Data & Backup") {
            Button {
                isImporting = true
            } label: {
                SimpleItemCard(title: "Import Backup", subtitle: "Restore a Gift for You backup JSON file", symbol: "square.and.arrow.down.fill", tint: GCColor.success)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                confirmsReset = true
            } label: {
                SimpleItemCard(title: "Erase All Data", subtitle: "Remove people, ideas, gifts and photos", symbol: "trash.fill", tint: GCColor.accent)
            }
            .buttonStyle(.plain)

            if let resultMessage {
                GlassCard {
                    Text(resultMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GCColor.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                try store.importBackup(Data(contentsOf: url))
                resultMessage = "Backup imported successfully."
            } catch {
                resultMessage = error.localizedDescription
            }
        }
        .confirmationDialog("Erase all local data?", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("Erase Everything", role: .destructive) {
                store.resetAllData()
                resultMessage = "All local data was erased."
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This cannot be undone unless you exported a backup first.")
        }
    }
}

// MARK: - Components

struct GlobalSearchView: View {
    @EnvironmentObject private var store: GiftCompassStore
    @State private var query = ""
    private var results: [SearchResult] {
        store.search(query)
    }

    var body: some View {
        DetailScroll(title: "Search") {
            SearchField(text: $query)
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ForEach(["People", "Ideas", "History", "Wishlist", "Occasions"], id: \.self) { area in
                    SimpleItemCard(title: area, subtitle: "Search \(area.lowercased()) instantly", symbol: "magnifyingglass", tint: GCColor.primary)
                }
            } else if results.isEmpty {
                EmptyStateCard(title: "Nothing found", subtitle: "Try a person, gift, idea, wish or occasion.", symbol: "magnifyingglass")
            } else {
                ForEach(results) { result in
                    NavigationLink {
                        searchDestination(for: result.target)
                    } label: {
                        SimpleItemCard(title: result.title, subtitle: result.subtitle, symbol: result.symbol, tint: result.tint)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func searchDestination(for target: SearchTarget) -> some View {
        switch target {
        case .person(let personID):
            if let person = store.people.first(where: { $0.id == personID }) {
                PersonProfileView(person: person)
            } else {
                EmptyStateCard(title: "Person not found", subtitle: "This item may have been removed.", symbol: "person.crop.circle.badge.questionmark")
            }
        case .gift(let personID, let giftID):
            GiftDetailsView(personID: personID, giftID: giftID)
        case .idea(let personID, let ideaID):
            IdeaDetailsView(personID: personID, ideaID: ideaID)
        case .wishlist(let personID):
            if let person = store.people.first(where: { $0.id == personID }) {
                WishlistView(person: person)
            } else {
                EmptyStateCard(title: "Wishlist not found", subtitle: "This person may have been removed.", symbol: "heart.slash")
            }
        }
    }
}

struct StatisticsView: View {
    @EnvironmentObject private var store: GiftCompassStore

    private var coverage: Double {
        guard !store.people.isEmpty else { return 0 }
        let ready = store.people.filter { !$0.ideas.isEmpty || !$0.wishes.isEmpty || !$0.gifts.isEmpty }.count
        return Double(ready) / Double(store.people.count)
    }

    var body: some View {
        DetailScroll(title: "Statistics") {
            GlassCard {
                HStack(spacing: 20) {
                    RingGauge(progress: coverage, tint: GCColor.gold, value: "\(Int((coverage * 100).rounded()))")
                        .frame(width: 104, height: 104)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Gift readiness")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(GCColor.text)
                        Text("Based on people with at least one saved idea, wish or past gift.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GCColor.text.opacity(0.56))
                    }
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                StatCircle(value: "\(store.people.count)", label: "People", progress: min(1, Double(store.people.count) / 10), tint: GCColor.primary)
                StatCircle(value: "\(store.allIdeas.count)", label: "Ideas", progress: min(1, Double(store.allIdeas.count) / 20), tint: GCColor.accent)
                StatCircle(value: "\(store.allGifts.count)", label: "Gifts Given", progress: min(1, Double(store.allGifts.count) / 20), tint: GCColor.success)
                StatCircle(value: "$\(Int(store.averageBudget.rounded()))", label: "Average Budget", progress: min(1, store.averageBudget / 200), tint: GCColor.gold)
            }
            SectionHeader(title: "People coverage", action: nil)
            ForEach(store.people) { person in
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(person.name)
                                .font(.headline.weight(.heavy))
                            Spacer()
                            Text("\(person.ideas.count) ideas • \(person.gifts.count) gifts")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(GCColor.text.opacity(0.5))
                        }
                        CoverageBar(progress: min(1, Double(person.ideas.count + person.wishes.count + person.gifts.count) / 8), tint: person.tint)
                            .frame(height: 8)
                    }
                }
            }
        }
    }
}
