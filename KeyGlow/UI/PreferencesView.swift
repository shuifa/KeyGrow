//
//  PreferencesView.swift
//  KeyGlow
//
//  偏好设置。信息架构对齐 Keystroke Pro 的三层配置面：
//    通用 General  —— 监听状态、权限、连按角标
//    外观 Appearance —— 形态、尺寸、停留时长、四色槽
//    显示 Displays  —— 8 个屏幕吸附点、边距
//

import AppKit
import SwiftUI

public struct PreferencesView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab: PreferencesTab = .appearance

    public enum PreferencesTab: String, CaseIterable, Identifiable {
        case general
        case appearance
        case displays

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .general: return "通用"
            case .appearance: return "外观"
            case .displays: return "显示"
            }
        }

        public var iconName: String {
            switch self {
            case .general: return "gearshape"
            case .appearance: return "paintpalette"
            case .displays: return "display"
            }
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            headerView

            Picker("", selection: $selectedTab) {
                ForEach(PreferencesTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.iconName).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    if !settings.isAccessibilityGranted && selectedTab != .general {
                        permissionBanner
                    }

                    switch selectedTab {
                    case .general: generalTab
                    case .appearance: appearanceTab
                    case .displays: displaysTab
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 600, minHeight: 660)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { settings.checkAccessibility() }
    }

    // MARK: - 顶栏

    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.35), Color(white: 0.16)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    )
                Image(systemName: "keyboard")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("KeyGlow")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(settings.shape.title) · \(settings.displayDurationText) · \(settings.anchor.title)")
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

    // MARK: - 权限提示

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

            Button("刷新") { settings.checkAccessibility() }
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

    // MARK: - 通用

    private var generalTab: some View {
        VStack(spacing: 16) {
            cardSection("监听状态") {
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

                Divider()

                Toggle(isOn: $settings.isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("启用按键可视化")
                            .font(.system(size: 12))
                        Text("关闭后键帽不再上台面，但仍保持菜单栏常驻")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }

            cardSection("显示范围", subtitle: "隐私优先") {
                VStack(alignment: .leading, spacing: 6) {
                    Label("只显示特殊键与组合键", systemImage: "lock.shield")
                        .font(.system(size: 12, weight: .medium))
                    Text("上台面的按键限于 F1–F12、Fn、⌘⌥⌃⇧、方向键、esc、return、delete、tab、space 等特殊键，以及它们与任意按键组成的组合（如 ⌘S、⌃⇧Tab）。单独输入字母、数字与标点时一律静默，不会出现在录屏里。")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                Toggle(isOn: $settings.showRepeatCount) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("显示连按次数（×N）")
                            .font(.system(size: 12))
                        Text("同一按键连续按下时原地计数，而不是不断推挤新的键帽组")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Label("长按驻留", systemImage: "hand.tap")
                        .font(.system(size: 12, weight: .medium))
                    Text("按住不放时键帽持续驻留，松开后才开始计算停留时长。此行为始终开启。")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            cardSection("配置") {
                HStack(spacing: 8) {
                    Button("恢复出厂设置") {
                        withAnimation { settings.resetToDefaults() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    Text("KeyGlow \(appVersion) · MIT License")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 外观

    private var appearanceTab: some View {
        VStack(spacing: 16) {
            previewCard
            shapeSection
            sizeSection
            durationSection
            colorSlotSection
        }
    }

    /// 实时预览：桌面模拟底 + 真实键帽组渲染
    private var previewCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("实时预览")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(settings.shape.title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(desktopSimulation)
                    .frame(height: 150)

                HStack(spacing: previewMetrics.groupSpacing) {
                    KeycapGroupView(
                        stroke: sampleStroke([.command], KeyLegend(text: "S"), "cmd+s"),
                        slots: settings.colorSlots,
                        metrics: previewMetrics,
                        shape: settings.shape,
                        repeatCount: 1,
                        appearance: appearance
                    )
                    KeycapGroupView(
                        stroke: sampleStroke([], KeyLegend(symbol: "escape", text: "escape", widthUnits: 1.25), "esc"),
                        slots: settings.colorSlots,
                        metrics: previewMetrics,
                        shape: settings.shape,
                        repeatCount: 1,
                        appearance: appearance
                    )
                    KeycapGroupView(
                        stroke: sampleStroke([], KeyLegend(text: "f5"), "f5"),
                        slots: settings.colorSlots,
                        metrics: previewMetrics,
                        shape: settings.shape,
                        repeatCount: 2,
                        appearance: appearance
                    )
                }
                .fixedSize()
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    /// 预览尺寸跟随滑条，但封顶 1.5x，避免大尺寸时把卡片撑破
    private var previewMetrics: KeycapMetrics {
        KeycapMetrics(height: AppSettings.Defaults.baseKeycapHeight * min(settings.sizeScale, 1.5))
    }

    private var appearance: NSAppearance? {
        NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
    }

    private var desktopSimulation: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color(white: 0.22), Color(white: 0.11)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [Color(white: 0.96), Color(white: 0.84)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var shapeSection: some View {
        cardSection("键帽形态", subtitle: "两种外形架构") {
            HStack(spacing: 10) {
                ForEach(KeycapShape.allCases) { shape in
                    shapeCard(shape)
                }
            }
        }
    }

    private func shapeCard(_ shape: KeycapShape) -> some View {
        let isSelected = settings.shape == shape
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                settings.shape = shape
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 6) {
                    KeycapGroupView(
                        stroke: sampleStroke([.command], KeyLegend(text: "S"), "cmd+s"),
                        slots: settings.colorSlots,
                        metrics: KeycapMetrics(height: 34),
                        shape: shape,
                        appearance: appearance
                    )
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                    }
                }
                .frame(height: 56)

                Text(shape.title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(.primary)

                Text(shape.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private var sizeSection: some View {
        cardSection("按键尺寸", subtitle: "1080p 紧凑 → 4K 录制超大") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "minus.magnifyingglass")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2fx · %.0f pt", settings.sizeScale, settings.metrics.height))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "plus.magnifyingglass")
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: $settings.sizeScale,
                    in: AppSettings.Defaults.sizeScaleRange,
                    step: 0.05
                )
                Text("字符全部按矢量渲染，放大到 4K 录制尺寸也不会发虚。")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var durationSection: some View {
        cardSection("停留时长", subtitle: "松开按键后开始计时") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "tortoise")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(settings.displayDurationText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "hare")
                        .foregroundColor(.secondary)
                }
                Slider(
                    value: $settings.displayDuration,
                    in: AppSettings.Defaults.displayDurationRange,
                    step: 0.05
                )
                Text("推荐 1~2 秒：足够观众读完整个组合，又不会在画面上拖沓。")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 四色槽

    private var colorSlotSection: some View {
        cardSection("配色", subtitle: "四色槽 · 材质字典") {
            VStack(spacing: 10) {
                materialRow(title: "Esc 键", role: .escape)
                Divider()
                materialRow(title: "修饰键", role: .modifier)
                Divider()
                materialRow(title: "按键", role: .key)
                Divider()
                materialRow(title: "底板", role: nil)
            }

            Text("四个色槽彼此独立，任意组合都被允许。中性材质（铝、石墨、深空）上亮下暗，彩色材质上暗下亮——这是原版让彩色键看起来「亮而不飘」的关键。")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 一行色槽：左侧色点 + 名称，右侧材质下拉菜单
    @ViewBuilder
    private func materialRow(title: String, role: KeycapColorRole?) -> some View {
        let current: KeycapMaterial = role.map { settings.colorSlots.material(for: $0) } ?? settings.colorSlots.borderMaterial
        let catalog: [KeycapMaterial] = role == nil ? KeycapMaterial.plateCatalog : KeycapMaterial.keyCatalog

        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            current.palette(appearance: appearance).faceTop.color,
                            current.palette(appearance: appearance).faceBottom.color
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 22, height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.8)
                )

            Text(title)
                .font(.system(size: 12))

            Spacer()

            Menu {
                ForEach(catalog) { material in
                    Button {
                        apply(material, to: role)
                    } label: {
                        if material.id == current.id {
                            Label("\(material.name) · \(material.englishName)", systemImage: "checkmark")
                        } else {
                            Text("\(material.name) · \(material.englishName)")
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(current.name)
                        .font(.system(size: 11))
                    Text(current.englishName)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private func apply(_ material: KeycapMaterial, to role: KeycapColorRole?) {
        var slots = settings.colorSlots
        if let role {
            slots.setMaterialID(material.id, for: role)
        } else {
            slots.border = material.id
        }
        withAnimation(.easeInOut(duration: 0.15)) {
            settings.colorSlots = slots
        }
    }

    // MARK: - 显示

    private var displaysTab: some View {
        VStack(spacing: 16) {
            cardSection("吸附位置", subtitle: "3×3 网格 · 8 个吸附点") {
                HStack(alignment: .top, spacing: 18) {
                    anchorGrid
                    VStack(alignment: .leading, spacing: 8) {
                        Text(settings.anchor.title)
                            .font(.system(size: 13, weight: .semibold))
                        Text(anchorDescription)
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            cardSection("边距", subtitle: "距屏幕可见边缘") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("边缘距离", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.system(size: 12))
                        Spacer()
                        Text("\(Int(settings.edgeInset)) pt")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $settings.edgeInset,
                        in: AppSettings.Defaults.edgeInsetRange,
                        step: 4
                    )
                }
            }

            cardSection("多显示器") {
                Text("键帽会出现在鼠标所在的那块屏幕上，并按该屏幕的可见区域（避开菜单栏与程序坞）计算吸附位置。")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 九宫格锚点选择器：正中心留空（与原版一致，中心位置不可选）
    private var anchorGrid: some View {
        VStack(spacing: 6) {
            ForEach(Array(DisplayAnchor.grid.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, anchor in
                        if let anchor {
                            anchorCell(anchor)
                        } else {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.primary.opacity(0.03))
                                .frame(width: 52, height: 38)
                                .overlay(
                                    Text("屏幕")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary.opacity(0.6))
                                )
                        }
                    }
                }
            }
        }
    }

    private func anchorCell(_ anchor: DisplayAnchor) -> some View {
        let isSelected = settings.anchor == anchor
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                settings.anchor = anchor
            }
        } label: {
            Image(systemName: anchor.iconName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 52, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.primary.opacity(isSelected ? 0 : 0.08), lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(anchor.title)
    }

    private var anchorDescription: String {
        switch settings.anchor.row {
        case .top:
            return "键帽贴着屏幕可见区域的上边缘，新按键从右侧进入，整组向\(settings.anchor.column == .center ? "两侧" : "左")扩张。"
        case .middle:
            return "键帽垂直居中贴在屏幕左侧或右侧，适合与窗口内容并排展示。"
        case .bottom:
            return "键帽贴着屏幕可见区域的下边缘（避开程序坞），最不容易遮挡窗口内容。"
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

    private func sampleStroke(_ modifiers: [KeyModifier], _ legend: KeyLegend, _ identifier: String) -> KeyStroke {
        KeyStroke(
            modifiers: modifiers,
            legend: legend,
            rawIdentifier: identifier,
            isSpecialKey: modifiers.isEmpty,
            isModifierOnly: false
        )
    }
}
