import SwiftUI
import UIKit
import PhotosUI
import Foundation

struct PersonHero: View {
    let person: GiftPerson

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [GCColor.ink, person.tint.opacity(0.92), GCColor.rosewood.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .stroke(GCColor.champagne.opacity(0.18), lineWidth: 30)
                .frame(width: 210, height: 210)
                .offset(x: 190, y: -82)
            Image(systemName: "gift.fill")
                .font(.system(size: 160, weight: .bold))
                .foregroundStyle(.white.opacity(0.07))
                .offset(x: 104, y: -42)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    AvatarView(name: person.name, tint: .white.opacity(0.25), size: 96, imageFileName: person.imageFileName)
                        .overlay(Circle().stroke(GCColor.champagne.opacity(0.78), lineWidth: 2))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        Text("Gift Score")
                            .font(.caption2.weight(.heavy))
                            .opacity(0.64)
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                            Text("4.7")
                        }
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(GCColor.champagne)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(person.name)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                    Text("\(person.relationship) • Birthday \(person.birthday)")
                        .font(.headline.weight(.semibold))
                        .opacity(0.78)
                }

                HStack(spacing: 9) {
                    PremiumMicroMetric(value: "\(person.ideas.count)", label: "Ideas")
                    PremiumMicroMetric(value: "\(person.wishes.count)", label: "Wishes")
                    PremiumMicroMetric(value: "\(person.brands.count)", label: "Brands")
                }
            }
            .foregroundStyle(.white)
            .padding(24)
        }
        .frame(height: 330)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(GCColor.champagne.opacity(0.52), lineWidth: 1)
        )
        .shadow(color: person.tint.opacity(0.26), radius: 30, y: 20)
    }
}

struct GiftRelationshipTimeline: View {
    let person: GiftPerson

    private var moments: [TimelineMoment] {
        let giftMoments = person.gifts.map { gift in
            TimelineMoment(year: gift.year, title: gift.occasion)
        }
        let personalMoments = person.relationshipTimeline.filter { moment in
            !SampleData.occasions.contains(moment.title)
        }
        return giftMoments + personalMoments
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Gift Timeline", action: nil)
                if moments.isEmpty {
                    Text("Add a gift to begin this timeline.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GCColor.text.opacity(0.52))
                }
                ForEach(Array(moments.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 5) {
                            Circle()
                                .fill(index == 0 ? GCColor.accent : GCColor.gold)
                                .frame(width: 12, height: 12)
                            if index != moments.count - 1 {
                                Rectangle()
                                    .fill(GCColor.text.opacity(0.16))
                                    .frame(width: 2, height: 30)
                            }
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.year)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(GCColor.text.opacity(0.48))
                            Text(item.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(GCColor.text)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}

struct SurpriseBoxCard: View {
    @EnvironmentObject private var store: GiftCompassStore
    @State private var selectedIdeaID: UUID?

    private var idea: GiftIdea? {
        store.allIdeas.first { $0.id == selectedIdeaID } ?? store.allIdeas.first
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [GCColor.porcelain, GCColor.champagne.opacity(0.55), GCColor.accent.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .stroke(GCColor.gold.opacity(0.18), lineWidth: 26)
                .frame(width: 170, height: 170)
                .offset(x: 66, y: -66)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Surprise Box")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(GCColor.text)
                        Text("One premium idea from your private base.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GCColor.text.opacity(0.56))
                    }
                    Spacer()
                    GiftBoxView(size: 60, ribbonColor: GCColor.accent, lidColor: GCColor.gold)
                }

                if let idea {
                    SurpriseIdeaPreview(idea: idea)
                } else {
                    EmptyStateCard(title: "Your surprise box is empty", subtitle: "Save an idea to start getting thoughtful picks.", symbol: "gift")
                }

                Button {
                    haptic(.rigid)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.76)) {
                        selectedIdeaID = store.allIdeas.randomElement()?.id
                    }
                } label: {
                    Label("Surprise Me", systemImage: "gift.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(colors: [GCColor.ink, GCColor.accent], startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
                .disabled(store.allIdeas.isEmpty)
                .opacity(store.allIdeas.isEmpty ? 0.45 : 1)
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(GCColor.cardHighlight.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: GCColor.accent.opacity(0.16), radius: 26, y: 18)
    }
}

struct SurpriseSheet: View {
    let person: GiftPerson
    @State private var ideaIndex = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            GiftBoxView(size: 110, ribbonColor: GCColor.accent, lidColor: GCColor.gold)
            if person.ideas.isEmpty {
                VStack(spacing: 10) {
                    Text("No ideas yet")
                        .font(.largeTitle.weight(.heavy))
                    Text("Save a few ideas for \(person.name), then come back for a surprise pick.")
                        .font(.headline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(GCColor.text.opacity(0.6))
                }
                .padding(.horizontal, 26)
            } else {
                let safeIndex = min(ideaIndex, person.ideas.count - 1)
                VStack(spacing: 10) {
                    Text(person.ideas[safeIndex].title)
                        .font(.largeTitle.weight(.heavy))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(GCColor.text)
                    Text(person.ideas[safeIndex].reason)
                        .font(.headline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(GCColor.text.opacity(0.6))
                }
                .padding(.horizontal, 26)
                Button {
                    haptic(.medium)
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                        ideaIndex = (safeIndex + 1) % person.ideas.count
                    }
                } label: {
                    Label("Surprise Me", systemImage: "sparkles")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(GCColor.action, in: Capsule())
                .padding(.horizontal, 26)
            }
            Spacer()
        }
        .background(PremiumBackground())
    }
}

struct PhotoHeader: View {
    let symbol: String
    let tint: Color
    let imageFileName: String?

    init(symbol: String, tint: Color, imageFileName: String? = nil) {
        self.symbol = symbol
        self.tint = tint
        self.imageFileName = imageFileName
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [tint.opacity(0.9), GCColor.action.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let image = ImageStorage.load(imageFileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .overlay(LinearGradient(colors: [.clear, GCColor.ink.opacity(0.22)], startPoint: .top, endPoint: .bottom))
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 92, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(height: 220)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: tint.opacity(0.18), radius: 20, y: 12)
    }
}

struct AvatarView: View {
    let name: String
    let tint: Color
    let size: CGFloat
    let imageFileName: String?

    init(name: String, tint: Color, size: CGFloat, imageFileName: String? = nil) {
        self.name = name
        self.tint = tint
        self.size = size
        self.imageFileName = imageFileName
    }

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }

    var body: some View {
        Group {
            if let image = ImageStorage.load(imageFileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(initials)
                    .font(.system(size: size * 0.34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(tint)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: tint.opacity(0.22), radius: 10, y: 6)
    }
}

struct ScoreStars: View {
    let score: Int

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < score ? "star.fill" : "star")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(GCColor.gold)
            }
        }
    }
}

struct TagWrap: View {
    let tags: [String]
    let tint: Color

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(tint.opacity(0.12), in: Capsule())
            }
        }
    }
}

