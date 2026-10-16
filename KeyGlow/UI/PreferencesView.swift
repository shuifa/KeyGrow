//
//  PreferencesView.swift
//  KeyGlow
//

import SwiftUI

/// 极简优雅的偏好设置面板
public struct PreferencesView: View {
    @ObservedObject private var settings = AppSettings.shared

    // 测试预览按键组合
    private var previewStroke: KeyStroke {
        KeyStroke(
            modifiers: [.command, .shift],
            content: .text("K"),
            rawIdentifier: "cmd+shift+k",
            isShortcut: true,
            isSpecialFunctionKey: false,
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

                    // 实时动效与质感预览大卡片
                    previewSection

                    // 特殊按键强调色选择（参考 Keystroke Pro）
                    specialKeyColorSection

                    // 视觉风格选择卡片
                    styleSection

                    // 核心参数设置（显示模式、屏幕位置、停留时长）
                    parametersSection

                    // 互动试炼场（即时在屏幕上体验 Spring 动效）
                    testActionSection
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 600)
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
                Text("极简、灵动、丝滑的 macOS 原生按键可视化")
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
                Text(settings.isAccessibilityGranted ? "KeyGlow 拥有系统级按键监听权限，可正常渲染键帽。" : "macOS 安全机制要求授予权限以捕获全局按键。")
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
        VStack(spacing: 12) {
            HStack {
                Text("效果实时预览")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Text("修饰键色彩自动同步")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .frame(height: 100)

                KeycapView(
                    stroke: previewStroke,
                    style: settings.keycapStyle,
                    accentColor: settings.specialKeyColor,
                    punchTrigger: 0
                )
                .scaleEffect(0.9)
            }
        }
    }

    // MARK: - 特殊按键个性化配色（Keystroke Pro 经典体验）

    private var specialKeyColorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("特殊键与修饰键配色")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Text(settings.specialKeyColor.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 14) {
                ForEach(SpecialKeyColor.allCases) { colorOption in
                    Button {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                            settings.specialKeyColor = colorOption
                        }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(colorOption.color)
                                    .frame(width: 32, height: 32)
                                    .shadow(color: colorOption.color.opacity(0.4), radius: 4, x: 0, y: 2)

                                if settings.specialKeyColor == colorOption {
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: 2.5)
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(colorOption == .monochrome ? .black : .white)
                                }
                            }

                            Text(colorOption.title)
                                .font(.system(size: 11, weight: settings.specialKeyColor == colorOption ? .bold : .regular))
                                .foregroundColor(settings.specialKeyColor == colorOption ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
    }

    // MARK: - 视觉样式选择

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("键帽质感风格")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(KeycapStyle.allCases) { style in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            settings.keycapStyle = style
                        }
                    } label: {
                        VStack(spacing: 10) {
                            // 迷你键帽预览
                            KeycapItemView(
                                style: style,
                                content: .symbol(name: "command", fallbackText: "⌘"),
                                minWidth: 44,
                                height: 44,
                                isSpecialKey: true,
                                accentColor: settings.specialKeyColor
                            )
                            .scaleEffect(0.9)

                            Text(style.title)
                                .font(.caption)
                                .fontWeight(settings.keycapStyle == style ? .bold : .regular)
                                .foregroundColor(settings.keycapStyle == style ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
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
        }
    }

    // MARK: - 核心参数

    private var parametersSection: some View {
        VStack(spacing: 16) {
            // 显示过滤模式
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

            // 屏幕锚点（含新增左下角、右下角）
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

            Divider()

            // 停留时长滑块
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("停留时长", systemImage: "clock")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f 秒", settings.displayDuration))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.displayDuration, in: 0.5...3.0, step: 0.1)
            }
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
                Text("连续点击下方按键体验最多 3 个键帽「右边进、左边出」弹簧流式动效：")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Button {
                    simulateSingle("⌘ C", modifiers: [.command], text: "C")
                } label: {
                    Text("⌘ C")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    simulateSingle("⌘ V", modifiers: [.command], text: "V")
                } label: {
                    Text("⌘ V")
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

                Button {
                    simulateSingle("Tab", modifiers: [], text: "Tab", isSpecial: true)
                } label: {
                    Text("Tab")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button {
                    simulateSequence()
                } label: {
                    Label("自动 3 连击", systemImage: "play.fill")
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

    private func simulateSequence() {
        simulateSingle("⌘ C", modifiers: [.command], text: "C")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            simulateSingle("⌘ V", modifiers: [.command], text: "V")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
            simulateSingle("Esc", modifiers: [], text: "Esc", isSpecial: true)
        }
    }
}
