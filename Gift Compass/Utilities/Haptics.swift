import SwiftUI
import UIKit
import PhotosUI
import Foundation

func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}

// MARK: - Data
