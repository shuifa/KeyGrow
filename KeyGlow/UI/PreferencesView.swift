//
//  PreferencesView.swift
//  KeyGlow
//

import SwiftUI

/// 极简拟物、高级典雅的偏好设置面板（参考 Keystroke Pro 视觉规范）
public struct PreferencesView: View {
    @ObservedObject private var settings = AppSettings.shared

    // 当前选中的配色子项：Key Color, Modifier Color, Escape Color, Border Color
    @State private var selectedColorCategory: ColorCategory = .keyColor

    private enum ColorCategory: String, CaseIterable, Identifiable {
        case keyColor = "keyColor"
        case modifierColor = "modifierColor"
        case escapeColor = "escapeColor"
        case borderColor = "borderColor"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .keyColor: return "Key Color"
            case .modifierColor: return "Modifier Color"
            case .escapeColor: return "Escape Color"
            case .borderColor: return "Border Color"
            }
        }

        var localizedTitle: String {
            switch self {
            case .keyColor: return "常规键"
            case .modifierColor: return "修饰键"
            case .escapeColor: return "Esc 键"
            case .borderColor: return "边框高光"
            }
        }
    }

    // 测试预览按键组合 1：修饰键 + 字母键
    private var previewStroke1: KeyStroke {
        KeyStroke(
            modifiers: [.command],
            content: .text("C"),
            rawIdentifier: "cmd+c",
            isShortcut: true,
            isSpecialFunctionKey: false,
            timestamp: Date()
        )
    }

    // 测试预览按键组合 2：独立 Escape 键
    private var previewStroke2: KeyStroke {
        KeyStroke(
            modifiers: [],
            content: .symbol(name: "escape", fallbackText: "Esc"),
            rawIdentifier: "esc",
            isShortcut: true,
            isSpecialFunctionKey: true,
            timestamp: Date()
        )
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 头部 Header
            headerView

            Divider()

            ScrollView {
                VStack(spacing: 22) {
                    // 权限状态提示与引导卡片
                    permissionSection

                    // 实时动效与拟物质感大卡片预览
                    previewSection

                    // 核心配色定制卡片（Key, Modifier, Escape, Border, Opacity）
                    colorCustomizationSection

                    // 视觉风格与尺寸（Style & Size）
                    styleAndSizeSection

                    // 核心参数设置（显示模式、屏幕位置、停留时长）
                    parametersSection

                    // 互动试炼场（即时在屏幕上体验 Spring 动效与字母按键）
                    testActionSection
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 620)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            settings.checkAccessibility()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("KeyGlow 偏好设置")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("拟物实体质感 · 原生丝滑键盘可视化")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $settings.isEnabled)
                .toggleStyle(.switch)
                .help(settings.isEnabled ? "点击暂停按键监听" : "点击开启按键监听")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - 权限状态

    private var permissionSection: some View {
        HStack(spacing: 14) {
            Image(systemName: settings.isAccessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundColor(settings.isAccessibilityGranted ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(settings.isAccessibilityGranted ? "辅助功能权限：已授予" : "需要辅助功能权限")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(settings.isAccessibilityGranted ? "KeyGlow 拥有全局按键监听权限，可正常渲染拟物键帽。" : "macOS 安全机制要求授予辅助功能权限以捕获键盘操作。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !settings.isAccessibilityGranted {
                Button("去授权") {
                    settings.openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Button("刷新") {
                    settings.checkAccessibility()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    // MARK: - 实时质感效果大卡片预览

    private var previewSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("效果实时预览")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Text("最多同时呈现 2 个按键")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .frame(height: 110)

                HStack(spacing: 12) {
                    // 第一个按键卡片（修饰键 + 字母键）
                    KeycapView(
                        stroke: previewStroke1,
                        style: settings.keycapStyle,
                        accentColor: settings.specialKeyColor,
                        punchTrigger: 0,
                        repeatCount: 1
                    )

                    // 第二个按键卡片（Esc 键）
                    KeycapView(
                        stroke: previewStroke2,
                        style: settings.keycapStyle,
                        accentColor: settings.specialKeyColor,
                        punchTrigger: 0,
                        repeatCount: settings.showRepeatCount ? 2 : 1
                    )
                }
                .scaleEffect(0.92)
            }
        }
    }

    // MARK: - 核心配色配置（Key Color, Modifier Color, Escape Color, Border Color, Opacity）

    private var colorCustomizationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("按键个性化配色 (Colors)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Text("参考 Keystroke Pro 独立配色")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // 分类选择器
            Picker("", selection: $selectedColorCategory) {
                ForEach(ColorCategory.allCases) { cat in
                    Text(cat.localizedTitle).tag(cat)
                }
            }
            .pickerStyle(.segmented)

            // 对应类别的具体颜色选择
            switch selectedColorCategory {
            case .keyColor:
                colorPickerRow(
                    title: "常规字母/字符键 (Key Color)",
                    currentSelection: settings.keyColor.rawValue,
                    options: KeyColorOption.allCases.map { ($0.rawValue, $0.title, $0.localizedName, $0.color) },
                    onSelect: { raw in
                        if let opt = KeyColorOption(rawValue: raw) {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                                settings.keyColor = opt
                            }
                        }
                    }
                )

            case .modifierColor:
                colorPickerRow(
                    title: "修饰键配色 (Modifier Color: ⌘ ⌥ ⌃ ⇧)",
                    currentSelection: settings.modifierColor.rawValue,
                    options: KeyColorOption.allCases.map { ($0.rawValue, $0.title, $0.localizedName, $0.color) },
                    onSelect: { raw in
                        if let opt = KeyColorOption(rawValue: raw) {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                                settings.modifierColor = opt
                            }
                        }
                    }
                )

            case .escapeColor:
                colorPickerRow(
                    title: "Escape 与特殊功能键 (Escape Color)",
                    currentSelection: settings.escapeColor.rawValue,
                    options: KeyColorOption.allCases.map { ($0.rawValue, $0.title, $0.localizedName, $0.color) },
                    onSelect: { raw in
                        if let opt = KeyColorOption(rawValue: raw) {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                                settings.escapeColor = opt
                            }
                        }
                    }
                )

            case .borderColor:
                borderColorPickerRow
            }

            Divider()

            // 不透明度调节（Opacity: 50% ~ 100%）
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("键帽不透明度 (Opacity)", systemImage: "circle.lefthalf.filled")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(settings.keyOpacity * 100))%")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.keyOpacity, in: 0.5...1.0, step: 0.05)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private func colorPickerRow(
        title: String,
        currentSelection: String,
        options: [(id: String, title: String, localized: String, color: Color)],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            // 10 种精选色块水平排布网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 10) {
                ForEach(options, id: \.id) { opt in
                    Button {
                        onSelect(opt.id)
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(opt.color)
                                    .frame(width: 30, height: 30)
                                    .shadow(color: opt.color.opacity(0.4), radius: 3, x: 0, y: 1.5)

                                if currentSelection == opt.id {
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: 2.2)
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(opt.id == "beige1984" || opt.id == "pureWhite" || opt.id == "mambaGreen" ? .black : .white)
                                }
                            }

                            Text(opt.title)
                                .font(.system(size: 10, weight: currentSelection == opt.id ? .bold : .regular))
                                .foregroundColor(currentSelection == opt.id ? .primary : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var borderColorPickerRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("倒角高光与微边框 (Border Color)")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 10) {
                ForEach(BorderColorOption.allCases) { opt in
                    Button {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                            settings.borderColor = opt
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(opt.previewColor)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                                )

                            Text(opt.localizedName)
                                .font(.system(size: 11, weight: settings.borderColor == opt ? .bold : .regular))
                                .foregroundColor(settings.borderColor == opt ? .primary : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.8))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    settings.borderColor == opt ? Color.accentColor : Color.clear,
                                    lineWidth: 1.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 视觉样式与尺寸（Style & Size）

    private var styleAndSizeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("质感风格与尺寸 (Style & Size)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // 键帽风格
            HStack(spacing: 12) {
                ForEach(KeycapStyle.allCases) { style in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            settings.keycapStyle = style
                        }
                    } label: {
                        VStack(spacing: 8) {
                            KeycapItemView(
                                style: style,
                                content: .symbol(name: "command", fallbackText: "⌘"),
                                minWidth: 40,
                                height: 40,
                                isSpecialKey: true,
                                isModifierKey: true
                            )

                            Text(style.title)
                                .font(.caption)
                                .fontWeight(settings.keycapStyle == style ? .bold : .regular)
                                .foregroundColor(settings.keycapStyle == style ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    settings.keycapStyle == style ? Color.accentColor : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // 尺寸档位快捷切换 (Small, Medium, Large)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("按键尺寸大小 (Size)", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.subheadline)
                    Spacer()
                    Picker("", selection: Binding<Double>(
                        get: {
                            if abs(settings.sizeScale - 0.85) < 0.05 { return 0.85 }
                            if abs(settings.sizeScale - 1.15) < 0.05 { return 1.15 }
                            return 1.0
                        },
                        set: { newScale in
                            withAnimation(.spring(duration: 0.22)) {
                                settings.sizeScale = newScale
                            }
                        }
                    )) {
                        Text("Small (0.85x)").tag(0.85)
                        Text("Medium (1.0x)").tag(1.0)
                        Text("Large (1.15x)").tag(1.15)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }

                Slider(value: $settings.sizeScale, in: 0.7...1.3, step: 0.05)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    // MARK: - 核心参数

    private var parametersSection: some View {
        VStack(spacing: 16) {
            // 显示过滤模式（默认全按键模式，保证打字及单字母输入直接可见）
            HStack {
                Label("触发模式", systemImage: "slider.horizontal.3")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $settings.displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            Divider()

            // 屏幕位置
            HStack {
                Label("显示位置", systemImage: "macwindow.on.rectangle")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $settings.anchor) {
                    ForEach(DisplayAnchor.allCases) { anchor in
                        Label(anchor.title, systemImage: anchor.iconName).tag(anchor)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 190)
            }

            // 上下边缘距离调节滑块
            if settings.anchor != .mouseFollow {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("上下边缘距离", systemImage: "arrow.up.and.down")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(settings.verticalOffset)) pt")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.verticalOffset, in: 20...220, step: 5)
                }
            }

            Divider()

            // 停留时长滑块（参考 Keystroke Pro 推荐 1.6s）
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("停留时长 (Display Duration)", systemImage: "clock")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f 秒", settings.displayDuration))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.displayDuration, in: 0.5...3.0, step: 0.1)
            }

            Divider()

            // 连按合并开关
            Toggle(isOn: $settings.showRepeatCount) {
                Label("显示连按次数 (×N)", systemImage: "repeat")
                    .font(.subheadline)
            }
            .toggleStyle(.switch)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    // MARK: - 即时体验测试

    private var testActionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("动效体验测试")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("连续点击下方按键体验最多 2 个键帽从右边进左边出的 Spring 动效与拟物配色：")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                // 单独点击字母按键测试（验证需求 3 修复）
                Button {
                    simulateSingle("A", modifiers: [], text: "A", isSpecial: false)
                } label: {
                    Text("字母 A")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    simulateSingle("⌘ C", modifiers: [.command], text: "C", isSpecial: false)
                } label: {
                    Text("⌘ C")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    simulateSingle("Esc", modifiers: [], text: "Esc", isSpecial: true)
                } label: {
                    Text("Esc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button {
                    simulateRepeatSequence()
                } label: {
                    Label("连按 ×3 演示", systemImage: "repeat")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    simulateSequence()
                } label: {
                    Label("双卡推挤演练", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private func simulateSingle(_ id: String, modifiers: [KeyModifier], text: String, isSpecial: Bool = false) {
        let stroke = KeyStroke(
            modifiers: modifiers,
            content: .text(text),
            rawIdentifier: id.lowercased(),
            isShortcut: true,
            isSpecialFunctionKey: isSpecial,
            timestamp: Date()
        )
        KeyMonitor.shared.simulateKeyStroke(stroke)
    }

    private func simulateRepeatSequence() {
        simulateSingle("⌘ C", modifiers: [.command], text: "C")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            simulateSingle("⌘ C", modifiers: [.command], text: "C")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) {
            simulateSingle("⌘ C", modifiers: [.command], text: "C")
        }
    }

    private func simulateSequence() {
        // 先发送卡片 1
        simulateSingle("A", modifiers: [], text: "A", isSpecial: false)
        // 0.26s 后发送卡片 2（队列达到 2 个满额）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            simulateSingle("⌘ C", modifiers: [.command], text: "C")
        }
        // 0.52s 后发送卡片 3（卡片 1 从左侧平滑推出，只保留 2 个）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            simulateSingle("Esc", modifiers: [], text: "Esc", isSpecial: true)
        }
    }
}
