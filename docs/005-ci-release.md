# 005 — CI 构建发布（GitHub Actions）

状态：已采纳（2026-07-17）

## 背景

阶段 5 的 Developer ID 公证因付费账号搁置（见 003），但仓库转为公开后需要一条零成本的分发路径：
tag 触发 GitHub Actions 构建 ad-hoc 签名包，挂 GitHub Release。

## 决策

### Tag 规则（触发器）

- 格式：`yyyy.mm.dd-sn`，如 `2026.07.17-1`
- `sn` = 当天第几次构建，从 1 起，当天每多一次 +1
- **打 tag 统一用 `scripts/release.sh`**：自动 fetch 远端 tag、算出当天下一个序号、打 tag 并推送。不要手工编号
- workflow 触发 glob：`[0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]-[0-9]*`

### 流水线（.github/workflows/release.yml）

`macos-15` runner 五步：

1. `brew install xcodegen` → `xcodegen generate`
2. 跑单测（质量门，失败即不发布）
3. Release 构建，签名统一覆盖为 ad-hoc（CI 无证书）：`CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=`
4. `ditto -c -k --keepParent` 打 zip
5. `gh release create` 挂 Release，release notes 内置首次打开说明（`xattr -cr` / 右键打开）

### 已知限制（刻意接受）

- **ad-hoc 签名未公证**：下载者首开需 `xattr -cr` 或右键打开
- **每个版本签名都不同**：装新版后辅助功能需重新授权（release notes 已写明）
- **自用不走 Release 包**：本机 Apple Development 签名构建的版本授权稳定，日常自用继续 `xcodebuild` 本地构建（见 CLAUDE.md 已踩的坑）
- 公开仓库 Actions 免费；若仓库改回私有，macOS runner 按 10 倍分钟计费

## 发布操作（唯一入口）

```bash
bash scripts/release.sh   # 打当天下一个序号的 tag 并推送，其余全自动
```

失败排查：`gh run list --workflow=release.yml`、`gh run view <id> --log-failed`。
