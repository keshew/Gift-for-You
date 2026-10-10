import SwiftUI
import UIKit
import PhotosUI
import Foundation

struct PremiumBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                GCColor.porcelain,
                GCColor.background,
                GCColor.champagne.opacity(0.24)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
