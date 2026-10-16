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

    public init(
        stroke: KeyStroke,
        style: KeycapStyle = .classicDark,
        accentColor: SpecialKeyColor = .blue,
        punchTrigger: Int = 0
    ) {
        self.stroke = stroke
        self.style = style
        self.accentColor = accentColor
        self.punchTrigger = punchTrigger
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
            KeycapItemView(
                style: style,
                content: stroke.content,
                isSpecialKey: stroke.isSpecialFunctionKey,
                accentColor: accentColor
            )
        }
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
