import Foundation
import UIKit

enum ImageStorage {
    private static var directoryURL: URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = support.appendingPathComponent("GiftForYouImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func save(_ sourceData: Data?, id: UUID) -> String? {
        guard
            let sourceData,
            let sourceImage = UIImage(data: sourceData),
            let directoryURL
        else { return nil }

        let image = sourceImage.preparingForStorage(maxDimension: 1800)
        guard let data = image.jpegData(compressionQuality: 0.84) else { return nil }

        let fileName = "\(id.uuidString.lowercased()).jpg"
        let fileURL = directoryURL.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    static func load(_ fileName: String?) -> UIImage? {
        guard let fileName, let directoryURL else { return nil }
        return UIImage(contentsOfFile: directoryURL.appendingPathComponent(fileName).path)
    }

    static func data(_ fileName: String) -> Data? {
        guard let directoryURL else { return nil }
        return try? Data(contentsOf: directoryURL.appendingPathComponent(fileName))
    }

    static func restore(_ data: Data, fileName: String) {
        guard let directoryURL else { return }
        try? data.write(to: directoryURL.appendingPathComponent(fileName), options: .atomic)
    }

    static func delete(_ fileName: String?) {
        guard let fileName, let directoryURL else { return }
        try? FileManager.default.removeItem(at: directoryURL.appendingPathComponent(fileName))
    }

    static func deleteAll() {
        guard let directoryURL else { return }
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

private extension UIImage {
    func preparingForStorage(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
