# 002 — 初始架构设计

状态：已采纳（2026-07-17），随实现推进可被后续文档细化

## 模块划分

```
┌─────────────────────────────────────────────────────┐
│ App (LSUIElement agent, 菜单栏图标)                    │
│                                                     │
│  ClipboardMonitor ──写入──▶ HistoryStore ◀──查询── PanelUI │
│  (200ms 轮询)              (GRDB/SQLite)      (NSPanel+SwiftUI) │
│                                │                    ▲       │
│                           ImageStore           HotkeyManager │
│                           (文件落盘+缩略图)     (KeyboardShortcuts) │
│                                                     │       │
│  PasteService ◀──选中条目────────────────────────────┘       │
│  (写回 NSPasteboard + CGEvent Cmd+V)                         │
└─────────────────────────────────────────────────────┘
```

数据单向流动：Monitor → Store → UI → PasteService，无环。

## 各模块职责

### ClipboardMonitor
- Timer 200ms 读 `NSPasteboard.general.changeCount`，变化时读取内容。
- 类型识别优先级：`fileURL` > `png/tiff`（图片）> `string`（富文本降级为纯文本存储，另存 RTF 原文以便回填保真）。
- 过滤：`org.nspasteboard.ConcealedType`、`org.nspasteboard.TransientType` 标记的内容跳过；与上一条内容哈希相同则去重（刷新时间戳置顶）。
- 自己触发的回填复制要跳过（写回时记录标记，Monitor 检测到后忽略一次）。

### HistoryStore（GRDB/SQLite）
- 表 `items`: id, type(text/image/file), content(文本正文/文件路径), preview(截断预览), image_path, byte_size, content_hash, app_bundle_id(来源应用), created_at, last_used_at, pin(置顶)。
- FTS5 虚表对 text 类型的 content 建索引，搜索用。
- 容量策略：默认保留 500 条（可配置），超出按 `last_used_at` 最旧淘汰，pin 的不淘汰；淘汰图片条目时同步删文件。
- 所有写操作在后台队列，UI 读走 GRDB 的 ValueObservation 增量更新。

### ImageStore
- 原图写 `Application Support/Scribe/images/<hash>.png`，同时生成 ≤200px 缩略图 `<hash>.thumb.png`。
- 面板列表只加载缩略图且懒加载；原图仅在回填时读取。这是内存红线的关键实现点。

### HotkeyManager
- KeyboardShortcuts 注册全局快捷键（默认 ⌘⇧V，可在设置中改）。
- 触发时定位面板到当前鼠标/光标所在屏幕，唤起 PanelUI。

### PanelUI
- `NSPanel`，styleMask 含 `.nonactivatingPanel`，不夺取原应用焦点。
- SwiftUI 内容：顶部搜索框 + 虚拟化列表（时间倒序，pin 置顶）。
- 键盘优先：↑↓ 选择、回车回填、Esc 关闭、直接打字即搜索、⌘1-9 快选前 9 条。
- 面板常驻内存（launch 时构建，隐藏而非销毁），保证唤起 <100ms。

### PasteService
- 选中条目 → 按原始类型写回 `NSPasteboard`（文本回填 RTF 原文，图片回填原图）→ 关面板 → CGEvent 发送 Cmd+V 到前台应用。
- 无 Accessibility 权限：降级为仅写回剪贴板，并在面板内提示一次授权入口。

## 测试路径

- 单测：HistoryStore 去重/淘汰/pin 逻辑、类型识别优先级、搜索。
- 手动验收：复制文字/截图/Finder 文件各一次 → 快捷键唤起 → 可见三条 → 回车回填到 TextEdit；复制密码管理器条目不出现在历史；重启应用历史仍在。
- 性能验收：Activity Monitor 常驻内存 <50MB（含 500 条历史、50 张图）；Instruments 测唤起延迟 <100ms。

## 回滚

数据全在 `Application Support/Scribe/`（SQLite + 图片目录），删目录即完全重置，不碰系统状态；Accessibility 授权由用户在系统设置中自行增删。

## 实施阶段（每阶段独立可用）

1. **MVP**：Monitor + Store（仅文本）+ Panel（列表/搜索/回车复制到剪贴板）+ 热键。——已可日常使用。
2. **回填**：PasteService + Accessibility 引导。
3. **图片/文件**：ImageStore + 缩略图 + 文件引用类型。
4. **打磨**：pin、⌘1-9、容量设置、开机自启、Sparkle 自动更新。
