import AppKit
import ApplicationServices

/// 回填粘贴：写回剪贴板后用 CGEvent 模拟 ⌘V 粘贴到前台应用。
/// 需要辅助功能（Accessibility）权限；未授权时降级为仅复制。
@MainActor
enum PasteService {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// 弹出系统授权引导对话框（指向 系统设置 > 隐私与安全性 > 辅助功能）。
    static func promptForPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// 写回剪贴板。plainText 为 true 时只写纯文本（丢弃 RTF）。
    static func writeToPasteboard(_ item: ClipItem, plainText: Bool, monitor: ClipboardMonitor) {
        monitor.suppressNextChange()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !plainText, let rtf = item.rtfData {
            pasteboard.setData(rtf, forType: .rtf)
        }
        pasteboard.setString(item.content, forType: .string)
    }

    /// 面板隐藏后调用：模拟 ⌘V。返回是否真正发出（未授权返回 false）。
    @discardableResult
    static func sendPasteKeystroke() -> Bool {
        guard isTrusted else { return false }
        // 稍延迟，确保面板已让出 key window、事件落到原前台应用
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let vKeyCode: CGKeyCode = 9
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
        return true
    }
}
