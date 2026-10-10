import SwiftUI
import UIKit
import PhotosUI
import Foundation

struct HeroSummaryCard: View {
    @EnvironmentObject private var store: GiftCompassStore

    private var noRepeatRate: Int {
        guard !store.allGifts.isEmpty else { return 100 }
        return Int((Double(store.allGifts.count - store.noRepeatGiftsCount) / Double(store.allGifts.count) * 100).rounded())
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [GCColor.ink, GCColor.action, GCColor.rosewood.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(GCColor.champagne.opacity(0.18), lineWidth: 34)
                .frame(width: 230, height: 230)
                .offset(x: 180, y: -92)

            Image(systemName: "sparkles")
                .font(.system(size: 88, weight: .bold))
                .foregroundStyle(GCColor.champagne.opacity(0.18))
                .offset(x: 245, y: 28)

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Private Gift CRM")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(GCColor.champagne)
                            .textCase(.uppercase)
                        Text("Never repeat.\nAlways surprise.")
                            .font(.system(size: 35, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineSpacing(2)
                            .minimumScaleFactor(0.82)
                    }
                    Spacer()
                    GiftBoxView(size: 86, ribbonColor: GCColor.accent, lidColor: GCColor.gold)
                        .shadow(color: GCColor.gold.opacity(0.32), radius: 22, y: 14)
                }

                Text("A curated memory base for people, ideas, budgets, wishes and moments.")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(3)

                HStack(spacing: 10) {
                    PremiumMicroMetric(value: "\(store.people.count)", label: "People")
                    PremiumMicroMetric(value: "\(store.allIdeas.count)", label: "Ideas")
                    PremiumMicroMetric(value: "\(noRepeatRate)%", label: "Unique")
                }
            }
            .padding(24)
        }
        .frame(minHeight: 286)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(LinearGradient(colors: [GCColor.champagne.opacity(0.75), .white.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: GCColor.primary.opacity(0.22), radius: 30, y: 22)
    }
}

struct PremiumMicroMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.weight(.heavy))
            Text(label)
                .font(.caption2.weight(.bold))
                .opacity(0.68)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
    }
}

struct ExecutiveMetricsCard: View {
    @EnvironmentObject private var store: GiftCompassStore

    private var peopleWithPlans: Int {
        store.people.filter { !$0.ideas.isEmpty || !$0.wishes.isEmpty }.count
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gift Portfolio")
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(GCColor.text)
                        Text("Coverage across people, wishes and budgets.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GCColor.text.opacity(0.55))
                    }
                    Spacer()
                    Image(systemName: "crown.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(GCColor.gold)
                        .frame(width: 42, height: 42)
                        .background(GCColor.gold.opacity(0.12), in: Circle())
                }

                HStack(spacing: 14) {
                    LuxuryMetric(title: "Ready", value: "\(peopleWithPlans)", subtitle: "people planned", tint: GCColor.success, progress: store.people.isEmpty ? 0 : Double(peopleWithPlans) / Double(store.people.count))
                    LuxuryMetric(title: "Perfect", value: "\(store.perfectIdeasCount)", subtitle: "ideas", tint: GCColor.gold, progress: store.allIdeas.isEmpty ? 0 : Double(store.perfectIdeasCount) / Double(store.allIdeas.count))
                    LuxuryMetric(title: "Avoid", value: "\(store.noRepeatGiftsCount)", subtitle: "no-repeat", tint: GCColor.accent, progress: store.allGifts.isEmpty ? 0 : Double(store.noRepeatGiftsCount) / Double(store.allGifts.count))
                }
            }
        }
    }
}

struct LuxuryMetric: View {
    let title: String
    let value: String
    let subtitle: String
    let tint: Color
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(GCColor.text.opacity(0.52))
                Spacer()
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
            }

            Text(value)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(GCColor.text)

            Text(subtitle)
                .font(.caption2.weight(.bold))
                .foregroundStyle(GCColor.text.opacity(0.50))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.12))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(8, proxy.size.width * progress))
                }
            }
            .frame(height: 5)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
        .background(GCColor.porcelain.opacity(0.82), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(GCColor.text.opacity(0.06), lineWidth: 1)
        )
    }
}

