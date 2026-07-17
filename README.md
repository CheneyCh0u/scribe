# Scribe

macOS 菜单栏剪贴板历史工具 —— 快、省内存、键盘优先。

复制/剪切过的文字、图片、文件都被记录，按 <kbd>⌘⇧V</kbd> 唤起面板，搜索、选中、回车，内容直接粘贴回你正在用的应用。

## 特性

- **三种内容类型**：纯文本（保留富文本格式用于保真回填）、图片、文件引用
- **回填粘贴**：选中即模拟 <kbd>⌘V</kbd> 粘贴到原应用；<kbd>⇧↩</kbd> 纯文本粘贴、<kbd>⌥↩</kbd> 仅复制
- **搜索**：唤起即打字过滤，中文子串走 SQLite FTS5 trigram 索引
- **筛选**：类型（文本/链接/图片/文件）+ 时间（今天/昨天/本周/上周/本月）双下拉
- **日期分组** + 置顶（Pin 的条目不受自动清理影响）
- **去重置顶**：重复复制不产生新条目，原条目刷新到最上
- **键盘全覆盖**：<kbd>↑↓</kbd> 选择 · <kbd>↩</kbd> 粘贴 · <kbd>⌘1-9</kbd> 快选 · <kbd>⌘O</kbd> 打开链接/文件/图片 · <kbd>⌘P</kbd> 置顶 · <kbd>⌘⌫</kbd> 删除 · <kbd>空格</kbd> 图片大图预览 · <kbd>esc</kbd> 关闭
- **拖拽**：条目可直接拖进其他应用（文本为文字，图片/文件为文件）
- **隐私**：全部数据本地存储、零网络请求；密码管理器标记的内容默认打码显示（可关闭记录）；支持排除指定应用；菜单栏一键暂停记录
- **自动清理**：按保留天数 + 条数上限双重淘汰，图片文件联动删除
- **原生外观**：材质与色值按 macOS 聚焦（Spotlight）取样，深浅模式随系统

## 安装

### 方式一：下载 Release

从 [Releases](https://github.com/CheneyCh0u/scribe/releases) 下载最新 zip，解压后拖入「应用程序」。

包为 ad-hoc 签名（未经 Apple 公证），首次打开需要：

```bash
xattr -cr /Applications/Scribe.app
```

或右键 → 打开。注意：ad-hoc 签名每个版本不同，**更新版本后需在系统设置中重新授权辅助功能**。

### 方式二：本地构建（推荐长期使用）

用你自己的开发证书签名，辅助功能授权一次长期有效：

```bash
brew install xcodegen
git clone https://github.com/CheneyCh0u/scribe.git && cd scribe
# 将 project.yml 中 DEVELOPMENT_TEAM 改为你的 Team ID
xcodegen generate
xcodebuild -project Scribe.xcodeproj -scheme Scribe -configuration Release build
```

### 首次使用

1. 启动后菜单栏出现剪贴板图标，<kbd>⌘⇧V</kbd> 唤起面板（可在设置中改键）
2. 回填粘贴需要辅助功能权限：菜单栏图标 → 「启用回填粘贴（辅助功能）…」，在系统设置中勾选 Scribe；未授权时降级为复制到剪贴板

## 使用

| 操作 | 方式 |
|---|---|
| 唤起/关闭面板 | <kbd>⌘⇧V</kbd>（默认，可改） |
| 搜索 | 唤起后直接打字 |
| 粘贴 | <kbd>↩</kbd> / 双击 / <kbd>⌘1-9</kbd> |
| 单击 | 选中并在右栏查看详情 |
| 设置 | 菜单栏图标 → 设置…（保留天数、排除应用、开机自启等） |

## 性能

| 指标 | 目标 | 实测 |
|---|---|---|
| 常驻内存（phys_footprint） | < 50 MB | 26 MB |
| 空闲 CPU | ≈ 0% | 200ms 轮询一次整型比较 |

图片采用三级加载策略：列表只解码 ≤400px 缩略图（懒加载 + NSCache）、右栏预览按需降采样 ≤1600px、原图仅在回填瞬间读取。

## 技术栈

Swift + AppKit（非激活 `NSPanel` 面板）+ SwiftUI（内容视图与设置页）；SQLite（[GRDB](https://github.com/groue/GRDB.swift)）+ FTS5 存储；[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 全局热键；CGEvent 模拟粘贴；XcodeGen 管理工程。选型与被否方案见 [docs/001-tech-stack.md](docs/001-tech-stack.md)。

## 开发

```bash
xcodegen generate                                                        # project.yml → xcodeproj（xcodeproj 不入库）
xcodebuild -project Scribe.xcodeproj -scheme Scribe -configuration Debug build
xcodebuild -project Scribe.xcodeproj -scheme Scribe -configuration Debug test   # 单元测试
bash scripts/release.sh                                                  # 打 tag（yyyy.mm.dd-sn）触发 CI 构建发布
```

项目文档体系（见 [docs/process.md](docs/process.md)）：

- [CLAUDE.md](CLAUDE.md)（= AGENTS.md）—— 项目现状摘要，永不过时
- `docs/NNN-*.md` —— 设计决策记录，只增不改：[架构](docs/002-architecture.md) · [功能清单与进度](docs/003-features.md) · [UI 定稿](docs/004-ui-options.md) · [CI 发布](docs/005-ci-release.md)
- [docs/ui/tokens.md](docs/ui/tokens.md) —— UI design token 唯一权威来源，HTML 原型与 Swift 实现与之同步

数据位置：`~/Library/Application Support/Scribe/`（SQLite + 图片目录，删除即完全重置）。

## 项目状态

核心功能（采集/回填/面板/搜索/设置/图片/文件）已完成并在日常使用；Developer ID 公证与 Sparkle 自动更新暂未做（无付费开发者账号）。进度明细见 [docs/003-features.md](docs/003-features.md)。
