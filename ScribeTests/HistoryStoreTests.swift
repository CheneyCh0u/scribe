import XCTest
@testable import Scribe

final class HistoryStoreTests: XCTestCase {
    private func makeStore() throws -> HistoryStore {
        try HistoryStore(inMemory: true)
    }

    private func record(_ store: HistoryStore, _ text: String) {
        store.record(text: text, rtfData: nil, appBundleID: nil, appName: nil, isConcealed: false)
    }

    // MARK: - 去重

    func testDuplicateBumpsToTopWithoutNewRow() throws {
        let store = try makeStore()
        record(store, "hello")
        record(store, "world")
        // 拉开时间差（真实场景复制间隔远大于毫秒；同毫秒写入排序无意义）
        let hello = store.fetch(filter: .all, query: "").others.first { $0.content == "hello" }!
        store.debugSetLastUsed(id: hello.id!, date: Date().addingTimeInterval(-60))

        record(store, "hello") // 重复：应置顶而非新增

        let result = store.fetch(filter: .all, query: "")
        XCTAssertEqual(result.others.count, 2)
        XCTAssertEqual(result.others.first?.content, "hello")
    }

    func testEmptyTextIgnored() throws {
        let store = try makeStore()
        record(store, "   \n  ")
        XCTAssertEqual(store.stats().count, 0)
    }

    // MARK: - 淘汰

    func testPruneRemovesExpiredButKeepsPinned() throws {
        let store = try makeStore()
        record(store, "old-unpinned")
        record(store, "old-pinned")
        record(store, "fresh")

        let all = store.fetch(filter: .all, query: "").others
        let oldDate = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let oldUnpinned = all.first { $0.content == "old-unpinned" }!
        let oldPinned = all.first { $0.content == "old-pinned" }!
        store.debugSetLastUsed(id: oldUnpinned.id!, date: oldDate)
        store.debugSetLastUsed(id: oldPinned.id!, date: oldDate)
        store.togglePin(id: oldPinned.id!)

        store.prune(days: 30, maxCount: 1000)

        let after = store.fetch(filter: .all, query: "")
        XCTAssertEqual(after.others.map(\.content), ["fresh"])
        XCTAssertEqual(after.pinned.map(\.content), ["old-pinned"])
    }

    func testPruneEnforcesMaxCount() throws {
        let store = try makeStore()
        for i in 1...5 { record(store, "item-\(i)") }
        // 保证 lastUsedAt 严格递增
        let all = store.fetch(filter: .all, query: "").others
        for (offset, item) in all.reversed().enumerated() {
            store.debugSetLastUsed(id: item.id!, date: Date().addingTimeInterval(Double(offset)))
        }

        store.prune(days: 365, maxCount: 3)

        let after = store.fetch(filter: .all, query: "").others
        XCTAssertEqual(after.count, 3)
        XCTAssertEqual(after.map(\.content), ["item-5", "item-4", "item-3"])
    }

    // MARK: - 搜索

    func testSearchChineseSubstringViaFTS() throws {
        let store = try makeStore()
        record(store, "上海市徐汇区漕溪北路331号")
        record(store, "hello world")

        let hit = store.fetch(filter: .all, query: "漕溪北")
        XCTAssertEqual(hit.others.count, 1)
        let miss = store.fetch(filter: .all, query: "漕溪南")
        XCTAssertEqual(miss.others.count, 0)
    }

    func testShortQueryFallsBackToLike() throws {
        let store = try makeStore()
        record(store, "hello world")
        record(store, "中文内容")

        XCTAssertEqual(store.fetch(filter: .all, query: "he").others.count, 1)
        XCTAssertEqual(store.fetch(filter: .all, query: "中文").others.count, 1)
        // LIKE 特殊字符转义
        record(store, "100%完成")
        XCTAssertEqual(store.fetch(filter: .all, query: "0%").others.count, 1)
    }

    // MARK: - 时间筛选

    func testTimeFilterYesterday() throws {
        let store = try makeStore()
        record(store, "today-item")
        record(store, "yesterday-item")

        let yesterday = Calendar.current.date(byAdding: .hour, value: -30, to: Date())!
        let item = store.fetch(filter: .all, query: "").others.first { $0.content == "yesterday-item" }!
        store.debugSetLastUsed(id: item.id!, date: yesterday)

        XCTAssertEqual(store.fetch(filter: .today, query: "").others.map(\.content), ["today-item"])
        XCTAssertEqual(store.fetch(filter: .yesterday, query: "").others.map(\.content), ["yesterday-item"])
    }

    // MARK: - 删除与清空

    func testDeleteAndClearAll() throws {
        let store = try makeStore()
        record(store, "a")
        record(store, "b")

        let first = store.fetch(filter: .all, query: "").others.first!
        store.delete(id: first.id!)
        XCTAssertEqual(store.stats().count, 1)

        store.clearAll()
        XCTAssertEqual(store.stats().count, 0)
    }

    // MARK: - 文件条目

    func testRecordFileDedup() throws {
        let store = try makeStore()
        let urls = [URL(fileURLWithPath: "/tmp/a.txt"), URL(fileURLWithPath: "/tmp/b.txt")]
        store.recordFile(urls: urls, appBundleID: nil, appName: nil)
        store.recordFile(urls: urls, appBundleID: nil, appName: nil)

        let result = store.fetch(filter: .all, query: "")
        XCTAssertEqual(result.others.count, 1)
        XCTAssertEqual(result.others.first?.type, "file")
        XCTAssertEqual(result.others.first?.filePaths, ["/tmp/a.txt", "/tmp/b.txt"])
    }
}
