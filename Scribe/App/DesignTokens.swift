import AppKit
import SwiftUI

/// UI tokens。唯一权威来源是 docs/ui/tokens.md，改动先改文档再同步这里。
/// 系统语义色直接用系统 API（自动适配深浅）；自定义色用 dynamicProvider 提供双值。
enum Tokens {
    enum Space {
        static let s1: CGFloat = 4
        static let s2: CGFloat = 6
        static let s3: CGFloat = 8
        static let s4: CGFloat = 12
        static let s5: CGFloat = 16
        static let s6: CGFloat = 20
    }

    enum Radius {
        static let panel: CGFloat = 22
        static let row: CGFloat = 10
        static let card: CGFloat = 8
        static let keycap: CGFloat = 6
    }

    enum Layout {
        static let panelSize = CGSize(width: 840, height: 540)
        static let listColumnWidth: CGFloat = 320
        static let settingsSize = CGSize(width: 460, height: 420)
    }

    enum Fonts {
        static let search = Font.system(size: 16)
        static let title = Font.system(size: 15)
        static let body = Font.system(size: 13)
        static let label = Font.system(size: 12)
        static let caption = Font.system(size: 11)
        static let mono = Font.system(size: 12).monospaced()
    }

    enum Motion {
        static let fast = Animation.easeOut(duration: 0.12)
        static let base = Animation.easeOut(duration: 0.18)
    }

    enum Colors {
        // 系统语义色（自动跟随深浅）
        static let textPrimary = Color(nsColor: .labelColor)
        static let textSecondary = Color(nsColor: .secondaryLabelColor)
        static let textTertiary = Color(nsColor: .tertiaryLabelColor)
        static let divider = Color(nsColor: .separatorColor)
        static let danger = Color(nsColor: .systemRed)

        // 自定义双值色（按 tokens.md 聚焦取样）
        static let rowSelected = dynamic("RowSelected",
            light: NSColor(white: 0, alpha: 0.075), dark: NSColor(white: 1, alpha: 0.09))
        static let rowHover = dynamic("RowHover",
            light: NSColor(white: 0, alpha: 0.045), dark: NSColor(white: 1, alpha: 0.055))
        static let keycap = dynamic("Keycap",
            light: NSColor(white: 0, alpha: 0.06), dark: NSColor(white: 1, alpha: 0.12))
        static let surfaceCard = dynamic("SurfaceCard",
            light: NSColor(white: 0, alpha: 0.045), dark: NSColor(white: 1, alpha: 0.05))
        static let pinIndicator = Color(nsColor: NSColor(srgbRed: 0.902, green: 0.635, blue: 0.235, alpha: 1)) // #E6A23C

        private static func dynamic(_ name: String, light: NSColor, dark: NSColor) -> Color {
            Color(nsColor: NSColor(name: NSColor.Name(name)) { appearance in
                appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            })
        }
    }
}
