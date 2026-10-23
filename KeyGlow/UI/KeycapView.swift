//
//  KeycapView.swift
//  KeyGlow
//

import SwiftUI

/// 完整按键组合视图（包含修饰键序列、主键位、主题配色与物理 Spring 动效）
public struct KeycapView: View {
    public let stroke: KeyStroke
    public let theme: KeycapTheme
    public let style: KeycapStyle
    /// 当前渲染外观（由 @Environment(\.colorScheme) 传入，决定取主题的白天档还是夜晚档）
    public let colorScheme: ColorScheme
    public let opacity: Double
    public let punchTrigger: Int
    public let repeatCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        stroke: KeyStroke,
        theme: KeycapTheme = .defaultTheme,
        style: KeycapStyle = .matte,
        colorScheme: ColorScheme = .light,
        opacity: Double = 1.0,
        punchTrigger: Int = 0,
        repeatCount: Int = 1
    ) {
        self.stroke = stroke
        self.theme = theme
        self.style = style
        self.colorScheme = colorScheme
        self.opacity = opacity
        self.punchTrigger = punchTrigger
        self.repeatCount = repeatCount
    }

    /// 当前外观下该主题的四档色板
    private var colorSet: ThemeColorSet {
        theme.colors(for: colorScheme)
    }

    /// 主键位配色（按 Esc / 修饰键 / 特殊功能键 / 普通字符键分别取色）
    private var mainPalette: KeycapPalette {
        colorSet.palette(for: stroke.colorRole)
    }

    public var body: some View {
        HStack(spacing: 4) {
            // 修饰键列表（⌘ ⌥ ⌃ ⇧ 等，统一采用 Modifier 档配色）
            ForEach(stroke.modifiers, id: \.self) { modifier in
                KeycapItemView(
                    style: style,
                    content: .symbol(name: modifier.sfSymbol, fallbackText: modifier.glyph),
                    palette: colorSet.modifier,
                    borderStyle: theme.border,
                    opacity: opacity
                )
            }

            // 主按键展示
            KeycapItemView(
                style: style,
                content: stroke.content,
                palette: mainPalette,
                borderStyle: theme.border,
                opacity: opacity
            )
            .overlay(alignment: .topTrailing) {
                // 连按次数角标（×2, ×3 等）：完全复用主键帽的配色与材质
                if repeatCount > 1 {
                    KeyRepeatBadgeView(
                        count: repeatCount,
                        style: style,
                        palette: mainPalette,
                        borderStyle: theme.border
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
                .scaleEffect(isPunched && !reduceMotion ? 1.07 : 1.0)
        } animation: { isPunched in
            .spring(response: 0.22, dampingFraction: 0.58, blendDuration: 0)
        }
    }
}

/// 连续按键次数拟物高质感角标
/// 设计原则：与主键帽共用同一 `KeycapPalette`，底色取自键帽顶面渐变、字符取自键帽字符色，
/// 边框沿用主题描边策略，从而保证「键帽是什么颜色，连按数字就是什么颜色」。
public struct KeyRepeatBadgeView: View {
    public let count: Int
    public let style: KeycapStyle
    public let palette: KeycapPalette
    public let borderStyle: KeycapBorderStyle

    public init(
        count: Int,
        style: KeycapStyle,
        palette: KeycapPalette,
        borderStyle: KeycapBorderStyle = .adaptive
    ) {
        self.count = count
        self.style = style
        self.palette = palette
        self.borderStyle = borderStyle
    }

    public var body: some View {
        HStack(spacing: 1) {
            Text("×")
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .opacity(0.75)

            Text("\(count)")
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(count)))
        }
        .foregroundColor(palette.foregroundColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .frame(minWidth: 22, minHeight: 18)
        .background(badgeSurface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(borderStyle.strokeGradient(for: palette), lineWidth: 1)
        )
        .shadow(color: palette.glowColor, radius: 3, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.30), radius: 1, x: 0, y: 1)
        .animation(.spring(duration: 0.22, bounce: 0.25), value: count)
    }

    // MARK: - 与键帽同源的拟物材质

    private var badgeSurface: some View {
        ZStack {
            // 侧面下沉厚度：与键帽同源的纵向渐变（上浅下深），
            // 使角标读作「一块小键帽」而不是贴在键帽上的贴纸
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            palette.extrusion.mixed(with: .white, ratio: 0.08).color,
                            palette.extrusion.mixed(with: .black, ratio: 0.30).color
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .offset(y: 1.5)

            // 顶面底色：直接复用键帽材质背景
            KeycapFaceBackground(style: style, palette: palette)
                .clipShape(Capsule())

            // 顶部受光高光
            LinearGradient(
                colors: [
                    Color.white.opacity(palette.isLightSurface ? 0.40 : 0.24),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(Capsule())
        }
    }
}
