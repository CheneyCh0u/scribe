# Scribe — macOS 历史剪切板

macOS 菜单栏常驻应用：记录复制/剪切历史（文字、图片、文件引用等），全局快捷键唤起面板，选中即回填粘贴。核心指标：**快（面板唤起 <100ms）、省内存（常驻 <50MB）**。

## 技术栈

Swift 6 原生：AppKit `NSPanel` 弹窗 + SwiftUI 内容视图；`NSPasteboard.changeCount` 轮询监听；SQLite（GRDB）+ FTS5 存储，图片落盘；KeyboardShortcuts 全局热键；CGEvent 模拟 Cmd+V 回填（需 Accessibility 权限）；`LSUIElement` 菜单栏 agent，非沙盒分发。

完整选型与被否方案见 [docs/001-tech-stack.md](docs/001-tech-stack.md)，架构设计见 [docs/002-architecture.md](docs/002-architecture.md)。

## 目录结构

```
README.md          # 对外介绍（特性/安装/使用），功能变化时同步更新
CLAUDE.md          # 本文件：项目现状摘要 + 索引，保持精简、永不过时
AGENTS.md          # → CLAUDE.md 的软链接（供非 Claude Code 的 agent 识别），永远不要单独编辑它
.claude/skills/    # 项目级 skills（真实目录）
.agents/skills     # → ../.claude/skills 的软链接，两套 agent 共用同一份 skills
.github/           # Issue/PR 模板与 GitHub Actions
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

见 [docs/process.md](docs/process.md)：文档体系分工、CLAUDE.md 维护规则、性能/隐私红线、语言约定。所有改动必须先建 Issue，再从 Issue ID 建分支，通过带 `Closes #ID` 的 PR 合并；完整规则见 [docs/007-git-workflow.md](docs/007-git-workflow.md)，agent 使用项目级 `git-workflow` skill。

## 当前进度

**阶段 1-4 已完成**（2026-07-17）：采集/回填（文本/图片/文件）、双栏面板、搜索筛选、热键、设置页（快捷键/保留策略/隐私/排除应用/自启/存储/清空）、右键菜单、单元测试 11 例。常驻内存实测 26MB（红线 50MB）。Todolist 见 [docs/003-features.md](docs/003-features.md)；UI 定稿见 [docs/004-ui-options.md](docs/004-ui-options.md)，权威 token 在 [docs/ui/tokens.md](docs/ui/tokens.md)。阶段 5 分发已搁置（需付费开发者账号，用户决定不开通；定位个人自用，本机 Apple Development 签名长期使用）。**规划内功能已全部完成**，后续为按需迭代。

## 常用命令

```bash
xcodegen generate        # project.yml → Scribe.xcodeproj（xcodeproj 不入库，改工程结构改 project.yml）
xcodebuild -project Scribe.xcodeproj -scheme Scribe -configuration Debug build
xcodebuild -project Scribe.xcodeproj -scheme Scribe -configuration Debug test   # HistoryStore 单测
open ~/Library/Developer/Xcode/DerivedData/Scribe-*/Build/Products/Debug/Scribe.app
```

数据库位置：`~/Library/Application Support/Scribe/scribe.sqlite`（删除即重置）。

发布：`bash scripts/release.sh` 打 tag（格式 `yyyy.mm.dd-sn`，sn 为当天序号自动 +1），推送后 GitHub Actions（`.github/workflows/release.yml`）自动构建 ad-hoc 签名包并挂 Release。仓库已公开；Developer ID 公证仍搁置（见 003 阶段 5）。

## 已踩的坑

- **TCC 授权按代码签名认应用**：曾用 ad-hoc 签名（`CODE_SIGN_IDENTITY: "-"`），每次构建签名都变，导致辅助功能授权在重新构建后失效（表面上还勾着，实际不生效）。已改为 Apple Development 稳定签名（project.yml：`DEVELOPMENT_TEAM: 9RHHPPZJNY`），授权一次持续有效。**不要改回 ad-hoc**；若换证书/改 Bundle ID，需 `tccutil reset Accessibility com.cheney.scribe` 后重新授权一次。
- **自用装 GitHub Release 包会重新踩上面的坑**（CI 是 ad-hoc 签名）：2026-07-20 用户装了下载版导致回填失效。自用的正确姿势：本机 `xcodebuild -configuration Release build` 后把产物替换到 `/Applications/Scribe.app`，更新同理。另注意别让 DerivedData 的 Debug 实例和 /Applications 版同时运行（双实例抢热键和剪贴板轮询）。
