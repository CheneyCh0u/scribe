<p align="center">
  <img src="docs/ui/icon-assets/scribe-app-icon.svg" width="144" height="144" alt="Scribe 应用图标">
</p>

<h1 align="center">Scribe</h1>

<p align="center"><strong>把刚刚复制过的东西，立刻找回来。</strong></p>

<p align="center">
  一款安静常驻于 macOS 菜单栏的剪贴板历史工具。<br>
  快、省内存，所有操作都可以只用键盘完成。
</p>

<p align="center">
  <a href="https://github.com/CheneyCh0u/scribe/releases">下载 Scribe</a>
  ·
  <a href="docs/003-features.md">功能清单</a>
  ·
  <a href="docs/002-architecture.md">架构设计</a>
</p>

---

复制或剪切过的文字、图片和文件会自动留在 Scribe 中。按 <kbd>⌘⇧V</kbd> 唤起面板，找到需要的内容，按回车即可粘贴回原来的应用。

## 使用方式

| 1. 照常复制 | 2. 唤起 Scribe | 3. 选中并回填 |
|:---:|:---:|:---:|
| <kbd>⌘C</kbd> | <kbd>⌘⇧V</kbd> | <kbd>↩</kbd> |
| 文字、图片或文件 | 直接输入即可搜索 | 内容粘贴到当前应用 |

## 适合日常使用的细节

### 找得快

- 唤起后直接打字，中文子串搜索使用 SQLite FTS5 trigram 索引
- 可以按文本、链接、图片、文件和日期范围筛选
- 历史记录按日期分组，常用内容可以置顶
- 重复复制不会产生多条记录，原条目会自动回到最上方

### 回填顺手

- <kbd>↩</kbd> 直接粘贴，<kbd>⇧↩</kbd> 以纯文本粘贴，<kbd>⌥↩</kbd> 仅复制
- <kbd>⌘1-9</kbd> 快速选择，<kbd>↑↓</kbd> 浏览，<kbd>esc</kbd> 关闭
- <kbd>⌘O</kbd> 打开链接、文件或图片，<kbd>⌘P</kbd> 置顶，<kbd>⌘⌫</kbd> 删除
- 图片按 <kbd>空格</kbd> 查看大图，所有条目都可以直接拖进其他应用

### 留在本机

- 所有数据只存储在本机，不发送网络请求
- 密码管理器标记的内容默认打码，也可以选择完全不记录
- 支持排除指定应用，菜单栏可以随时暂停记录
- 按保留天数和条数上限自动清理，置顶内容不受影响

## 安装

### 下载 Release

从 [Releases](https://github.com/CheneyCh0u/scribe/releases) 下载最新 zip，解压后拖入「应用程序」。

Release 包使用 ad-hoc 签名，未经 Apple 公证。首次打开前需要运行：

```bash
xattr -cr /Applications/Scribe.app
```

也可以右键点击 Scribe，选择「打开」。ad-hoc 签名会随版本变化，更新后需要在系统设置中重新授权辅助功能。

### 本地构建

如果希望辅助功能授权长期有效，可以使用自己的 Apple Development 证书签名：

```bash
brew install xcodegen
git clone https://github.com/CheneyCh0u/scribe.git
cd scribe
# 将 project.yml 中的 DEVELOPMENT_TEAM 改为你的 Team ID
xcodegen generate
xcodebuild -project Scribe.xcodeproj -scheme Scribe -configuration Release build
```

### 首次启动

1. 启动后，菜单栏会出现 Scribe 图标。按 <kbd>⌘⇧V</kbd> 唤起面板，也可以在设置中更换快捷键。
2. 回填粘贴需要辅助功能权限。点击菜单栏图标，选择「启用回填粘贴（辅助功能）…」，再到系统设置中勾选 Scribe。未授权时，Scribe 会退化为仅复制到剪贴板。

## 常用操作

| 操作 | 快捷方式 |
|---|---|
| 唤起或关闭面板 | <kbd>⌘⇧V</kbd>，默认快捷键，可修改 |
| 搜索 | 唤起后直接输入 |
| 选择上一条或下一条 | <kbd>↑</kbd> / <kbd>↓</kbd> |
| 粘贴 | <kbd>↩</kbd> / 双击 / <kbd>⌘1-9</kbd> |
| 以纯文本粘贴 | <kbd>⇧↩</kbd> |
| 仅复制，不粘贴 | <kbd>⌥↩</kbd> |
| 查看详情 | 单击条目 |
| 打开设置 | 菜单栏图标 → 设置… |

## 性能

Scribe 的目标是面板唤起低于 100ms，常驻内存低于 50MB。

| 指标 | 目标 | 实测 |
|---|---|---|
| 常驻内存（phys_footprint） | < 50 MB | 26 MB |
| 空闲 CPU | 接近 0% | 每 200ms 进行一次整型比较 |

图片采用三级加载策略。列表只解码不超过 400px 的缩略图，并配合懒加载与 NSCache；右栏预览按需降采样至不超过 1600px；原图只在回填瞬间读取。

## 技术实现

Scribe 使用 Swift 6 开发，以 AppKit 的非激活 `NSPanel` 承载面板，SwiftUI 构建内容视图与设置页。历史数据通过 [GRDB](https://github.com/groue/GRDB.swift) 和 SQLite FTS5 存储，[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 负责全局热键，CGEvent 用于模拟粘贴，工程由 XcodeGen 管理。

完整的技术选型和未采用方案见 [docs/001-tech-stack.md](docs/001-tech-stack.md)。

## 开发

```bash
xcodegen generate
xcodebuild -project Scribe.xcodeproj -scheme Scribe -configuration Debug build
xcodebuild -project Scribe.xcodeproj -scheme Scribe -configuration Debug test
bash scripts/release.sh
```

- `xcodegen generate`：从 `project.yml` 生成不入库的 Xcode 工程
- `xcodebuild ... build`：构建 Debug 版本
- `xcodebuild ... test`：运行单元测试
- `scripts/release.sh`：按 `yyyy.mm.dd-sn` 格式打 tag，并触发 CI 构建发布

数据存放在 `~/Library/Application Support/Scribe/`。删除该目录会清空数据库与图片。

## 项目文档

- [CLAUDE.md](CLAUDE.md)（与 AGENTS.md 相同）：项目现状摘要
- [docs/002-architecture.md](docs/002-architecture.md)：架构设计
- [docs/003-features.md](docs/003-features.md)：功能清单与进度
- [docs/004-ui-options.md](docs/004-ui-options.md)：UI 方案与定稿
- [docs/006-icon-options.md](docs/006-icon-options.md)：应用图标与菜单栏图标方案
- [docs/ui/tokens.md](docs/ui/tokens.md)：UI design token 的唯一权威来源
- [docs/ui/icon-options.html](docs/ui/icon-options.html)：保留在项目内的图标方案选择页
- [docs/process.md](docs/process.md)：开发流程与文档维护规则

## 项目状态

采集、回填、面板、搜索、设置、图片和文件支持均已完成，并已投入日常使用。Developer ID 公证和 Sparkle 自动更新暂未实现，原因是当前没有付费开发者账号。进度明细见 [docs/003-features.md](docs/003-features.md)。
