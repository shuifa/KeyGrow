//
//  PreferencesView.swift
//  KeyGlow
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// 偏好设置面板
///
/// 0.12 起的信息架构：把原来单列滚动堆叠的 6 大块，重组为「外观 / 行为 / 高级」三页，
/// 并且配色不再逐类调节，而是从内置主题里选一套（每套自带白天 / 夜晚两档）。
public struct PreferencesView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab: PreferencesTab = .appearance
    @State private var statusMessage: String?

    public enum PreferencesTab: String, CaseIterable, Identifiable {
        case appearance
        case behavior
        case advanced

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .appearance: return "外观"
            case .behavior: return "行为"
            case .advanced: return "高级"
            }
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            headerView

            Picker("", selection: $selectedTab) {
                ForEach(PreferencesTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // 高级页已有「权限与状态」卡片，这里不再重复提示
                    if !settings.isAccessibilityGranted && selectedTab != .advanced {
                        permissionBanner
                    }

                    switch selectedTab {
                    case .appearance: appearanceTab
                    case .behavior: behaviorTab
                    case .advanced: advancedTab
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 580, minHeight: 700)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            settings.checkAccessibility()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 17))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("KeyGlow 偏好设置")
                    .font(.system(size: 13, weight: .semibold))
                Text("主题：\(settings.theme.name) · \(colorScheme == .dark ? "夜晚" : "白天")档")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $settings.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .help(settings.isEnabled ? "点击暂停按键监听" : "点击开启按键监听")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - 权限提示（未授权时才出现，已授权不再占据版面）

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("需要辅助功能权限")
                    .font(.system(size: 12, weight: .medium))
                Text("macOS 要求授予辅助功能权限，才能全局捕获键盘操作。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("去授权") {
                settings.requestAccessibilityPermission()
                settings.openAccessibilitySettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("刷新") {
                settings.checkAccessibility()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - 外观页

    private var appearanceTab: some View {
        VStack(spacing: 16) {
            previewCard
            themeSection
            appearanceModeSection
            materialSection
            sizeAndOpacitySection
        }
    }

    /// 实时预览：浅/深两种桌面背景都示意，键帽始终有稳定对比度
    private var previewCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("效果实时预览")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(settings.maxVisibleKeys) 键上限 · \(settings.theme.name)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(desktopSimulation)
                    .frame(height: 132)

                HStack(spacing: 18) {
                    KeycapView(
                        stroke: sampleStroke([.command], "C", identifier: "cmd+c"),
                        theme: settings.theme,
                        style: settings.keycapStyle,
                        colorScheme: colorScheme,
                        opacity: settings.keyOpacity
                    )
                    KeycapView(
                        stroke: sampleStroke([], "esc", special: true, identifier: "esc"),
                        theme: settings.theme,
                        style: settings.keycapStyle,
                        colorScheme: colorScheme,
                        opacity: settings.keyOpacity
                    )
                    KeycapView(
                        stroke: sampleStroke([], "A", identifier: "a", repeatCount: 3),
                        theme: settings.theme,
                        style: settings.keycapStyle,
                        colorScheme: colorScheme,
                        opacity: settings.keyOpacity
                    )
                }
                .scaleEffect(0.92)
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private var desktopSimulation: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color(white: 0.20), Color(white: 0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(white: 0.97), Color(white: 0.87)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var themeSection: some View {
        cardSection("配色主题", subtitle: "\(KeycapTheme.all.count) 套 · 每套含白天 / 夜晚") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(KeycapTheme.all) { theme in
                    themeCard(theme)
                }
            }
        }
    }

    private func themeCard(_ theme: KeycapTheme) -> some View {
        let isSelected = settings.themeID == theme.id
        let colors = theme.colors(for: colorScheme)

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                settings.themeID = theme.id
                settings.keycapStyle = theme.recommendedStyle
            }
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    KeycapItemView(
                        style: settings.keycapStyle,
                        content: .symbol(name: "command", fallbackText: "⌘"),
                        palette: colors.modifier,
                        borderStyle: theme.border,
                        minWidth: 32,
                        height: 32
                    )
                    KeycapItemView(
                        style: settings.keycapStyle,
                        content: .text("C"),
                        palette: colors.regular,
                        borderStyle: theme.border,
                        minWidth: 32,
                        height: 32
                    )
                    KeycapItemView(
                        style: settings.keycapStyle,
                        content: .text("esc"),
                        palette: colors.escape,
                        borderStyle: theme.border,
                        minWidth: 38,
                        height: 32
                    )
                    KeycapItemView(
                        style: settings.keycapStyle,
                        content: .symbol(name: "arrow.left", fallbackText: "←"),
                        palette: colors.special,
                        borderStyle: theme.border,
                        minWidth: 32,
                        height: 32
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Text(theme.name)
                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                    }
                }

                Text(theme.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var appearanceModeSection: some View {
        cardSection("外观模式", subtitle: colorScheme == .dark ? "当前：夜晚档" : "当前：白天档") {
            Picker("", selection: $settings.appearanceMode) {
                ForEach(ThemeAppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text("「跟随系统」会随 macOS 浅色/深色自动切换该主题的白天与夜晚配色，无需手动改主题。")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    private var materialSection: some View {
        cardSection("键帽材质", subtitle: "与主题解耦，可单独覆盖") {
            HStack(spacing: 10) {
                ForEach(KeycapStyle.allCases) { style in
                    materialButton(style)
                }
            }
        }
    }

    private func materialButton(_ style: KeycapStyle) -> some View {
        let isSelected = settings.keycapStyle == style
        // 用修饰键配色做预览：普通键是中性灰，三种材质的差别会被压得很不明显
        let palette = settings.theme.colors(for: colorScheme).modifier

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                settings.keycapStyle = style
            }
        } label: {
            VStack(spacing: 7) {
                KeycapItemView(
                    style: style,
                    content: .symbol(name: "command", fallbackText: "⌘"),
                    palette: palette,
                    borderStyle: settings.theme.border,
                    minWidth: 38,
                    height: 38
                )
                Text(style.title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(style.subtitle)
    }

    private var sizeAndOpacitySection: some View {
        cardSection("尺寸与不透明度") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("按键尺寸", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12))
                    Spacer()
                    Text(String(format: "%.2fx", settings.sizeScale))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.sizeScale, in: 0.6...1.8, step: 0.05)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("键帽不透明度", systemImage: "circle.lefthalf.filled")
                        .font(.system(size: 12))
                    Spacer()
                    Text("\(Int(settings.keyOpacity * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.keyOpacity, in: 0.5...1.0, step: 0.05)
            }

            Divider()

            Toggle(isOn: $settings.showKeycapTray) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("键帽托盘")
                        .font(.system(size: 12))
                    Text("在键帽下方垫一层半透明底板，浅色桌面下对比度更稳")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
    }

    // MARK: - 行为页

    private var behaviorTab: some View {
        VStack(spacing: 16) {
            cardSection("触发模式") {
                Picker("", selection: $settings.displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(settings.displayMode.description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            cardSection("显示位置") {
                Picker("", selection: $settings.anchor) {
                    ForEach(DisplayAnchor.allCases) { anchor in
                        Label(anchor.title, systemImage: anchor.iconName).tag(anchor)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)

                if settings.anchor != .mouseFollow {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("上下边缘距离", systemImage: "arrow.up.and.down")
                                .font(.system(size: 12))
                            Spacer()
                            Text("\(Int(settings.verticalOffset)) pt")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.verticalOffset, in: 20...220, step: 5)
                    }
                }
            }

            cardSection("节奏") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("停留时长", systemImage: "clock")
                            .font(.system(size: 12))
                        Spacer()
                        Text(String(format: "%.1f 秒", settings.displayDuration))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.displayDuration, in: 0.5...3.0, step: 0.1)
                }

                Divider()

                HStack {
                    Label("同屏最多保留", systemImage: "square.stack.3d.up")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $settings.maxVisibleKeys) {
                        ForEach(Array(AppSettings.Defaults.maxVisibleKeysRange), id: \.self) { value in
                            Text("\(value) 个").tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 220)
                }

                Divider()

                Toggle(isOn: $settings.showRepeatCount) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("显示连按次数 (×N)")
                            .font(.system(size: 12))
                        Text("开启后同一按键连按会原地计数，而不是不断推挤卡片")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
        }
    }

    // MARK: - 高级页

    private var advancedTab: some View {
        VStack(spacing: 16) {
            cardSection("权限与状态") {
                HStack(spacing: 10) {
                    Image(systemName: settings.isAccessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(settings.isAccessibilityGranted ? .green : .orange)
                    Text(settings.isAccessibilityGranted ? "辅助功能权限已授予" : "辅助功能权限未授予")
                        .font(.system(size: 12))
                    Spacer()
                    Button("刷新") { settings.checkAccessibility() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            cardSection("动效体验", subtitle: "在屏幕上实际渲染一次") {
                HStack(spacing: 8) {
                    Button("字母 A") { simulateSingle("a", modifiers: [], text: "A") }
                        .buttonStyle(.borderedProminent)
                    Button("⌘ C") { simulateSingle("cmd+c", modifiers: [.command], text: "C") }
                        .buttonStyle(.bordered)
                    Button("esc") { simulateSingle("esc", modifiers: [], text: "esc", isSpecial: true) }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("连按 ×3") { simulateRepeatSequence() }
                        .buttonStyle(.bordered)
                }
                .controlSize(.small)
            }

            cardSection("配置") {
                HStack(spacing: 8) {
                    Button("恢复默认") {
                        withAnimation { settings.resetToDefaults() }
                        statusMessage = "已恢复出厂设置"
                    }
                    .buttonStyle(.bordered)

                    Button("导出配置…") { exportSettings() }
                        .buttonStyle(.bordered)

                    Button("导入配置…") { importSettings() }
                        .buttonStyle(.bordered)

                    Spacer()

                    Text(statusMessage ?? "")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .controlSize(.small)
            }

            HStack {
                Spacer()
                Text("KeyGlow \(appVersion) · MIT License")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.top, 4)
        }
    }

    // MARK: - 通用容器

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func cardSection<Content: View>(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.9))
                }
            }
            content()
        }
        .padding(14)
        .background(cardBackground)
    }

    // MARK: - 工具

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "v\(short) (\(build))"
    }

    private func sampleStroke(
        _ modifiers: [KeyModifier],
        _ text: String,
        special: Bool = false,
        identifier: String,
        repeatCount: Int = 1
    ) -> KeyStroke {
        KeyStroke(
            modifiers: modifiers,
            content: .text(text),
            rawIdentifier: identifier,
            isShortcut: !modifiers.isEmpty || special,
            isSpecialFunctionKey: special,
            repeatCount: repeatCount
        )
    }

    // MARK: - 模拟与配置导入导出

    private func simulateSingle(_ id: String, modifiers: [KeyModifier], text: String, isSpecial: Bool = false) {
        let stroke = KeyStroke(
            modifiers: modifiers,
            content: .text(text),
            rawIdentifier: id,
            isShortcut: true,
            isSpecialFunctionKey: isSpecial
        )
        KeyMonitor.shared.simulateKeyStroke(stroke)
    }

    private func simulateRepeatSequence() {
        simulateSingle("cmd+c", modifiers: [.command], text: "C")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [self] in
            simulateSingle("cmd+c", modifiers: [.command], text: "C")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) { [self] in
            simulateSingle("cmd+c", modifiers: [.command], text: "C")
        }
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "KeyGlow-Settings.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try settings.makeSnapshot().encodedJSON().write(to: url, options: .atomic)
            statusMessage = "已导出到 \(url.lastPathComponent)"
        } catch {
            statusMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let snapshot = try SettingsSnapshot.decode(data)
            withAnimation { settings.apply(snapshot) }
            statusMessage = "已导入 \(url.lastPathComponent)"
        } catch {
            statusMessage = "导入失败：\(error.localizedDescription)"
        }
    }
}