struct GiftIntelligenceCard: View {
    @EnvironmentObject private var store: GiftCompassStore

    private var quality: Double {
        guard !store.people.isEmpty else { return 0 }
        let scores = store.people.map { person in
            min(1, Double(person.ideas.count + person.wishes.count + person.gifts.count) / 8)
        }
        return scores.reduce(0, +) / Double(scores.count)
    }

    private var points: [GiftSignal] {
        let tints = [GCColor.primary, GCColor.success, GCColor.gold, GCColor.accent]
        return store.people.prefix(6).enumerated().map { index, person in
            GiftSignal(
                label: String(person.name.prefix(3)),
                value: max(1, person.ideas.count + person.wishes.count + person.gifts.count),
                tint: tints[index % tints.count]
            )
        }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Memory Quality")
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(GCColor.text)
                        Text("Signals from wishes, reactions, favorite brands and past gifts.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GCColor.text.opacity(0.56))
                    }
                    Spacer()
                    RingGauge(progress: quality, tint: GCColor.gold, value: "\(Int((quality * 100).rounded()))")
                        .frame(width: 72, height: 72)
                }

                if points.isEmpty {
                    Text("Add a person and save a wish, idea or gift to build memory quality.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GCColor.text.opacity(0.56))
                } else {
                    GiftSignalBars(points: points)
                        .frame(height: 132)
                }

                HStack(spacing: 10) {
                    SignalChip(title: "Best gifts", value: "\(store.allGifts.filter { $0.score == 5 }.count)", tint: GCColor.gold)
                    SignalChip(title: "Wishes", value: "\(store.people.flatMap(\.wishes).count)", tint: GCColor.success)
                    SignalChip(title: "Never again", value: "\(store.noRepeatGiftsCount)", tint: GCColor.accent)
                }
            }
        }
    }
}

struct GiftSignal: Identifiable {
    let id = UUID()
    let label: String
    let value: Int
    let tint: Color
}

struct GiftSignalBars: View {
    let points: [GiftSignal]

    private var maxValue: CGFloat {
        CGFloat(points.map(\.value).max() ?? 100)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(points) { point in
                VStack(spacing: 8) {
                    GeometryReader { proxy in
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [point.tint.opacity(0.92), point.tint.opacity(0.42)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: max(12, proxy.size.height * CGFloat(point.value) / maxValue))
                        }
                    }
                    Text(point.label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(GCColor.text.opacity(0.42))
                }
            }
        }
        .padding(.top, 4)
    }
}

struct SignalChip: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(GCColor.text.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .padding(.horizontal, 8)
        .background(tint.opacity(0.10), in: Capsule())
    }
}

struct SurpriseIdeaPreview: View {
    let idea: GiftIdea

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: idea.symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(idea.tint, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(idea.title)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(GCColor.text)
                        .lineLimit(1)
                    Text(idea.status)
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(idea.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(idea.tint.opacity(0.12), in: Capsule())
                }
                Text(idea.reason)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GCColor.text.opacity(0.58))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(GCColor.card.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(GCColor.cardHighlight.opacity(0.55), lineWidth: 1)
        )
    }
}

struct NavigationLinkCard<Destination: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let destination: Destination

    init(title: String, subtitle: String, symbol: String, tint: Color, @ViewBuilder destination: () -> Destination) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tint = tint
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: symbol)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(tint, in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(GCColor.text)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                        Text(subtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GCColor.text.opacity(0.55))
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
    }
}

struct FeatureGrid: View {
    let items: [FeatureItem]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            ForEach(items) { item in
                NavigationLink {
                    item.destination
                } label: {
                    SimpleTile(title: item.title, subtitle: item.subtitle, symbol: item.symbol, tint: item.tint)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct FeatureItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let destination: AnyView

    init(_ title: String, _ subtitle: String, _ symbol: String, _ tint: Color, _ destination: AnyView) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tint = tint
        self.destination = destination
    }
}

struct SimpleTile: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.13), in: Circle())
                Text(title)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(GCColor.text)
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GCColor.text.opacity(0.55))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        }
    }
}

