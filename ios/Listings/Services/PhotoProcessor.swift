import UIKit

/// The API only accepts JPEGs of 10 MB or less. Photos from the library are often
/// HEIC and large, so downscale and re-encode them before upload.
enum PhotoProcessor {
    static let maxDimension: CGFloat = 1600
    static let maxBytes = 9_500_000

    static func jpeg(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }

        var quality: CGFloat = 0.8
        var output = resized.jpegData(compressionQuality: quality)
        while let current = output, current.count > maxBytes, quality > 0.3 {
            quality -= 0.15
            output = resized.jpegData(compressionQuality: quality)
        }
        return output
    }
}
