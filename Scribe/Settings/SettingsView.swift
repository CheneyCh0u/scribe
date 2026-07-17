import SwiftUI
import ServiceManagement
import KeyboardShortcuts

struct SettingsView: View {
    let store: HistoryStore

    var body: some View {
        TabView {
            GeneralSettingsTab(store: store)
                .tabItem { Label("通用", systemImage: "gearshape") }
            PrivacySettingsTab()
                .tabItem { Label("隐私", systemImage: "hand.raised") }
            StorageSettingsTab(store: store)
                .tabItem { Label("存储", systemImage: "internaldrive") }
        }
        .frame(
            width: Tokens.Layout.settingsSize.width,
            height: Tokens.Layout.settingsSize.height
        )
    }
}

// MARK: - 通用

private struct GeneralSettingsTab: View {
    let store: HistoryStore
    @AppStorage("retentionDays") private var retentionDays = 30
    @AppStorage("maxItemCount") private var maxItemCount = 1000
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("快捷键") {
                KeyboardShortcuts.Recorder("呼出历史面板", name: .togglePanel)
            }
            Section("历史记录") {
                Stepper(value: $retentionDays, in: 1...365) {
                    HStack {
                        Text("保留最近")
                        Spacer()
                        Text("\(retentionDays) 天").foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                Stepper(value: $maxItemCount, in: 100...10000, step: 100) {
                    HStack {
                        Text("条数上限")
                        Spacer()
                        Text("\(maxItemCount) 条").foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                Text("超期或超量的条目自动清理，置顶条目除外。")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            Section("启动") {
                Toggle("登录时启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .onChange(of: retentionDays) { _, _ in prune() }
        .onChange(of: maxItemCount) { _, _ in prune() }
    }

    private func prune() {
        store.prune(days: retentionDays, maxCount: maxItemCount)
    }
}

// MARK: - 隐私

private struct PrivacySettingsTab: View {
    @AppStorage("recordConcealed") private var recordConcealed = true
    @State private var excluded: [String] = Preferences.excludedBundleIDs

    var body: some View {
        Form {
            Section("敏感内容") {
                Toggle("记录密码类内容", isOn: $recordConcealed)
                Text("开启时，密码管理器等标记为敏感的内容仍会记录，但在列表中打码显示；关闭后不再记录。")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            Section("排除的应用") {
                if excluded.isEmpty {
                    Text("暂无排除应用").foregroundStyle(.tertiary)
                }
                ForEach(excluded, id: \.self) { bundleID in
                    HStack {
                        appLabel(bundleID)
                        Spacer()
                        Button {
                            excluded.removeAll { $0 == bundleID }
                            Preferences.excludedBundleIDs = excluded
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button("添加应用…") { pickApp() }
                Text("来自这些应用的复制不会进入历史。")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func appLabel(_ bundleID: String) -> some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            HStack(spacing: 6) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable().frame(width: 18, height: 18)
                Text(url.deletingPathExtension().lastPathComponent)
                Text(bundleID).font(.caption).foregroundStyle(.tertiary)
            }
        } else {
            Text(bundleID)
        }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.message = "选择要排除的应用"
        guard panel.runModal() == .OK, let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
        if !excluded.contains(bundleID) {
            excluded.append(bundleID)
            Preferences.excludedBundleIDs = excluded
        }
    }
}

// MARK: - 存储

private struct StorageSettingsTab: View {
    let store: HistoryStore
    @State private var itemCount = 0
    @State private var diskUsage = 0
    @State private var confirmingClear = false

    var body: some View {
        Form {
            Section("已用空间") {
                LabeledContent("历史条数", value: "\(itemCount) 条")
                LabeledContent("磁盘占用",
                               value: ByteCountFormatter.string(fromByteCount: Int64(diskUsage), countStyle: .file))
                Button("在访达中显示数据目录") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: Self.dataDir.path)
                }
            }
            Section {
                Button("清空全部历史…", role: .destructive) { confirmingClear = true }
                    .confirmationDialog("确定要清空全部历史吗？", isPresented: $confirmingClear) {
                        Button("清空（不可恢复）", role: .destructive) {
                            store.clearAll()
                            refresh()
                        }
                    } message: {
                        Text("包括置顶条目和所有图片文件，此操作不可恢复。")
                    }
            }
        }
        .formStyle(.grouped)
        .onAppear { refresh() }
    }

    private static var dataDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Scribe")
    }

    private func refresh() {
        itemCount = store.stats().count
        diskUsage = Self.directorySize(Self.dataDir)
    }

    private static func directorySize(_ dir: URL) -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: dir, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        var total = 0
        for case let url as URL in enumerator {
            total += (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
        return total
    }
}
