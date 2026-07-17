import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", default: .init(.v, modifiers: [.command, .shift]))
}

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var sharedDelegate: AppDelegate!

    static func main() {
        let app = NSApplication.shared
        sharedDelegate = AppDelegate()
        app.delegate = sharedDelegate
        app.run()
    }

    private var statusItem: NSStatusItem!
    private var store: HistoryStore!
    private var clipboardMonitor: ClipboardMonitor!
    private var panelController: PanelController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            store = try HistoryStore()
        } catch {
            NSAlert(error: error).runModal()
            NSApp.terminate(nil)
            return
        }
        clipboardMonitor = ClipboardMonitor(store: store)
        panelController = PanelController(store: store, clipboardMonitor: clipboardMonitor)
        clipboardMonitor.start()
        store.prune(days: Preferences.retentionDays, maxCount: Preferences.maxItemCount)

        setUpMainMenu()
        setUpStatusItem()
        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in
            Task { @MainActor in
                self?.panelController.toggle()
            }
        }
    }

    /// LSUIElement 应用没有可见主菜单，但 ⌘C/⌘V/⌘X/⌘A 等编辑键位依赖菜单路由，
    /// 不挂这个菜单，面板里（右栏选词、搜索框）的复制粘贴全部失效。
    private func setUpMainMenu() {
        let mainMenu = NSMenu()
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "Scribe"
        )
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "打开面板", action: #selector(openPanel), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())
        let axItem = NSMenuItem(title: "启用回填粘贴（辅助功能）…", action: #selector(openAccessibility), keyEquivalent: "")
        axItem.target = self
        menu.addItem(axItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 Scribe", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func openPanel() {
        panelController.toggle()
    }

    @objc private func openAccessibility() {
        PasteService.openAccessibilitySettings()
    }
}

enum Preferences {
    static var retentionDays: Int {
        let v = UserDefaults.standard.integer(forKey: "retentionDays")
        return v > 0 ? v : 30
    }
    static var maxItemCount: Int {
        let v = UserDefaults.standard.integer(forKey: "maxItemCount")
        return v > 0 ? v : 1000
    }
    static var recordConcealed: Bool {
        UserDefaults.standard.object(forKey: "recordConcealed") as? Bool ?? true
    }
}
