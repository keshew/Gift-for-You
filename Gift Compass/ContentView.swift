//
//  ContentView.swift
//  Gift Compass
//
//  Created by Artem Korotkov on 18.07.2026.
//

import SwiftUI

struct ContentView: View {
    @AppStorage(OnboardingStorage.completedKey) private var hasCompletedOnboarding = false
    @AppStorage("giftForYou.appearance") private var appearance = AppTheme.system.rawValue
    @StateObject private var store = GiftCompassStore()
    @State private var phase: AppPhase = .splash
    @State private var selectedTab: GiftTab = .home
    @State private var onboardingPage = 0

    init(startAtNativeContent: Bool = false) {
        let initialPhase: AppPhase = startAtNativeContent
            ? (OnboardingStorage.isCompleted ? .main : .onboarding)
            : .splash
        _phase = State(initialValue: initialPhase)
    }

    var body: some View {
        ZStack {
            PremiumBackground()

            switch phase {
            case .splash:
                SplashView()
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            case .loading:
                LoadingView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingView(page: $onboardingPage) {
                    completeOnboarding()
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case .main:
                MainTabView(selectedTab: $selectedTab)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }
        }
        .tint(GCColor.accent)
        .preferredColorScheme(AppTheme(rawValue: appearance)?.colorScheme)
        .environmentObject(store)
        .onAppear(perform: boot)
    }

    private func boot() {
        guard phase == .splash else { return }
        _ = ClientIdentity.current
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.easeInOut(duration: 0.5)) {
                phase = .loading
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.25) {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.84)) {
                phase = OnboardingStorage.isCompleted ? .main : .onboarding
            }
        }
    }

    private func completeOnboarding() {
        haptic(.medium)
        OnboardingStorage.markCompleted()
        hasCompletedOnboarding = true
        Task {
            let granted = await NotificationManager.requestAndSchedule(for: store.people)
            UserDefaults.standard.set(granted, forKey: NotificationManager.settingKey)
            withAnimation(.spring(response: 0.7, dampingFraction: 0.86)) {
                phase = .main
            }
        }
    }
}

#Preview {
    ContentView()
}
