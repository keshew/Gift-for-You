import SwiftUI
import UIKit
import PhotosUI
import Foundation

struct SplashView: View {
    @State private var float = false

    var body: some View {
        VStack(spacing: 22) {
            GiftBoxView(size: 126, ribbonColor: GCColor.accent, lidColor: GCColor.gold)
                .rotationEffect(.degrees(float ? 3 : -3))
                .offset(y: float ? -8 : 8)
                .shadow(color: GCColor.gold.opacity(0.26), radius: 24, y: 16)

            VStack(spacing: 8) {
                Text("Gift for You")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(GCColor.text)
                Text("Never repeat. Always surprise.")
                    .font(.headline)
                    .foregroundStyle(GCColor.text.opacity(0.62))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                float.toggle()
            }
        }
    }
}

struct LoadingView: View {
    private let captions = ["Remembering memories...", "Finding ideas...", "Preparing surprises..."]
    @State private var rotation = 0.0
    @State private var captionIndex = 0

    var body: some View {
        VStack(spacing: 26) {
            GiftBoxView(size: 94, ribbonColor: GCColor.accent, lidColor: GCColor.gold)
                .rotation3DEffect(.degrees(rotation), axis: (x: 0.3, y: 1, z: 0))
                .shadow(color: GCColor.accent.opacity(0.22), radius: 20, y: 14)

            Text(captions[captionIndex])
                .font(.title3.weight(.semibold))
                .foregroundStyle(GCColor.text)
                .contentTransition(.opacity)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.22)) {
                    captionIndex = (captionIndex + 1) % captions.count
                }
            }
        }
    }
}

struct OnboardingView: View {
    @Binding var page: Int
    let start: () -> Void

    private let pages = OnboardingPage.samples

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    OnboardingPageView(page: item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? GCColor.primary : GCColor.primary.opacity(0.16))
                        .frame(width: index == page ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
                }
            }
            .padding(.bottom, 24)

            Button {
                haptic(.light)
                if page == pages.count - 1 {
                    start()
                } else {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                        page += 1
                    }
                }
            } label: {
                Label(page == pages.count - 1 ? "Start Organizing" : "Continue",
                      systemImage: page == pages.count - 1 ? "sparkles" : "arrow.right")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(GCColor.action, in: Capsule())
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 12)

            ZStack {
                Circle()
                    .fill(GCColor.card.opacity(0.72))
                    .frame(width: 250, height: 250)

                page.visual
            }
            .frame(height: 300)

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(GCColor.text)
                    .lineSpacing(1)

                if !page.subtitle.isEmpty {
                    Text(page.subtitle)
                        .font(.title3.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(GCColor.text.opacity(0.62))
                        .lineSpacing(5)
                }
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 14)
        }
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let visual: AnyView

    static let samples: [OnboardingPage] = [
        OnboardingPage(
            title: "Never Forget\na Great Gift",
            subtitle: "Track gifts, save ideas,\nand surprise people every year.",
            visual: AnyView(GiftBoxView(size: 158, ribbonColor: GCColor.accent, lidColor: GCColor.gold))
        ),
        OnboardingPage(
            title: "Everything About Everyone",
            subtitle: "",
            visual: AnyView(PeopleCardsVisual())
        ),
        OnboardingPage(
            title: "Never Give\nThe Same Gift Twice",
            subtitle: "",
            visual: AnyView(TimelineVisual(items: ["2021", "2023", "2025"]))
        ),
        OnboardingPage(
            title: "One Place\nFor Every Gift",
            subtitle: "",
            visual: AnyView(StackedFlowVisual(items: ["Wishlist", "Ideas", "History", "Occasions"]))
        ),
        OnboardingPage(
            title: "Photos That\nStay Private",
            subtitle: "Attach visual inspiration. Your people, ideas and photos stay on this device.",
            visual: AnyView(OnboardingSymbolVisual(symbol: "lock.shield.fill", tint: GCColor.success))
        ),
        OnboardingPage(
            title: "Ready for\nEvery Occasion",
            subtitle: "Filter ideas, track reactions and export a complete personal backup whenever you need it.",
            visual: AnyView(StackedFlowVisual(items: ["Plan", "Choose", "Give", "Remember"]))
        ),
        OnboardingPage(
            title: "Never Miss\nthe Moment",
            subtitle: "Enable a private reminder one day before each saved birthday.",
            visual: AnyView(NotificationPermissionVisual())
        )
    ]
}

struct OnboardingSymbolVisual: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 82, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 190, height: 190)
            .background(GCColor.card.opacity(0.9), in: Circle())
            .overlay(Circle().stroke(tint.opacity(0.18), lineWidth: 14))
            .shadow(color: tint.opacity(0.2), radius: 24, y: 14)
    }
}

// MARK: - Tabs
