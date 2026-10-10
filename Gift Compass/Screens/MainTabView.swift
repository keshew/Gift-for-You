import SwiftUI
import UIKit
import PhotosUI
import Foundation

struct MainTabView: View {
    @Binding var selectedTab: GiftTab

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label(GiftTab.home.rawValue, systemImage: GiftTab.home.symbol) }
                .tag(GiftTab.home)

            PeopleListView()
                .tabItem { Label(GiftTab.people.rawValue, systemImage: GiftTab.people.symbol) }
                .tag(GiftTab.people)

            IdeasHubView()
                .tabItem { Label(GiftTab.ideas.rawValue, systemImage: GiftTab.ideas.symbol) }
                .tag(GiftTab.ideas)

            OccasionsView()
                .tabItem { Label(GiftTab.occasions.rawValue, systemImage: GiftTab.occasions.symbol) }
                .tag(GiftTab.occasions)

            SettingsView()
                .tabItem { Label(GiftTab.settings.rawValue, systemImage: GiftTab.settings.symbol) }
                .tag(GiftTab.settings)
        }
    }
}
