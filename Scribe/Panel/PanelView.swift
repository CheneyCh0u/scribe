import SwiftUI

struct PanelView: View {
    @ObservedObject var model: PanelModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Tokens.Colors.divider.frame(height: 1)
            HStack(spacing: 0) {
                list
                    .frame(width: Tokens.Layout.listColumnWidth)
                Tokens.Colors.divider.frame(width: 1)
                preview
            }
            Tokens.Colors.divider.frame(height: 1)
            hints
        }
        .frame(width: Tokens.Layout.panelSize.width, height: Tokens.Layout.panelSize.height)
        .onAppear { searchFocused = true }
    }

    // MARK: - 顶部：搜索 + chips

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(Tokens.Colors.textSecondary)
                TextField("搜索剪贴板历史", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .font(Tokens.Fonts.search)
                    .focused($searchFocused)
            }
            .padding(.horizontal, 2)
            HStack(spacing: Tokens.Space.s3) {
                ForEach(TimeFilter.allCases) { filter in
                    ChipView(title: filter.title, isOn: model.filter == filter) {
                        model.filter = filter
                    }
                }
            }
        }
        .padding(.init(top: 14, leading: 16, bottom: 11, trailing: 16))
    }

    // MARK: - 左栏列表

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(model.sections) { section in
                        Text(section.title)
                            .font(Tokens.Fonts.caption.weight(.semibold))
                            .foregroundStyle(Tokens.Colors.textTertiary)
                            .padding(.init(top: 9, leading: 8, bottom: 4, trailing: 8))
                        ForEach(section.items) { item in
                            RowView(item: item, isSelected: item.id == model.selectedID)
                                .id(item.id)
                                .onTapGesture(count: 2) {
                                    model.selectedID = item.id
                                    model.copySelected()
                                }
                                .onTapGesture {
                                    model.selectedID = item.id
                                }
                        }
                    }
                }
                .padding(.horizontal, Tokens.Space.s3)
                .padding(.vertical, Tokens.Space.s1)
            }
            .onChange(of: model.selectedID) { _, newValue in
                if let newValue {
                    proxy.scrollTo(newValue)
                }
            }
        }
    }

    // MARK: - 右栏预览

    @ViewBuilder
    private var preview: some View {
        if let item = model.selectedItem {
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                ScrollView {
                    Text(item.isConcealed ? "•••••••••••• 已打码内容\n回车仍可粘贴原文" : item.content)
                        .font(item.isConcealed ? Tokens.Fonts.body : previewFont(item))
                        .foregroundStyle(Tokens.Colors.textPrimary)
                        .textSelection(.enabled)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(13)
                }
                .background(Tokens.Colors.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))

                metaGrid(item)
            }
            .padding(.init(top: 14, leading: 16, bottom: 14, trailing: 16))
        } else {
            VStack {
                Spacer()
                Text(model.searchText.isEmpty ? "暂无剪贴板历史\n复制任意内容后会出现在这里" : "没有匹配的结果")
                    .font(Tokens.Fonts.body)
                    .foregroundStyle(Tokens.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func previewFont(_ item: ClipItem) -> Font {
        // 简单启发：多行且含代码常见符号时用等宽
        let looksLikeCode = item.content.contains("\n")
            && (item.content.contains("{") || item.content.contains("(") || item.content.contains("="))
        return looksLikeCode ? Tokens.Fonts.mono : Tokens.Fonts.body
    }

    private func metaGrid(_ item: ClipItem) -> some View {
        Grid(alignment: .leading, horizontalSpacing: Tokens.Space.s4, verticalSpacing: 3) {
            GridRow {
                metaLabel("来源")
                metaValue(item.appName ?? "未知")
            }
            GridRow {
                metaLabel("时间")
                metaValue(Self.timeFormatter.string(from: item.lastUsedAt))
            }
            GridRow {
                metaLabel("类型")
                metaValue("\(item.typeDisplayName) · \(item.characterCount) 字符")
            }
        }
    }

    private func metaLabel(_ text: String) -> some View {
        Text(text)
            .font(Tokens.Fonts.label)
            .foregroundStyle(Tokens.Colors.textTertiary)
            .frame(width: 40, alignment: .leading)
    }

    private func metaValue(_ text: String) -> some View {
        Text(text)
            .font(Tokens.Fonts.label)
            .foregroundStyle(Tokens.Colors.textSecondary)
            .monospacedDigit()
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()

    // MARK: - 底部提示

    private var hints: some View {
        HStack(spacing: 14) {
            hint("↑↓", "选择")
            hint("↩", "粘贴")
            hint("⌘1-9", "快选")
            hint("⌘⌫", "删除")
            hint("esc", "关闭")
            Spacer()
            Text("\(model.totalCount) 条")
                .font(Tokens.Fonts.caption)
                .foregroundStyle(Tokens.Colors.textTertiary)
                .monospacedDigit()
        }
        .padding(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10))
                .foregroundStyle(Tokens.Colors.textSecondary)
                .padding(.init(top: 1, leading: 5, bottom: 1, trailing: 5))
                .background(Tokens.Colors.keycap)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            Text(label)
                .font(Tokens.Fonts.caption)
                .foregroundStyle(Tokens.Colors.textTertiary)
        }
    }
}

// MARK: - 组件

private struct ChipView: View {
    var title: String
    var isOn: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(isOn ? Tokens.Fonts.label.weight(.semibold) : Tokens.Fonts.label)
                .foregroundStyle(Tokens.Colors.textPrimary)
                .padding(.init(top: 4, leading: 12, bottom: 4, trailing: 12))
                .background(
                    Capsule(style: .continuous)
                        .fill(fillColor)
                        .shadow(color: (isOn || hovering) ? .clear : .black.opacity(0.10), radius: 1.25, y: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Tokens.Motion.fast, value: hovering)
        .animation(Tokens.Motion.fast, value: isOn)
    }

    private var fillColor: Color {
        if isOn { return Tokens.Colors.chipSelected }
        if hovering { return Tokens.Colors.rowHover }
        return Tokens.Colors.chipBackground
    }
}

private struct RowView: View {
    var item: ClipItem
    var isSelected: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 9) {
            appIcon
            VStack(alignment: .leading, spacing: 1) {
                Text(item.isConcealed ? "••••••••••••" : item.preview)
                    .font(Tokens.Fonts.body)
                    .foregroundStyle(Tokens.Colors.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Tokens.Fonts.caption)
                    .foregroundStyle(Tokens.Colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if item.pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Tokens.Colors.pinIndicator)
            }
            if isSelected {
                HStack(spacing: 4) {
                    Text("粘贴")
                        .font(Tokens.Fonts.caption)
                        .foregroundStyle(Tokens.Colors.textTertiary)
                    Text("↩")
                        .font(.system(size: 10))
                        .foregroundStyle(Tokens.Colors.textSecondary)
                        .padding(.init(top: 2, leading: 7, bottom: 2, trailing: 7))
                        .background(Tokens.Colors.keycap)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.keycap, style: .continuous))
                }
            } else {
                Text(Self.timeFormatter.string(from: item.lastUsedAt))
                    .font(Tokens.Fonts.caption)
                    .foregroundStyle(Tokens.Colors.textTertiary)
                    .monospacedDigit()
            }
        }
        .padding(.init(top: 7, leading: 9, bottom: 7, trailing: 9))
        .background(isSelected ? Tokens.Colors.rowSelected : (hovering ? Tokens.Colors.rowHover : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.row, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let appName = item.appName { parts.append(appName) }
        parts.append(item.isConcealed ? "已打码" : "\(item.characterCount) 字符")
        return parts.joined(separator: " · ")
    }

    private var appIcon: some View {
        Group {
            if let bundleID = item.appBundleID,
               let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
            } else {
                Image(systemName: "doc.on.clipboard")
                    .foregroundStyle(Tokens.Colors.textSecondary)
            }
        }
        .frame(width: 22, height: 22)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
