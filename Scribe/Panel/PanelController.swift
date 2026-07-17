import AppKit
import SwiftUI

/// 非激活浮层面板：可成为 key window 接收键盘输入，但不激活本应用、不抢原应用焦点。
private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController {
    private let panel: KeyPanel
    private let model: PanelModel
    private var keyMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    init(store: HistoryStore, clipboardMonitor: ClipboardMonitor) {
        model = PanelModel(store: store, clipboardMonitor: clipboardMonitor)

        panel = KeyPanel(
            contentRect: NSRect(origin: .zero, size: Tokens.Layout.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .utilityWindow

        let contentRect = NSRect(origin: .zero, size: Tokens.Layout.panelSize)
        let effectView = NSVisualEffectView(frame: contentRect)
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = Tokens.Radius.panel
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.masksToBounds = true

        let hostingView = NSHostingView(rootView: PanelView(model: model))
        hostingView.frame = effectView.bounds
        hostingView.autoresizingMask = [.width, .height]
        effectView.addSubview(hostingView)
        panel.contentView = effectView

        model.onRequestClose = { [weak self] in self?.hide() }

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        model.prepareForShow()
        positionOnActiveScreen()
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func hide() {
        removeKeyMonitor()
        panel.orderOut(nil)
    }

    /// 居中于鼠标所在屏幕（略高于几何中心）。
    private func positionOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = Tokens.Layout.panelSize
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2 + frame.height * 0.06
        )
        panel.setFrameOrigin(origin)
    }

    // MARK: - 键盘

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        let hasCommand = event.modifierFlags.contains(.command)

        switch event.keyCode {
        case 126: // ↑
            model.moveSelection(by: -1)
            return true
        case 125: // ↓
            model.moveSelection(by: 1)
            return true
        case 36, 76: // ↩ / enter：粘贴；⇧↩ 纯文本粘贴；⌥↩ 仅复制
            if event.modifierFlags.contains(.option) {
                model.copySelected()
            } else {
                model.pasteSelected(plainText: event.modifierFlags.contains(.shift))
            }
            return true
        case 53: // esc
            hide()
            return true
        case 51 where hasCommand: // ⌘⌫
            model.deleteSelected()
            return true
        default:
            break
        }

        if hasCommand, let chars = event.charactersIgnoringModifiers {
            if chars == "p" {
                model.togglePinSelected()
                return true
            }
            if let digit = Int(chars), (1...9).contains(digit) {
                model.selectVisibleIndex(digit - 1)
                model.pasteSelected()
                return true
            }
        }
        return false
    }
}