struct PersonRow: View {
    let person: GiftPerson

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(person.tint.opacity(0.22), lineWidth: 8)
                        .frame(width: 74, height: 74)
                    AvatarView(name: person.name, tint: person.tint, size: 60, imageFileName: person.imageFileName)
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(person.name)
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(GCColor.text)
                        Image(systemName: "sparkle")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(GCColor.gold)
                    }
                    Text("\(person.relationship) • \(person.birthday)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GCColor.text.opacity(0.56))
                    HStack(spacing: 8) {
                        Label("\(person.gifts.count)", systemImage: "gift.fill")
                        Label("\(person.ideas.count)", systemImage: "lightbulb.fill")
                        Label("\(person.wishes.count)", systemImage: "heart.fill")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(GCColor.text.opacity(0.48))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(GCColor.text.opacity(0.26))
            }
        }
    }
}

struct TimelineGiftRow: View {
    let gift: GiftRecord

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                MediaThumbnail(imageFileName: gift.imageFileName, symbol: gift.symbol, tint: gift.tint)
                VStack(alignment: .leading, spacing: 5) {
                    Text(gift.year)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(GCColor.text.opacity(0.48))
                    Text(gift.title)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(GCColor.text)
                    Text("\(gift.occasion) • \(gift.price)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GCColor.text.opacity(0.55))
                }
                Spacer()
                ScoreStars(score: gift.score)
            }
        }
    }
}

struct IdeaRow: View {
    let idea: GiftIdea
    let ownerName: String?

    init(idea: GiftIdea, ownerName: String? = nil) {
        self.idea = idea
        self.ownerName = ownerName
    }

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                MediaThumbnail(imageFileName: idea.imageFileName, symbol: idea.symbol, tint: idea.tint)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(idea.title)
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(GCColor.text)
                        Spacer()
                        Text(idea.status)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(idea.tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(idea.tint.opacity(0.12), in: Capsule())
                    }
                    Text(ownerName.map { "\($0) • \(idea.reason)" } ?? idea.reason)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GCColor.text.opacity(0.55))
                        .lineLimit(2)
                    Text(idea.price)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(GCColor.text.opacity(0.44))
                }
            }
        }
    }
}

struct TimelinePreviewCard: View {
    @EnvironmentObject private var store: GiftCompassStore

    private var upcomingPeople: [GiftPerson] {
        store.people.sorted {
            ($0.nextBirthday ?? .distantFuture) < ($1.nextBirthday ?? .distantFuture)
        }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Saved Birthdays", action: "View all")
                if store.people.isEmpty {
                    Text("Add someone to start a private birthday timeline.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GCColor.text.opacity(0.56))
                }
                ForEach(upcomingPeople.prefix(2)) { person in
                    HStack(spacing: 12) {
                        Image(systemName: "birthday.cake.fill")
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(person.tint, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(person.name)
                                .font(.headline.weight(.heavy))
                            Text("\(person.birthdayCountdown) • \(person.birthday)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(GCColor.text.opacity(0.54))
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}

struct UpcomingEventRow: View {
    let event: UpcomingEvent
    var embedded = false

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 5) {
                Circle()
                    .fill(event.tint)
                    .frame(width: 13, height: 13)
                Rectangle()
                    .fill(GCColor.text.opacity(0.12))
                    .frame(width: 2, height: embedded ? 28 : 42)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(event.when)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(event.tint)
                Text(event.person)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(GCColor.text)
                Text(event.occasion)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GCColor.text.opacity(0.56))
            }
            Spacer()
            Image(systemName: event.symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(event.tint, in: Circle())
        }
        .padding(embedded ? 0 : 18)
        .modifier(EmbeddedTimelineBackground(isEmbedded: embedded))
    }
}

struct EmbeddedTimelineBackground: ViewModifier {
    let isEmbedded: Bool

    func body(content: Content) -> some View {
        if isEmbedded {
            content
        } else {
            content
                .background(GCColor.porcelain.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
    }
}

struct OccasionCard: View {
    let title: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: SampleData.occasionSymbol(title))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(GCColor.accent)
                Text(title)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(GCColor.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        }
    }
}

struct CollectionRow: View {
    let collection: GiftCollection

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: collection.symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(collection.tint, in: Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(collection.title)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(GCColor.text)
                    Text("\(collection.ideas.count) ideas")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GCColor.text.opacity(0.56))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(GCColor.text.opacity(0.28))
            }
        }
    }
}

