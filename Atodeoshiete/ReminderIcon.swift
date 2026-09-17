import UIKit

enum ReminderIconType: String {
    case emoji
    case photo
}

enum ReminderIconStore {
    private static let photoFileName = "reminder-icon.jpg"

    static var photoURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(photoFileName)
    }

    static var hasPhoto: Bool {
        FileManager.default.fileExists(atPath: photoURL.path)
    }

    static func savePhoto(_ image: UIImage) throws {
        let dir = photoURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: photoURL, options: .atomic)
    }

    static func deletePhoto() {
        try? FileManager.default.removeItem(at: photoURL)
    }

    static func loadPhoto() -> UIImage? {
        guard let data = try? Data(contentsOf: photoURL) else { return nil }
        return UIImage(data: data)
    }

    static func emojiImage(_ emoji: String, size: CGFloat = 200) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { _ in
            let text = emoji.isEmpty ? "🔔" : emoji
            let font = UIFont.systemFont(ofSize: size * 0.75)
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let textSize = text.size(withAttributes: attrs)
            let rect = CGRect(
                x: (size - textSize.width) / 2,
                y: (size - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: rect, withAttributes: attrs)
        }
    }
}
