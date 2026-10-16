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
            // 修饰键列表（⌘ ⌥ ⌃ ⇧ 等，作为特殊键着色）
            ForEach(stroke.modifiers, id: \.self) { modifier in
                KeycapItemView(
                    style: style,
                    content: .symbol(name: modifier.sfSymbol, fallbackText: modifier.glyph),
                    isSpecialKey: true,
                    accentColor: accentColor
                )
            }

            // 主按键展示（若为 Esc、Tab、Return 等特殊功能键，自动赋予特殊键强调色）
            HStack(spacing: 2) {
                KeycapItemView(
                    style: style,
                    content: stroke.content,
                    isSpecialKey: stroke.isSpecialFunctionKey,
                    accentColor: accentColor
                )

                // 连按次数徽标（×2, ×3 等）
                if repeatCount > 1 {
                    Text("×\(repeatCount)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }
            }
            .contentTransition(.numericText())
        }
        .animation(
            reduceMotion ? .easeInOut(duration: 0.18) : .spring(duration: 0.28, bounce: 0.24),
            value: stroke.modifiers
        )
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
