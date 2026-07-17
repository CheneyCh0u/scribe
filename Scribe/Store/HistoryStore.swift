import Foundation
import CryptoKit
import GRDB

enum TimeFilter: String, CaseIterable, Identifiable {
    case all, today, yesterday, thisWeek, lastWeek, thisMonth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .today: return "今天"
        case .yesterday: return "昨天"
        case .thisWeek: return "本周"
        case .lastWeek: return "上周"
        case .thisMonth: return "本月"
        }
    }

    /// 时间范围 [start, end)，nil 表示不限。
    var dateRange: (start: Date, end: Date)? {
        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        switch self {
        case .all:
            return nil
        case .today:
            return (todayStart, cal.date(byAdding: .day, value: 1, to: todayStart)!)
        case .yesterday:
            return (cal.date(byAdding: .day, value: -1, to: todayStart)!, todayStart)
        case .thisWeek:
            let start = cal.dateInterval(of: .weekOfYear, for: now)!.start
            return (start, cal.date(byAdding: .weekOfYear, value: 1, to: start)!)
        case .lastWeek:
            let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: now)!.start
            return (cal.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)!, thisWeekStart)
        case .thisMonth:
            let start = cal.dateInterval(of: .month, for: now)!.start
            return (start, cal.date(byAdding: .month, value: 1, to: start)!)
        }
    }
}

final class HistoryStore {
    static let didChange = Notification.Name("HistoryStoreDidChange")

    private let dbQueue: DatabaseQueue

    init() throws {
        let dir = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Scribe", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        dbQueue = try DatabaseQueue(path: dir.appendingPathComponent("scribe.sqlite").path)
        try Self.migrator.migrate(dbQueue)
    }

