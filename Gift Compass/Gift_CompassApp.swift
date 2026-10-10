//
//  Gift_CompassApp.swift
//  Gift Compass
//
//  Created by Артём Коротков on 18.07.2026.
//

import SwiftUI

@main
struct Gift_CompassApp: App {
    @UIApplicationDelegateAdaptor(GiftCompassAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            CompassLaunchRouter()
        }
    }
}
