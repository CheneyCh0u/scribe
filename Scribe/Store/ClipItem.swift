import Foundation
import GRDB

struct ClipItem: Identifiable, Equatable, Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "item"

    var id: Int64?
    var type: String            // "text"（图片/文件在阶段 3 加入）
    var content: String
    var rtfData: Data?          // 富文本原文，保真回填用；⇧↩ 纯文本粘贴时忽略
    var preview: String
    var contentHash: String
    var appBundleID: String?
    var appName: String?
    var isConcealed: Bool
    var pinned: Bool
    var createdAt: Date
    var lastUsedAt: Date

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    var characterCount: Int { content.count }

    var isLink: Bool {
        let t = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.contains("\n") && (t.hasPrefix("http://") || t.hasPrefix("https://"))
    }

    var typeDisplayName: String {
        if isConcealed { return "密码" }
        if isLink { return "链接" }
        return "纯文本"
    }

    static func makePreview(_ text: String) -> String {
        let singleLine = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        return String(singleLine.prefix(200))
    }
}
