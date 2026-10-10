import SwiftUI
import UIKit
import PhotosUI
import Foundation

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(
                LinearGradient(
                    colors: [GCColor.porcelain.opacity(0.98), GCColor.card.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [GCColor.cardHighlight.opacity(0.72), GCColor.champagne.opacity(0.42), GCColor.text.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.16), radius: 10, y: 5)
    }
}

struct DetailScroll<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                content
            }
            .contentMargins()
        }
        .scrollIndicators(.hidden)
        .background(PremiumBackground())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

struct FormShell<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        DetailScroll(title: title) {
            content
        }
    }
}

struct SectionHeader: View {
    let title: String
    let action: String?

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.weight(.heavy))
                .foregroundStyle(GCColor.text)
            Spacer()
            if let action {
                Text(action)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(GCColor.accent)
            }
        }
    }
}

struct EmptyStateCard: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(GCColor.text.opacity(0.36))
                    .frame(width: 70, height: 70)
                    .background(GCColor.text.opacity(0.08), in: Circle())
                Text(title)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(GCColor.text)
                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(GCColor.text.opacity(0.56))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
    }
}
