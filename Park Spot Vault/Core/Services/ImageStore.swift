import UIKit

enum ImageStore {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    static func save(_ image: UIImage) -> String? {
        let ratio = min(1, 1600 / max(image.size.width, image.size.height))
        let size = CGSize(width: max(1, image.size.width * ratio), height: max(1, image.size.height * ratio))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = resized.jpegData(compressionQuality: 0.82) else { return nil }
        let filename = "parking-\(UUID().uuidString).jpg"
        let url = documentsDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            cache.setObject(image, forKey: filename as NSString, cost: Int(image.size.width * image.size.height * image.scale * image.scale * 4))
            return filename
        } catch {
            return nil
        }
    }

    static func load(_ filename: String?) -> UIImage? {
        guard let filename else { return nil }
        if let cached = cache.object(forKey: filename as NSString) {
            return cached
        }
        let url = documentsDirectory.appendingPathComponent(filename)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: filename as NSString, cost: Int(image.size.width * image.size.height * image.scale * image.scale * 4))
        return image
    }

    static func remove(_ filename: String?) {
        guard let filename, filename == URL(fileURLWithPath: filename).lastPathComponent else { return }
        cache.removeObject(forKey: filename as NSString)
        try? FileManager.default.removeItem(at: documentsDirectory.appendingPathComponent(filename))
    }

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
