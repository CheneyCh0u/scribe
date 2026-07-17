import Foundation
import GRDB

struct ClipItem: Identifiable, Equatable, Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "item"

    var id: Int64?
    var type: String            // "text" | "image" | "file"
    var content: String         // text 正文；image 为标签；file 为路径列表（\n 分隔）
    var rtfData: Data?          // 富文本原文，保真回填用；⇧↩ 纯文本粘贴时忽略
    var preview: String
    var contentHash: String
    var appBundleID: String?
    var appName: String?
    var isConcealed: Bool
    var pinned: Bool
    var createdAt: Date
    var lastUsedAt: Date
    var imagePath: String?      // images/ 目录下的文件名（image 类型）
    var imageWidth: Int?
    var imageHeight: Int?
    var byteSize: Int?          // image/file 的字节数

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    var characterCount: Int { content.count }

    var filePaths: [String] {
        type == "file" ? content.components(separatedBy: "\n") : []
    }

    var isLink: Bool {
        guard type == "text" else { return false }
        let t = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.contains("\n") && (t.hasPrefix("http://") || t.hasPrefix("https://"))
    }

    var typeDisplayName: String {
        switch type {
        case "image": return "图片"
        case "file": return filePaths.count > 1 ? "文件 × \(filePaths.count)" : "文件"
        default:
            if isConcealed { return "密码" }
            if isLink { return "链接" }
            return "纯文本"
        }
    }

    var sizeLabel: String? {
        guard let byteSize, byteSize > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(byteSize), countStyle: .file)
    }

    var dimensionLabel: String? {
        guard let imageWidth, let imageHeight else { return nil }
        return "\(imageWidth) × \(imageHeight)"
    }

    static func makePreview(_ text: String) -> String {
        let singleLine = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        return String(singleLine.prefix(200))
    }
}
