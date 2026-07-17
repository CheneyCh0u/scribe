# Scribe — macOS 历史剪切板

macOS 菜单栏常驻应用：记录复制/剪切历史（文字、图片、文件引用等），全局快捷键唤起面板，选中即回填粘贴。核心指标：**快（面板唤起 <100ms）、省内存（常驻 <50MB）**。

## 技术栈

Swift 6 原生：AppKit `NSPanel` 弹窗 + SwiftUI 内容视图；`NSPasteboard.changeCount` 轮询监听；SQLite（GRDB）+ FTS5 存储，图片落盘；KeyboardShortcuts 全局热键；CGEvent 模拟 Cmd+V 回填（需 Accessibility 权限）；`LSUIElement` 菜单栏 agent，非沙盒分发。

完整选型与被否方案见 [docs/001-tech-stack.md](docs/001-tech-stack.md)，架构设计见 [docs/002-architecture.md](docs/002-architecture.md)。

## 目录结构

```
CLAUDE.md          # 本文件：项目现状摘要 + 索引，保持精简、永不过时
docs/
  process.md       # 开发流程、文档维护规则、项目约定（权威来源）
  NNN-主题.md       # 设计决策记录，编号递增，只增不改
  ui/
    tokens.md      # UI design tokens 唯一权威来源（色/圆角/布局/字体/动效）
    scribe-ui.html # UI 定稿视觉原型（与 tokens.md 同步维护）
    options.html   # 三方案探索记录（历史存档）
project.yml        # XcodeGen 工程定义（Scribe.xcodeproj 由它生成，不入库）
Scribe/            # 应用源码
  App/             # AppDelegate（菜单栏/热键/启动）、DesignTokens
  Store/           # ClipItem、HistoryStore（GRDB + FTS5）
  Clipboard/       # ClipboardMonitor（changeCount 轮询）
  Panel/           # PanelController（NSPanel/键盘）、PanelModel、PanelView
```

## 流程与约定

见 [docs/process.md](docs/process.md)：文档体系分工、CLAUDE.md 维护规则、性能/隐私红线、语言约定。

## 当前进度

**阶段 1 MVP 已完成**（2026-07-17，文本采集→分组面板→搜索筛选→热键全链路已真机验证）。Todolist 见 [docs/003-features.md](docs/003-features.md)；UI 定稿见 [docs/004-ui-options.md](docs/004-ui-options.md)，权威 token 在 [docs/ui/tokens.md](docs/ui/tokens.md)。下一步：阶段 2 回填粘贴（CGEvent ⌘V + Accessibility 引导）。

## 常用命令

```bash
xcodegen generate        # project.yml → Scribe.xcodeproj（xcodeproj 不入库，改工程结构改 project.yml）
xcodebuild -project Scribe.xcodeproj -scheme Scribe -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/Scribe-*/Build/Products/Debug/Scribe.app
```

数据库位置：`~/Library/Application Support/Scribe/scribe.sqlite`（删除即重置）。