    /// 测试用：内存库。
    init(inMemory: Bool) throws {
        dbQueue = try DatabaseQueue()
        try Self.migrator.migrate(dbQueue)
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "item") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("type", .text).notNull()
                t.column("content", .text).notNull()
                t.column("preview", .text).notNull()
                t.column("contentHash", .text).notNull().unique()
                t.column("appBundleID", .text)
                t.column("appName", .text)
                t.column("isConcealed", .boolean).notNull().defaults(to: false)
                t.column("pinned", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
                t.column("lastUsedAt", .datetime).notNull().indexed()
            }
            // trigram FTS：支持中英文子串搜索（查询 ≥3 字符走 MATCH，更短回退 LIKE）
            try db.execute(sql: """
                CREATE VIRTUAL TABLE item_fts USING fts5(
                    content, content='item', content_rowid='id', tokenize='trigram'
                );
                CREATE TRIGGER item_ai AFTER INSERT ON item BEGIN
                    INSERT INTO item_fts(rowid, content) VALUES (new.id, new.content);
                END;
                CREATE TRIGGER item_ad AFTER DELETE ON item BEGIN
                    INSERT INTO item_fts(item_fts, rowid, content) VALUES ('delete', old.id, old.content);
                END;
                CREATE TRIGGER item_au AFTER UPDATE OF content ON item BEGIN
                    INSERT INTO item_fts(item_fts, rowid, content) VALUES ('delete', old.id, old.content);
                    INSERT INTO item_fts(rowid, content) VALUES (new.id, new.content);
                END;
                """)
        }
        migrator.registerMigration("v2-rtf") { db in
            try db.alter(table: "item") { t in
                t.add(column: "rtfData", .blob)
            }
        }
        return migrator
    }

    // MARK: - 写入

    func record(text: String, rtfData: Data?, appBundleID: String?, appName: String?, isConcealed: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let hash = Self.hash(of: text)
        do {
            try dbQueue.write { db in
                if var existing = try ClipItem.filter(Column("contentHash") == hash).fetchOne(db) {
                    existing.lastUsedAt = Date()
                    if let rtfData { existing.rtfData = rtfData }
                    try existing.update(db)
                } else {
                    var item = ClipItem(
                        id: nil,
                        type: "text",
                        content: text,
                        rtfData: rtfData,
                        preview: ClipItem.makePreview(text),
                        contentHash: hash,
                        appBundleID: appBundleID,
                        appName: appName,
                        isConcealed: isConcealed,
                        pinned: false,
                        createdAt: Date(),
                        lastUsedAt: Date()
                    )
                    try item.insert(db)
                }
            }
            notifyChanged()
        } catch {
            NSLog("HistoryStore.record failed: \(error)")
        }
    }

    func bumpUsed(id: Int64) {
        try? dbQueue.write { db in
            try db.execute(sql: "UPDATE item SET lastUsedAt = ? WHERE id = ?", arguments: [Date(), id])
        }
        notifyChanged()
    }

    func togglePin(id: Int64) {
        try? dbQueue.write { db in
            try db.execute(sql: "UPDATE item SET pinned = NOT pinned WHERE id = ?", arguments: [id])
        }
        notifyChanged()
    }

    func delete(id: Int64) {
        _ = try? dbQueue.write { db in
            try ClipItem.deleteOne(db, key: id)
        }
        notifyChanged()
    }

    /// 天数 + 条数双重淘汰，pinned 不淘汰。
    func prune(days: Int, maxCount: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        try? dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM item WHERE pinned = 0 AND lastUsedAt < ?",
                arguments: [cutoff]
            )
            try db.execute(sql: """
                DELETE FROM item WHERE pinned = 0 AND id IN (
                    SELECT id FROM item WHERE pinned = 0
                    ORDER BY lastUsedAt DESC LIMIT -1 OFFSET ?
                )
                """, arguments: [maxCount])
        }
        notifyChanged()
    }

    // MARK: - 查询

    struct FetchResult {
        var pinned: [ClipItem]
        var others: [ClipItem]
    }

    /// pinned 不受时间筛选影响（但受搜索影响）；others 按 lastUsedAt 倒序。
    func fetch(filter: TimeFilter, query: String, limit: Int = 300) -> FetchResult {
        let query = query.trimmingCharacters(in: .whitespaces)
        return (try? dbQueue.read { db -> FetchResult in
            var conditions: [String] = []
            var arguments: [DatabaseValueConvertible] = []

            if !query.isEmpty {
                if query.count >= 3 {
                    let match = "\"" + query.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                    conditions.append("id IN (SELECT rowid FROM item_fts WHERE item_fts MATCH ?)")
                    arguments.append(match)
                } else {
                    let escaped = query
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "%", with: "\\%")
                        .replacingOccurrences(of: "_", with: "\\_")
                    conditions.append("content LIKE ? ESCAPE '\\'")
                    arguments.append("%\(escaped)%")
                }
            }

            let searchClause = conditions.isEmpty ? "" : " AND " + conditions.joined(separator: " AND ")

            let pinned = try ClipItem.fetchAll(db, sql: """
                SELECT * FROM item WHERE pinned = 1\(searchClause) ORDER BY lastUsedAt DESC
                """, arguments: StatementArguments(arguments))

            var timeClause = ""
            var otherArguments = arguments
            if let range = filter.dateRange {
                timeClause = " AND lastUsedAt >= ? AND lastUsedAt < ?"
                otherArguments.append(range.start)
                otherArguments.append(range.end)
            }
            otherArguments.append(limit)
            let others = try ClipItem.fetchAll(db, sql: """
                SELECT * FROM item WHERE pinned = 0\(searchClause)\(timeClause)
                ORDER BY lastUsedAt DESC LIMIT ?
                """, arguments: StatementArguments(otherArguments))

            return FetchResult(pinned: pinned, others: others)
        }) ?? FetchResult(pinned: [], others: [])
    }

    func stats() -> (count: Int, bytes: Int) {
        (try? dbQueue.read { db in
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item") ?? 0
            let bytes = try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(LENGTH(content)), 0) FROM item") ?? 0
            return (count, bytes)
        }) ?? (0, 0)
    }

    // MARK: - 辅助

    static func hash(of text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func notifyChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didChange, object: nil)
        }
    }
}
