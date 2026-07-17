# 007 — Issue-first GitHub 工作流

状态：已采用（2026-07-17）

## 背景

项目此前允许直接在 `main` 修改、提交和推送，功能、修复、文档与发布之间缺少稳定的追踪关系。随着公开仓库开始持续迭代，需要让每项变更都有问题背景、独立分支、可审阅差异和明确的关闭记录。

## 决策

所有仓库改动统一采用以下闭环，包括 `feat`、`fix`、`docs`、`core`、`refactor`、`test`、`perf`、`build`、`ci` 和 `chore`：

```text
Issue → 含 Issue ID 的分支 → Conventional Commit → PR → owner 合并 → Issue 自动关闭
```

普通合并与发布解耦。只有明确提出发布时才运行 `scripts/release.sh` 并创建 `yyyy.mm.dd-sn` tag；分支推送和 PR 合并本身不触发 Release 工作流。

## Issue

开始修改前先搜索是否存在相同的开放 Issue。没有时使用 [变更申请模板](../.github/ISSUE_TEMPLATE/change.yml) 创建，至少写明：

- 变更类型
- 背景与问题
- 目标和不包含范围
- 可验证的验收标准
- 影响范围
- 风险、验证与回滚
- 是否需要独立发布

紧急修复也必须先建 Issue，可以先写最小信息，但在合并前补全。

## 分支

分支必须包含 Issue ID，且从最新的 `origin/main` 创建：

```text
<type>/<issue-id>-<short-slug>
codex/issue-<issue-id>-<short-slug>
```

例如：

```text
fix/42-double-click-paste
docs/57-install-guide
codex/issue-61-settings-layout
```

禁止在 `main` 上实施改动。若发现工作区已有未提交内容，先创建 Issue，再切换到对应分支并保留现有内容。

## 提交

提交信息使用 Conventional Commit，正文只引用 Issue，不提前关闭：

```text
fix(panel): restore double-click paste

Refs #42
```

`core` 用于项目基础规则或架构层改动。提交信息和代码注释使用英文，文档使用中文。

## Pull Request

所有进入 `main` 的改动都必须通过 PR，使用 [PR 模板](../.github/pull_request_template.md)。PR 标题继续使用 Conventional Commit，以便 squash merge 后保持一致的主分支历史。

PR 正文必须包含真实关闭关键字：

```text
Closes #42
```

GitHub 只会在 PR 合并到默认分支后自动关闭关联 Issue。不要把 `Closes`、`Fixes` 或 `Resolves` 写进普通提交信息。

## 合并权限

`main` 由 GitHub ruleset 保护：只有仓库拥有者可以通过 PR 更新主分支。直接推送到 `main` 不属于正常工作流；合并前必须确认 Issue 关联正确、验证完成、文档同步。

默认使用 squash merge。合并后确认 Issue 已自动关闭，并删除远端分支。

## Agent 支持

项目内的 `git-workflow` skill 位于 `.claude/skills/git-workflow/`；`.agents/skills` 是指向 `.claude/skills` 的软链接，两套 agent 读取同一份规则。

调用示例：

```text
Use $git-workflow to implement this change through an Issue-linked branch and PR.
```

## 被否方案

- **只依赖提交信息**：无法记录验收条件和讨论，也不能形成自动关闭关系。
- **允许小改动直接推 main**：难以定义“小改动”，最终会让规则逐渐失效。
- **每次合并都自动发布**：把代码集成和用户发布绑定，增加无意义构建与频繁的辅助功能重新授权。
