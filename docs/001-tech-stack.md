# 001 — 技术栈选型

状态：已采纳（2026-07-17）

## 背景

Scribe 是 macOS 历史剪切板工具：常驻后台记录复制/剪切内容（文字、图片、文件引用），全局快捷键唤起面板浏览/搜索，选中后回填到当前应用。硬性要求：

1. **快** — 快捷键按下到面板可交互 <100ms；
2. **省内存** — 常驻 <50MB；
3. 支持文字、图片等多种剪贴板类型；
4. 仅 macOS。

## 决策：Swift 6 原生（AppKit + SwiftUI）

参考对象：**Maccy**（github.com/p0deje/Maccy，同品类最流行的开源实现，Swift 原生，常驻内存 ~30MB），验证了这条路线能同时满足"快"和"省"。

| 组件 | 选型 | 理由 |
|---|---|---|
| 语言/工程 | Swift 6，Xcode 工程 + SwiftPM 依赖 | 平台一等公民；剪贴板/热键/粘贴全是平台 API |
| 弹窗 | AppKit `NSPanel`（`.nonactivatingPanel`）承载 SwiftUI 列表 | 非激活面板不抢焦点，粘贴才能回填到原应用；SwiftUI 写列表快，宿主用 AppKit 保证键盘导航与唤起速度 |
| 剪贴板监听 | Timer 轮询 `NSPasteboard.general.changeCount`，间隔 200ms | macOS 没有剪贴板变更回调 API，轮询是唯一方案（Maccy/Paste 同做法）；对比 Int 的开销可忽略，空闲 CPU ≈0% |
| 存储 | SQLite via GRDB.swift；正文进 DB，启用 FTS5 全文搜索；图片写入 `~/Library/Application Support/Scribe/images/`（含缩略图），DB 只存路径+尺寸+哈希 | 单文件、零运维、随机读快；图片不进 DB 也不进内存，是内存红线的关键 |
| 全局快捷键 | KeyboardShortcuts（sindresorhus/KeyboardShortcuts） | 封装 Carbon `RegisterEventHotKey`，带现成的录制 UI，用户可改键 |
| 粘贴回填 | 写回 `NSPasteboard` + CGEvent 模拟 Cmd+V | 需要 Accessibility 授权；未授权时降级为"仅复制到剪贴板" |
| 应用形态 | `LSUIElement = true` 菜单栏 agent | 无 Dock 图标、无主窗口，符合工具定位 |
| 分发 | 非沙盒，Developer ID 签名 + 公证，App Store 外分发 | 模拟粘贴需要 Accessibility，沙盒内不可用 |

## 被否方案

- **Electron**：常驻内存 150MB+，冷启动慢，直接违背两条硬指标。否。
- **Tauri（Rust + WebView）**：二进制小，但 WKWebView 常驻 ~80MB+，弹窗首帧慢；且剪贴板监听、热键、模拟粘贴仍要写原生桥接，等于两套栈。否。
- **纯 SwiftUI 窗口（`Window`/`MenuBarExtra`）做弹窗**：`MenuBarExtra` 面板焦点行为不可控、无法做非激活浮层，回填粘贴做不了。否，仅设置窗口用纯 SwiftUI。
- **Core Data 存储**：对"按时间倒序 + 全文搜索"这种简单模式是负资产，FTS 还得自己桥 SQLite。否。

## 最脆弱假设

本方案假设 **200ms 轮询能接住所有复制事件**。若某应用连续快速写剪贴板（<200ms 两次），中间态会丢。接受：人手动复制达不到这个频率，同类产品同样取舍；如未来出现真实投诉，可把间隔降到 100ms（开销仍可忽略）。

## 依赖清单

- Xcode 26 / Swift 6（本机已有）
- SwiftPM 包：GRDB.swift、KeyboardShortcuts（首次构建时拉取）
- 分发需要 Apple Developer ID 证书（开发阶段不需要）