struct GiftBoxView: View {
    let size: CGFloat
    let ribbonColor: Color
    let lidColor: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.13, style: .continuous)
                .fill(GCColor.action)
                .frame(width: size * 0.78, height: size * 0.62)
                .offset(y: size * 0.12)
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .fill(lidColor)
                .frame(width: size * 0.92, height: size * 0.24)
                .offset(y: -size * 0.19)
            Rectangle()
                .fill(ribbonColor)
                .frame(width: size * 0.17, height: size * 0.78)
                .offset(y: size * 0.08)
            Rectangle()
                .fill(ribbonColor)
                .frame(width: size * 0.92, height: size * 0.14)
                .offset(y: -size * 0.19)
            HStack(spacing: -size * 0.05) {
                RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                    .stroke(ribbonColor, lineWidth: size * 0.08)
                    .frame(width: size * 0.28, height: size * 0.2)
                    .rotationEffect(.degrees(-24))
                RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                    .stroke(ribbonColor, lineWidth: size * 0.08)
                    .frame(width: size * 0.28, height: size * 0.2)
                    .rotationEffect(.degrees(24))
            }
            .offset(y: -size * 0.39)
        }
        .frame(width: size, height: size)
    }
}

struct PeopleCardsVisual: View {
    private let items = [("Friends", GCColor.accent), ("Family", GCColor.success), ("Coworkers", GCColor.primary), ("Partner", GCColor.gold)]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack {
                    AvatarView(name: item.0, tint: item.1, size: 44)
                    Text(item.0)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(GCColor.text)
                    Spacer()
                }
                .padding(14)
                .frame(width: 220)
                .background(GCColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .rotationEffect(.degrees(index.isMultiple(of: 2) ? -2 : 2))
            }
        }
    }
}

struct TimelineVisual: View {
    let items: [String]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Text(item)
                    .font(.title.weight(.heavy))
                    .foregroundStyle(index == items.count - 1 ? GCColor.accent : GCColor.text)
                if index != items.count - 1 {
                    Image(systemName: "arrow.down")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(GCColor.text.opacity(0.28))
                }
            }
        }
        .padding(26)
        .background(GCColor.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

struct StackedFlowVisual: View {
    let items: [String]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack {
                    Text(item)
                        .font(.headline.weight(.heavy))
                    Spacer()
                    Image(systemName: "chevron.down")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .frame(width: 214)
                .background([GCColor.action, GCColor.accent, GCColor.success, GCColor.gold][index], in: Capsule())
            }
        }
    }
}

struct NotificationPermissionVisual: View {
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 62, weight: .bold))
                .foregroundStyle(GCColor.gold)
                .frame(width: 130, height: 130)
                .background(GCColor.card, in: Circle())
            SimpleItemCard(title: "Notifications", subtitle: "Birthday reminders", symbol: "calendar.badge.clock", tint: GCColor.accent, compact: true)
                .frame(width: 260)
        }
    }
}

// MARK: - Layout Helpers

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

extension View {
    func contentMargins() -> some View {
        padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
    }
}
