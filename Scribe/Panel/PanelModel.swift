import AppKit
import SwiftUI

@MainActor
final class PanelModel: ObservableObject {
    struct Section: Identifiable {
        var title: String
        var items: [ClipItem]
        var id: String { title }
    }

    @Published var searchText = "" {
        didSet { if searchText != oldValue { reload(keepSelection: false) } }
    }
    @Published var filter: TimeFilter = .all {
        didSet { if filter != oldValue { reload(keepSelection: false) } }
    }
    @Published var typeFilter: TypeFilter = .all {
        didSet { if typeFilter != oldValue { reload(keepSelection: false) } }
    }
    @Published private(set) var sections: [Section] = []
    @Published var selectedID: Int64?
    @Published private(set) var totalCount = 0

    var onRequestClose: (() -> Void)?

    private let store: HistoryStore
    private let clipboardMonitor: ClipboardMonitor
    private var observer: NSObjectProtocol?

    init(store: HistoryStore, clipboardMonitor: ClipboardMonitor) {
        self.store = store
        self.clipboardMonitor = clipboardMonitor
        observer = NotificationCenter.default.addObserver(
            forName: HistoryStore.didChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload(keepSelection: true) }
        }
    }

    var flatItems: [ClipItem] { sections.flatMap(\.items) }

    var selectedItem: ClipItem? {
        guard let id = selectedID else { return nil }
        return flatItems.first { $0.id == id }
    }

    func prepareForShow() {
        searchText = ""
        filter = .all
        typeFilter = .all
        reload(keepSelection: false)
    }

    func reload(keepSelection: Bool) {
        let result = store.fetch(filter: filter, type: typeFilter, query: searchText)
        var sections: [Section] = []
        if !result.pinned.isEmpty {
            sections.append(Section(title: "置顶", items: result.pinned))
        }
        sections.append(contentsOf: Self.groupByDay(result.others))
        self.sections = sections
        totalCount = store.stats().count

        let flat = flatItems
        if keepSelection, let id = selectedID, flat.contains(where: { $0.id == id }) {
            // 选中项仍在，保持
        } else {
            selectedID = flat.first?.id
        }
    }

    // MARK: - 选择与操作

    func moveSelection(by delta: Int) {
        let flat = flatItems
        guard !flat.isEmpty else { return }
        let currentIndex = flat.firstIndex { $0.id == selectedID } ?? 0
        let newIndex = min(max(currentIndex + delta, 0), flat.count - 1)
        selectedID = flat[newIndex].id
    }

    func selectVisibleIndex(_ index: Int) {
        let flat = flatItems
        guard flat.indices.contains(index) else { return }
        selectedID = flat[index].id
    }

    /// 回填粘贴（↩ / 单击 / ⌘1-9）：写回剪贴板 → 关面板 → 模拟 ⌘V。
    /// 未授权辅助功能时降级为仅复制，并弹一次系统授权引导。
    func pasteSelected(plainText: Bool = false) {
        guard let item = selectedItem, let id = item.id else { return }
        PasteService.writeToPasteboard(item, plainText: plainText, monitor: clipboardMonitor)
        store.bumpUsed(id: id)
        onRequestClose?()
        if PasteService.isTrusted {
            PasteService.sendPasteKeystroke()
        } else {
            let promptedKey = "axPromptShown"
            if !UserDefaults.standard.bool(forKey: promptedKey) {
                UserDefaults.standard.set(true, forKey: promptedKey)
                PasteService.promptForPermission()
            }
            // 降级：内容已在剪贴板，用户可手动 ⌘V
        }
    }

    /// 仅复制到剪贴板（⌥↩），不模拟粘贴。
    func copySelected() {
        guard let item = selectedItem, let id = item.id else { return }
        PasteService.writeToPasteboard(item, plainText: false, monitor: clipboardMonitor)
        store.bumpUsed(id: id)
        onRequestClose?()
    }

    func deleteSelected() {
        guard let item = selectedItem, let id = item.id else { return }
        let flat = flatItems
        let index = flat.firstIndex { $0.id == id }
        store.delete(id: id)
        if let index {
            let remaining = flat.enumerated().filter { $0.offset != index }.map(\.element)
            let next = remaining.indices.contains(index) ? remaining[index] : remaining.last
            selectedID = next?.id
        }
    }

    func togglePinSelected() {
        guard let item = selectedItem, let id = item.id else { return }
        store.togglePin(id: id)
    }

    /// ⌘O：链接开浏览器、文件在访达显示、图片用默认应用打开。
    func openSelected() {
        guard let item = selectedItem else { return }
        switch item.type {
        case "file":
            let urls = item.filePaths.map { URL(fileURLWithPath: $0) }
            NSWorkspace.shared.activateFileViewerSelecting(urls)
            onRequestClose?()
        case "image":
            if let path = item.imagePath, let url = ImageStore.shared?.url(for: path) {
                NSWorkspace.shared.open(url)
                onRequestClose?()
            }
        default:
            if item.isLink,
               let url = URL(string: item.content.trimmingCharacters(in: .whitespacesAndNewlines)) {
                NSWorkspace.shared.open(url)
                onRequestClose?()
            }
        }
    }

    var openActionTitle: String? {
        guard let item = selectedItem else { return nil }
        switch item.type {
        case "file": return "在访达中显示"
        case "image": return "打开图片"
        default: return item.isLink ? "打开链接" : nil
        }
    }

    // MARK: - 分组

    private static func groupByDay(_ items: [ClipItem]) -> [Section] {
        let cal = Calendar.current
        var order: [Date] = []
        var buckets: [Date: [ClipItem]] = [:]
        for item in items {
            let day = cal.startOfDay(for: item.lastUsedAt)
            if buckets[day] == nil { order.append(day) }
            buckets[day, default: []].append(item)
        }
        return order.map { day in
            Section(title: dayTitle(day), items: buckets[day] ?? [])
        }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日 EEEE"
        return f
    }()

    private static func dayTitle(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "今天" }
        if cal.isDateInYesterday(day) { return "昨天" }
        return dayFormatter.string(from: day)
    }
}
