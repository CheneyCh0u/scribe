import AppKit
import ImageIO

/// 图片落盘存储：原图转 PNG 按内容哈希命名（天然去重），另存 ≤400px 缩略图。
/// DB 只存文件名与元数据；列表只加载缩略图、预览按需降采样，原图仅回填时读取。
final class ImageStore {
    static var shared: ImageStore!

    private let dir: URL
    private static let thumbCache = NSCache<NSString, NSImage>()

    init() throws {
        dir = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Scribe/images", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    struct SavedImage {
        let fileName: String
        let width: Int
        let height: Int
    }

    func url(for fileName: String) -> URL {
        dir.appendingPathComponent(fileName)
    }

    private func thumbFileName(for fileName: String) -> String {
        fileName.replacingOccurrences(of: ".png", with: ".thumb.png")
    }

    func save(pngData: Data, hash: String) throws -> SavedImage {
        let fileName = hash + ".png"
        let fileURL = url(for: fileName)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try pngData.write(to: fileURL)
        }
        guard let source = CGImageSourceCreateWithData(pngData as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let thumbURL = url(for: thumbFileName(for: fileName))
        if !FileManager.default.fileExists(atPath: thumbURL.path) {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 400,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ]
            if let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
               let dest = CGImageDestinationCreateWithURL(thumbURL as CFURL, "public.png" as CFString, 1, nil) {
                CGImageDestinationAddImage(dest, thumb, nil)
                CGImageDestinationFinalize(dest)
            }
        }
        return SavedImage(fileName: fileName, width: width, height: height)
    }

    func deleteFiles(imagePaths: [String]) {
        for name in imagePaths {
            try? FileManager.default.removeItem(at: url(for: name))
            try? FileManager.default.removeItem(at: url(for: thumbFileName(for: name)))
        }
    }

    /// 启动时清理 DB 不再引用的图片文件。
    func cleanupOrphans(referenced: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
        for file in files {
            let base = file.replacingOccurrences(of: ".thumb.png", with: ".png")
            if !referenced.contains(base) {
                try? FileManager.default.removeItem(at: url(for: file))
            }
        }
    }

    /// 列表缩略图：带缓存、后台解码。
    func loadThumbnail(for fileName: String) async -> NSImage? {
        let key = fileName as NSString
        if let cached = Self.thumbCache.object(forKey: key) { return cached }
        let thumbURL = url(for: thumbFileName(for: fileName))
        let image = await Task.detached(priority: .userInitiated) {
            NSImage(contentsOf: thumbURL)
        }.value
        if let image { Self.thumbCache.setObject(image, forKey: key) }
        return image
    }

    /// 按需降采样解码（右栏预览 / 空格大图），不把原图整幅载入内存。
    static func downsample(url: URL, maxPixel: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
