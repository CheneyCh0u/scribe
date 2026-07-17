# Scribe Design Tokens（权威来源）

状态：已定稿（2026-07-17），依据 004 结论 + macOS 聚焦（Spotlight）实拍取样。

**维护规则**：本文件是 UI token 的唯一权威。任何视觉调整先改这里，再同步 [scribe-ui.html](scribe-ui.html) 原型与 Swift 实现；三者不一致时以本文件为准。SwiftUI 侧 token 集中在一个 `DesignTokens.swift`（色值走 Asset Catalog），禁止在视图里散写魔法数字。

## 实现原则

- 标注「系统（自动）」的 token 直接用系统 API（语义色/材质/强调色），深浅模式自动跟随，**不写死色值**。
- 标注「自定义」的 token 在 Asset Catalog 建同名 Color Set，提供 Any / Dark 双值。
- 窗口不覆盖 appearance，跟随系统切换。
- 强调色仅用于链接、焦点环、设置选中标签；**列表选中态不用强调色**（聚焦式安静灰）。

## 颜色

| token | 浅色值 | 深色值 | SwiftUI | 类别 |
|---|---|---|---|---|
| `panel.background` | rgba(252,251,250,0.82) + blur38 sat1.8 | rgba(30,30,34,0.80) + blur38 | NSVisualEffectView(.popover/.fullScreenUI, .behindWindow)，以真机聚焦观感为准 | 系统材质（自动） |
| `row.selected` | black @7.5% | white @9% | Asset `RowSelected` | 自定义（聚焦同款） |
| `row.hover` | black @4.5% | white @5.5% | Asset `RowHover` | 自定义 |
| `filter.control` | 无底色；hover 用 `row.hover`，radius 6 | 同左 | Menu(.button) + .plain，文字 text.secondary 12pt + chevron.down 8pt | 自定义（时间筛选下拉） |
| `keycap` | black @6%（无阴影） | white @12% | Asset `Keycap` | 自定义（2026-07-17 修订：弃纯白） |
| `surface.card`（预览底） | black @4.5%（无边框无阴影） | white @5% | Asset `SurfaceCard` | 自定义（2026-07-17 修订：弃白色，轻灰内嵌与选中行同灰阶） |
| `text.primary` | #1C1C1E | white @90% | `.labelColor` | 系统（自动） |
| `text.secondary` | rgba(60,60,67,0.60) | rgba(235,235,245,0.60) | `.secondaryLabelColor` | 系统（自动） |
| `text.tertiary` | rgba(60,60,67,0.33) | rgba(235,235,245,0.32) | `.tertiaryLabelColor` | 系统（自动） |
| `divider` | black @6% | white @7% | `.separatorColor` | 系统（自动） |
| `accent` | #0A7AFF | #0A84FF | `Color.accentColor`（限链接/焦点环/设置选中标签） | 系统（自动） |
| `pin.indicator` | #E6A23C | 同值 | 固定色 | 自定义 |
| `danger` | #E0382E | #FF6961 | `.systemRed` | 系统（自动） |

## 圆角

| token | 值 |
|---|---|
| `radius.panel` | 22（聚焦大圆角） |
| `radius.row` | 10 |
| `radius.card` | 8 |
| `radius.chip / keycap` | 胶囊 / 6 |

## 布局

| token | 值 |
|---|---|
| `layout.panel` | 840 × 540 pt，屏幕居中唤起 |
| `layout.listColumn` | 320 pt |
| `layout.rowHeight` | 46 pt |
| `layout.settingsWindow` | 460 pt 宽 |
| `spacing` 刻度 | 4 / 6 / 8 / 12 / 16 / 20（`Spacing.s1`-`s6`） |

## 字体

| token | 值 |
|---|---|
| `font.search` | 16 pt（无框搜索区，占位用 text.tertiary，图标用 text.secondary） |
| `font.title` | 15 pt |
| `font.body` | 13 pt（列表主行） |
| `font.label` | 12 pt |
| `font.caption` | 11 pt（分组头、时间、提示） |
| `font.mono` | SF Mono 12（代码行与预览），`.monospaced()` |
| 字族 | 系统字体（SF Pro + PingFang SC），不引第三方字体 |
| 数字 | 时间/尺寸/计数用 `tabular-nums`（`.monospacedDigit()`） |

## 动效

| token | 值 | 用途 |
|---|---|---|
| `motion.fast` | 120ms，cubic-bezier(0.16,1,0.3,1)，`.easeOut(0.12)` 近似 | hover、选中、预览切换（透明度） |
| `motion.base` | 180ms，同曲线 | 面板出现：scale 0.98→1 + fade |
| reduce motion | 尊重系统「减弱动态效果」，动效降级为直切 | 全局 |

## 交互速记

- 选中行：安静灰填充，文字不反白，行右侧显示「粘贴」+ `↩` 按键帽。
- 时间筛选：搜索行右侧下拉（低频功能不占整行），常态显示当前值 + ⌄，hover 灰底，点开原生菜单勾选「全部/今天/昨天/本周/上周/本月」；非「全部」时文字换 accent 提示筛选生效中。
- 键位：↑↓ 选择 · ↩ 粘贴 · ⇧↩ 纯文本 · ⌥↩ 仅复制 · ⌘1-9 快选 · ⌘P 置顶 · ⌘O 打开（链接/图片/文件）· ⌘⌫ 删除 · esc 关闭 · 空格图片预览。
- 鼠标：单击选中（右栏看详情），双击回填粘贴，可直接拖拽条目到其他应用（文本拖为文字，图片/文件拖为文件）。
- 筛选：搜索行右侧两个安静下拉——类型（全部/文本/链接/图片/文件）+ 时间；非默认值时文字换 accent。
