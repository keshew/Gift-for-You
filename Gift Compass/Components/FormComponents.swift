import SwiftUI
import UIKit
import PhotosUI
import Foundation

struct FieldCard: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let keyboardType: UIKeyboardType

    init(_ title: String, text: Binding<String>, placeholder: String, keyboardType: UIKeyboardType = .default) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.keyboardType = keyboardType
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(GCColor.text.opacity(0.5))
                TextField(placeholder, text: $text)
                    .font(.headline.weight(.semibold))
                    .textFieldStyle(.plain)
                    .keyboardType(keyboardType)
            }
        }
    }
}

struct DateFieldCard: View {
    let title: String
    @Binding var date: Date

    var body: some View {
        GlassCard {
            DatePicker(title, selection: $date, displayedComponents: .date)
                .font(.headline.weight(.semibold))
                .foregroundStyle(GCColor.text)
        }
    }
}

struct PickerCard: View {
    let title: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        GlassCard {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .font(.headline.weight(.semibold))
        }
    }
}

struct NotesCard: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(GCColor.text.opacity(0.5))
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(4...7)
                    .font(.headline.weight(.semibold))
            }
        }
    }
}

struct PhotoPickerCard: View {
    let symbol: String
    let title: String
    let existingImageFileName: String?
    @Binding var imageData: Data?
    @Binding var removesExistingImage: Bool
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(symbol: String, title: String, imageData: Binding<Data?>, existingImageFileName: String? = nil, removesExistingImage: Binding<Bool> = .constant(false)) {
        self.symbol = symbol
        self.title = title
        self._imageData = imageData
        self.existingImageFileName = existingImageFileName
        self._removesExistingImage = removesExistingImage
    }

    private var hasPhoto: Bool {
        imageData != nil || (existingImageFileName != nil && !removesExistingImage)
    }

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            HStack(spacing: 15) {
                photoPreview
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.heavy))
                    Text(errorMessage ?? (hasPhoto ? "Tap to replace photo" : "Choose from Photos"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(errorMessage == nil ? GCColor.text.opacity(0.55) : GCColor.accent)
                }
                Spacer()
                if isLoading {
                    ProgressView()
                        .tint(GCColor.accent)
                } else {
                    Image(systemName: hasPhoto ? "checkmark.circle.fill" : "chevron.right")
                        .foregroundStyle(hasPhoto ? GCColor.success : GCColor.text.opacity(0.28))
                }
            }
            .foregroundStyle(GCColor.text)
        }
        .buttonStyle(.plain)
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
                .stroke(GCColor.cardHighlight.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: GCColor.primary.opacity(0.055), radius: 10, y: 5)
        .overlay(alignment: .topTrailing) {
            if hasPhoto {
                Button {
                    selectedItem = nil
                    imageData = nil
                    removesExistingImage = true
                    errorMessage = nil
                    haptic(.light)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, GCColor.accent)
                }
                .buttonStyle(.plain)
                .padding(10)
                .accessibilityLabel("Remove photo")
            }
        }
        .task(id: selectedItem) {
            guard let selectedItem else { return }
            isLoading = true
            errorMessage = nil
            do {
                guard let data = try await selectedItem.loadTransferable(type: Data.self), UIImage(data: data) != nil else {
                    throw PhotoSelectionError.invalidImage
                }
                imageData = data
                removesExistingImage = false
                haptic(.light)
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = "Could not load this photo"
            }
            isLoading = false
        }
    }

    @ViewBuilder
    private var photoPreview: some View {
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 66, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(GCColor.cardHighlight, lineWidth: 2))
        } else if !removesExistingImage, let image = ImageStorage.load(existingImageFileName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 66, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(GCColor.cardHighlight, lineWidth: 2))
        } else {
            Image(systemName: symbol)
                .font(.title2.weight(.bold))
                .foregroundStyle(GCColor.accent)
                .frame(width: 66, height: 66)
                .background(GCColor.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private enum PhotoSelectionError: Error {
    case invalidImage
}

struct PrimaryActionButton: View {
    let title: String
    let symbol: String
    let isEnabled: Bool
    let action: () -> Void

    init(title: String, symbol: String, isEnabled: Bool = true, action: @escaping () -> Void = {}) {
        self.title = title
        self.symbol = symbol
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button {
            haptic(.medium)
            action()
        } label: {
            Label(title, systemImage: symbol)
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(GCColor.action, in: Capsule())
        .opacity(isEnabled ? 1 : 0.42)
        .disabled(!isEnabled)
    }
}

struct AddMiniCard: View {
    let title: String
    let symbol: String
    let action: () -> Void

    init(title: String, symbol: String, action: @escaping () -> Void = {}) {
        self.title = title
        self.symbol = symbol
        self.action = action
    }

    var body: some View {
        Button {
            haptic(.light)
            action()
        } label: {
            Label(title, systemImage: symbol)
                .font(.headline.weight(.heavy))
                .foregroundStyle(GCColor.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(GCColor.card.opacity(0.9), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [8, 8]))
                        .foregroundStyle(GCColor.text.opacity(0.18))
                )
        }
        .buttonStyle(.plain)
    }
}

struct SearchField: View {
    @Binding var text: String

    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(GCColor.text.opacity(0.45))
                TextField("Search everything", text: $text)
                    .font(.headline.weight(.semibold))
            }
        }
    }
}
