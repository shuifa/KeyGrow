//
//  KeycapView.swift
//  KeyGlow
//

import SwiftUI

/// 完整按键组合视图（包含修饰键序列、主键位、特殊键独立强调色与物理 Spring 动效）
public struct KeycapView: View {
    public let stroke: KeyStroke
    public let style: KeycapStyle
    public let accentColor: SpecialKeyColor
    public let punchTrigger: Int
    public let repeatCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        stroke: KeyStroke,
        style: KeycapStyle = .classicDark,
        accentColor: SpecialKeyColor = .blue,
        punchTrigger: Int = 0,
        repeatCount: Int = 1
    ) {
        self.stroke = stroke
        self.style = style
        self.accentColor = accentColor
        self.punchTrigger = punchTrigger
        self.repeatCount = repeatCount
    }

    public var body: some View {
        HStack(spacing: 5) {
            // 修饰键列表（⌘ ⌥ ⌃ ⇧ 等，采用 Modifier Color）
            ForEach(stroke.modifiers, id: \.self) { modifier in
                KeycapItemView(
                    style: style,
                    content: .symbol(name: modifier.sfSymbol, fallbackText: modifier.glyph),
                    isSpecialKey: true,
                    isModifierKey: true,
                    isEscapeKey: false,
                    accentColor: accentColor
                )
            }

            // 主按键展示（如果是 Esc，采用 Escape Color；其他特殊键采用 Special Color；普通字母/数字采用 Key Color）
            KeycapItemView(
                style: style,
                content: stroke.content,
                isSpecialKey: stroke.isSpecialFunctionKey,
                isModifierKey: stroke.isModifierOnly,
                isEscapeKey: stroke.rawIdentifier == "esc" || stroke.rawIdentifier == "escape",
                accentColor: accentColor
            )
            .overlay(alignment: .topTrailing) {
                // 连按次数高质感角标（×2, ×3 等，悬浮右上微倒角，不侵占按键内部与外部水平间距）
                if repeatCount > 1 {
                    KeyRepeatBadgeView(
                        count: repeatCount,
                        style: style,
                        accentColor: accentColor
                    )
                    .offset(x: 6, y: -6)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .scale(scale: 0.35, anchor: .center).combined(with: .opacity),
                                removal: .scale(scale: 0.55, anchor: .center).combined(with: .opacity)
                            )
                    )
                }
            }
        }
        .animation(
            reduceMotion ? .easeInOut(duration: 0.18) : .spring(duration: 0.28, bounce: 0.24),
            value: stroke.modifiers
        )
        .animation(.spring(duration: 0.26, bounce: 0.22), value: repeatCount)
        .padding(4)
        // 连按冲击振颤（Tap Punch/Pulse Spring）使用 macOS 14 原生 phaseAnimator
        .phaseAnimator([false, true, false], trigger: punchTrigger) { content, isPunched in
            content
                .scaleEffect(isPunched ? 1.07 : 1.0)
        } animation: { isPunched in
            .spring(response: 0.22, dampingFraction: 0.58, blendDuration: 0)
        }
    }
}

/// 连续按键次数拟物高质感角标（与 KeycapStyle 材质及 SpecialKeyColor 强调色无缝融合）
public struct KeyRepeatBadgeView: View {
    public let count: Int
    public let style: KeycapStyle
    public let accentColor: SpecialKeyColor

    public init(
        count: Int,
        style: KeycapStyle,
        accentColor: SpecialKeyColor
    ) {
        self.count = count
        self.style = style
        self.accentColor = accentColor
    }

    public var body: some View {
        HStack(spacing: 1) {
            Text("×")
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .opacity(0.85)

            Text("\(count)")
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(count)))
        }
        .foregroundColor(badgeForegroundColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .frame(minWidth: 22, minHeight: 18)
        .background(badgeBackground)
        .clipShape(Capsule())
        .overlay(badgeBorder)
        .shadow(color: badgeAmbientShadow, radius: 4, x: 0, y: 2)
        .shadow(color: badgeContactShadow, radius: 1, x: 0, y: 1)
        .animation(.spring(duration: 0.22, bounce: 0.25), value: count)
    }

    // MARK: - 前景文字与符号色彩

    private var badgeForegroundColor: Color {
        if accentColor != .monochrome {
            return accentColor.color
        }

        switch style {
        case .classicDark:
            return Color(white: 0.95)
        case .frostedGlass:
            return Color.primary
        case .auroraGlow:
            return Color(red: 0.0, green: 0.95, blue: 1.0)
        }
    }

    // MARK: - 拟物材质背景层

    @ViewBuilder
    private var badgeBackground: some View {
        switch style {
        case .classicDark:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.23, green: 0.24, blue: 0.28),
                        Color(red: 0.12, green: 0.13, blue: 0.16)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                if accentColor != .monochrome {
                    accentColor.color.opacity(0.16)
                }
            }

        case .frostedGlass:
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Color.white.opacity(0.12)
                if accentColor != .monochrome {
                    accentColor.color.opacity(0.15)
                }
            }

        case .auroraGlow:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.14, blue: 0.22),
                        Color(red: 0.05, green: 0.06, blue: 0.11)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        (accentColor != .monochrome ? accentColor.color : Color(red: 0.0, green: 0.85, blue: 1.0)).opacity(0.32),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 2,
                    endRadius: 18
                )
            }
        }
    }

    // MARK: - 边缘微边框高光

    @ViewBuilder
    private var badgeBorder: some View {
        if accentColor != .monochrome {
            Capsule()
                .strokeBorder(accentColor.borderGradient, lineWidth: 1)
        } else {
            defaultBadgeBorder
        }
    }

    @ViewBuilder
    private var defaultBadgeBorder: some View {
        switch style {
        case .classicDark:
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.45),
                            Color.white.opacity(0.15),
                            Color.black.opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )

        case .frostedGlass:
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.65),
                            Color.white.opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )

        case .auroraGlow:
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 0.0, green: 0.95, blue: 1.0, opacity: 0.85),
                            Color(red: 0.7, green: 0.3, blue: 1.0, opacity: 0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    // MARK: - 阴影配置

    private var badgeAmbientShadow: Color {
        if accentColor != .monochrome {
            return accentColor.glowColor.opacity(0.6)
        }

        switch style {
        case .classicDark:
            return Color.black.opacity(0.4)
        case .frostedGlass:
            return Color.black.opacity(0.16)
        case .auroraGlow:
            return Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.45)
        }
    }

    private var badgeContactShadow: Color {
        Color.black.opacity(0.4)
    }
}
