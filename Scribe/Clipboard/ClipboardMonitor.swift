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

        // 面板内选词复制（面板是 key window 时）来源记为 Scribe；
        // 否则记前台应用（本应用是 agent，永不成为 frontmost）
        var bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        var appName = NSWorkspace.shared.frontmostApplication?.localizedName
        if NSApp.keyWindow != nil {
            bundleID = Bundle.main.bundleIdentifier
            appName = "Scribe"
        }

        // 类型优先级：文件引用 > 图片 > 文本
        if types.contains(.fileURL),
           let urls = pasteboard.readObjects(forClasses: [NSURL.self],
                                             options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            store.recordFile(urls: urls, appBundleID: bundleID, appName: appName)
            return
        }

        if let pngData = pngImageData(from: pasteboard) {
            store.recordImage(pngData: pngData, appBundleID: bundleID, appName: appName)
            return
        }

        guard let text = pasteboard.string(forType: .string) else { return }
        // RTF 原文另存用于保真回填（1MB 以内，超大富文本退化为纯文本）
        var rtfData = pasteboard.data(forType: .rtf)
        if let data = rtfData, data.count > 1_000_000 { rtfData = nil }

        store.record(
            text: text,
            rtfData: rtfData,
            appBundleID: bundleID,
            appName: appName,
            isConcealed: isConcealed
        )
    }

    /// 取剪贴板图片并统一为 PNG（优先原生 PNG，其次 TIFF 转码）。
    private func pngImageData(from pasteboard: NSPasteboard) -> Data? {
        if let png = pasteboard.data(forType: .png) { return png }
        if let tiff = pasteboard.data(forType: .tiff) {
            return NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        }
        return nil
    }
}
