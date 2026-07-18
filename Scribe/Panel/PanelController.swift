import AppKit
import SwiftUI

/// 非激活浮层面板：可成为 key window 接收键盘输入，但不激活本应用、不抢原应用焦点。
private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class MaterialHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
}

enum PanelMask {
    static func path(in rect: CGRect, cornerRadius: CGFloat) -> Path {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
    }

    static func image(size: CGSize, cornerRadius: CGFloat) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.clear(rect)
            context.addPath(path(in: rect, cornerRadius: cornerRadius).cgPath)
            context.setFillColor(NSColor.white.cgColor)
            context.fillPath()
            return true
        }
    }
}

@MainActor
final class PanelController {
    private let panel: KeyPanel
    private let model: PanelModel
    private var keyMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var imageOverlay: NSPanel?

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
        effectView.maskImage = PanelMask.image(
            size: contentRect.size,
            cornerRadius: Tokens.Radius.panel
        )
        effectView.layer?.cornerRadius = Tokens.Radius.panel
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.masksToBounds = true

        let hostingView = MaterialHostingView(
            rootView: PanelView(model: model).background(Color.clear)
        )
        hostingView.frame = effectView.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.isOpaque = false
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        effectView.addSubview(hostingView)
        panel.contentView = effectView
        panel.invalidateShadow()

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
        let start = CFAbsoluteTimeGetCurrent()
        model.prepareForShow()
        positionOnActiveScreen()
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
        DispatchQueue.main.async {
            let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
            NSLog("Scribe panel interactive in %.1f ms", ms)
            #if DEBUG
            // 统一日志会打码动态值，DEBUG 下另落文件便于性能验收
            let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Scribe/latency.log")
            let line = String(format: "%.1f\n", ms)
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(line.data(using: .utf8)!)
            } else {
                try? line.write(to: url, atomically: true, encoding: .utf8)
            }
            #endif
        }
    }

    func hide() {
        hideImageOverlay()
        removeKeyMonitor()
        panel.orderOut(nil)
    }

    // MARK: - 空格大图预览

    private func toggleImageOverlay() {
        if imageOverlay?.isVisible == true {
            hideImageOverlay()
            return
        }
        guard let item = model.selectedItem, item.type == "image",
              let path = item.imagePath,
              let url = ImageStore.shared?.url(for: path),
              let image = ImageStore.downsample(url: url, maxPixel: 2400),
              let screen = panel.screen ?? NSScreen.main else { return }

        // 适配屏幕 85%，等比缩放
        let maxSize = CGSize(width: screen.visibleFrame.width * 0.85,
                             height: screen.visibleFrame.height * 0.85)
        let scale = min(maxSize.width / image.size.width, maxSize.height / image.size.height, 1)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let overlay = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        overlay.level = .modalPanel
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.hasShadow = true

        let imageView = NSImageView(image: image)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 12
        imageView.layer?.cornerCurve = .continuous
        imageView.layer?.masksToBounds = true
        overlay.contentView = imageView

        let frame = screen.visibleFrame
        overlay.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2,
                                       y: frame.midY - size.height / 2))
        overlay.orderFront(nil)
        imageOverlay = overlay
    }

    private func hideImageOverlay() {
        imageOverlay?.orderOut(nil)
        imageOverlay = nil
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

        // 大图预览打开时：任意确认/取消键先关闭它
        if imageOverlay?.isVisible == true, [49, 53, 36].contains(event.keyCode) {
            hideImageOverlay()
            return true
        }

        switch event.keyCode {
        case 49 where model.searchText.isEmpty: // 空格（仅搜索为空时，避免吃掉输入）
            if model.selectedItem?.type == "image" {
                toggleImageOverlay()
                return true
            }
            return false
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
            if chars == "o" {
                model.openSelected()
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
