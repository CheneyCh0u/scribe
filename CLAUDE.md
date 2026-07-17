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
Scribe/            # 应用源码（待创建）
```

## 流程与约定

见 [docs/process.md](docs/process.md)：文档体系分工、CLAUDE.md 维护规则、性能/隐私红线、语言约定。

## 当前进度

功能范围与 Todolist 已定稿于 [docs/003-features.md](docs/003-features.md)（5 个阶段）。UI 已定稿于 [docs/004-ui-options.md](docs/004-ui-options.md)：原生材质双栏（左列表右详情），深浅随系统，色值按系统聚焦取样，权威 token 在 [docs/ui/tokens.md](docs/ui/tokens.md)。工程尚未创建，下一步：阶段 1 MVP。

## 常用命令

待工程搭建后补充（构建、测试、打包命令）。
