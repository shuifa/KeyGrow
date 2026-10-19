//
//  KeycapView.swift
//  KeyGlow
//

import SwiftUI

/// 完整按键组合视图（包含修饰键序列、主键位、特殊键独立强调色与物理 Spring 动效）
public struct KeycapView: View {
    public let stroke: KeyStroke
    public let style: KeycapStyle
    /// 兼容保留：早期用于给角标着色的全局强调色，现已改为跟随键帽自身配色
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

    /// 主键位实际生效的配色（与 KeycapItemView 使用同一套角色解析，杜绝角标与键帽不同色）
    private var mainKeyColor: KeyColorOption {
        AppSettings.shared.keyColor(for: stroke.colorRole)
    }

    /// 修饰键配色（⌘ ⌥ ⌃ ⇧ 等统一采用 Modifier Color）
    private var modifierKeyColor: KeyColorOption {
        AppSettings.shared.modifierColor
    }

    private var borderColor: BorderColorOption {
        AppSettings.shared.borderColor
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
                    customKeyColor: modifierKeyColor,
                    customBorderColor: borderColor
                )
            }

            // 主按键展示（按 Esc / 修饰键 / 特殊功能键 / 普通字符键分别取色）
            KeycapItemView(
                style: style,
                content: stroke.content,
                isSpecialKey: stroke.isSpecialFunctionKey,
                isModifierKey: stroke.isModifierOnly,
                isEscapeKey: stroke.colorRole == .escape,
                customKeyColor: mainKeyColor,
                customBorderColor: borderColor
            )
            .overlay(alignment: .topTrailing) {
                // 连按次数角标（×2, ×3 等）：完全复用主键帽的配色与材质，数字颜色与键帽保持一致
                if repeatCount > 1 {
                    KeyRepeatBadgeView(
                        count: repeatCount,
                        style: style,
                        keyColor: mainKeyColor,
                        borderColor: borderColor
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

/// 连续按键次数拟物高质感角标
/// 设计原则：与主键帽共用同一 `KeyColorOption`，底色取自键帽顶面渐变、字符取自键帽字符色，
/// 边框沿用全局 Border Color，从而保证「键帽是什么颜色，连按数字就是什么颜色」。
public struct KeyRepeatBadgeView: View {
    public let count: Int
    public let style: KeycapStyle
    public let keyColor: KeyColorOption
    public let borderColor: BorderColorOption

    public init(
        count: Int,
        style: KeycapStyle,
        keyColor: KeyColorOption,
        borderColor: BorderColorOption = .matching
    ) {
        self.count = count
        self.style = style
        self.keyColor = keyColor
        self.borderColor = borderColor
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
        .foregroundColor(keyColor.foregroundColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .frame(minWidth: 22, minHeight: 18)
        .background(badgeSurface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(borderColor.strokeGradient(for: keyColor), lineWidth: 1)
        )
        .shadow(color: keyColor.glowColor, radius: 4, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.35), radius: 1, x: 0, y: 1)
        .animation(.spring(duration: 0.22, bounce: 0.25), value: count)
    }

    // MARK: - 与键帽同源的拟物材质

    private var badgeSurface: some View {
        ZStack {
            // 侧面下沉厚度，与键帽保持一致的立体关系
            Capsule()
                .fill(keyColor.extrusionBaseColor)
                .offset(y: 1.2)

            // 顶面底色：直接复用键帽材质背景
            KeycapFaceBackground(style: style, keyColor: keyColor)
                .clipShape(Capsule())

            // 顶部受光高光
            LinearGradient(
                colors: [
                    Color.white.opacity(keyColor.isLightSurface ? 0.40 : 0.24),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(Capsule())
        }
    }
}
