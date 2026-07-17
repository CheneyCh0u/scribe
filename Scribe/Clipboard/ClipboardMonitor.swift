import AppKit

/// 轮询 NSPasteboard.changeCount（macOS 无剪贴板变更回调 API，轮询是唯一方案）。
final class ClipboardMonitor {
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    private let store: HistoryStore
    private var timer: Timer?
    private var changeCount: Int
    private var suppressRemaining = 0

    init(store: HistoryStore) {
        self.store = store
        changeCount = NSPasteboard.general.changeCount
    }

    func start() {
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// 面板回填/复制会写剪贴板，调用一次跳过下一次变更，避免自采集。
    func suppressNextChange() {
        suppressRemaining += 1
    }

    private func tick() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount

        if suppressRemaining > 0 {
            suppressRemaining -= 1
            return
        }

        let types = pasteboard.types ?? []
        if types.contains(Self.transientType) { return }
        let isConcealed = types.contains(Self.concealedType)
        if isConcealed && !Preferences.recordConcealed { return }

        guard let text = pasteboard.string(forType: .string) else { return }

        let app = NSWorkspace.shared.frontmostApplication
        store.record(
            text: text,
            appBundleID: app?.bundleIdentifier,
            appName: app?.localizedName,
            isConcealed: isConcealed
        )
    }
}