struct BestGiftsStrip: View {
    @EnvironmentObject private var store: GiftCompassStore

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                let bestGifts = store.allGifts.filter { $0.score == 5 }
                if bestGifts.isEmpty {
                    Text("Add a loved gift to start your highlights.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GCColor.text.opacity(0.56))
                        .padding(.vertical, 12)
                }
                ForEach(bestGifts) { gift in
                    GiftMiniCard(gift: gift)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
    }
}

struct NeverAgainStrip: View {
    @EnvironmentObject private var store: GiftCompassStore

    var body: some View {
        HStack(spacing: 10) {
            let avoided = store.allGifts.filter(\.doNotRepeat)
            if avoided.isEmpty {
                Text("No gifts marked as “Never again”.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GCColor.text.opacity(0.56))
            }
            ForEach(avoided) { gift in
                Text(gift.title)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(GCColor.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(GCColor.accent.opacity(0.12), in: Capsule())
            }
            Spacer()
        }
    }
}

struct MediaThumbnail: View {
    let imageFileName: String?
    let symbol: String
    let tint: Color
    var size: CGFloat = 54

    var body: some View {
        Group {
            if let image = ImageStorage.load(imageFileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(tint)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).stroke(GCColor.cardHighlight.opacity(0.65), lineWidth: 1))
    }
}

struct EditableTextRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let editAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(tint, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(GCColor.text)
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GCColor.text.opacity(0.54))
                }
                Spacer()
                Menu {
                    Button("Edit", systemImage: "pencil", action: editAction)
                    Button("Delete", systemImage: "trash", role: .destructive, action: deleteAction)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(GCColor.text.opacity(0.5))
                }
            }
        }
    }
}

struct GiftMiniCard: View {
    let gift: GiftRecord

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [GCColor.porcelain, gift.tint.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "sparkle")
                .font(.title3.weight(.bold))
                .foregroundStyle(GCColor.gold.opacity(0.55))
                .padding(14)

            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: gift.symbol)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        LinearGradient(colors: [gift.tint, GCColor.ink.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
                Text(gift.title)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(GCColor.text)
                    .lineLimit(1)
                ScoreStars(score: gift.score)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 172, height: 148)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(GCColor.cardHighlight.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: GCColor.primary.opacity(0.08), radius: 16, y: 10)
    }
}

struct SettingsProfileCard: View {
    var body: some View {
        GlassCard {
            HStack(spacing: 16) {
                AvatarView(name: "You", tint: GCColor.primary, size: 66)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Your gift memory")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(GCColor.text)
                    Text("Wishlist, history, exports and reminders.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GCColor.text.opacity(0.56))
                }
                Spacer()
            }
        }
    }
}

struct SettingsLink<Destination: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let destination: Destination

    init(title: String, subtitle: String, symbol: String, tint: Color, @ViewBuilder destination: () -> Destination) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tint = tint
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            GlassCard {
                HStack(spacing: 14) {
                    Image(systemName: symbol)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(tint, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(GCColor.text)
                        Text(subtitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GCColor.text.opacity(0.56))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(GCColor.text.opacity(0.28))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct SimpleItemCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    var compact = false

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: compact ? 42 : 50, height: compact ? 42 : 50)
                    .background(tint, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(GCColor.text)
                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GCColor.text.opacity(0.56))
                        .lineLimit(2)
                }
                Spacer()
            }
        }
    }
}

struct CategoryCard: View {
    let title: String

    var body: some View {
        SimpleTile(title: title, subtitle: "Saved ideas", symbol: SampleData.categorySymbol(title), tint: SampleData.categoryTint(title))
    }
}

struct KeyValueRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(GCColor.text.opacity(0.48))
            Spacer(minLength: 16)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(GCColor.text)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct WarningCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(GCColor.accent, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.heavy))
                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.62)
            }
            Spacer()
        }
        .foregroundStyle(GCColor.text)
        .padding(18)
        .background(GCColor.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title2.weight(.heavy))
            Text(label)
                .font(.caption.weight(.bold))
                .opacity(0.56)
        }
        .foregroundStyle(GCColor.text)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(GCColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
