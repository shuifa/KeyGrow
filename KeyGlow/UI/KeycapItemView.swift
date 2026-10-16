//
//  KeycapItemView.swift
//  KeyGlow
//

import SwiftUI

/// 单个物理质感拟物键帽组件
public struct KeycapItemView: View {
    public let style: KeycapStyle
    public let content: KeyDisplayContent
    public var minWidth: CGFloat = 54
    public var height: CGFloat = 54
    public var isSpecialKey: Bool = false
    public var accentColor: SpecialKeyColor = .blue

    public init(
        style: KeycapStyle = .classicDark,
        content: KeyDisplayContent,
        minWidth: CGFloat = 54,
        height: CGFloat = 54,
        isSpecialKey: Bool = false,
        accentColor: SpecialKeyColor = .blue
    ) {
        self.style = style
        self.content = content
        self.minWidth = minWidth
        self.height = height
        self.isSpecialKey = isSpecialKey
        self.accentColor = accentColor
    }

    public var body: some View {
        innerContent
            .contentTransition(.numericText())
            .frame(minWidth: minWidth, minHeight: height)
            .padding(.horizontal, 10)
            .background(backgroundLayer)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(borderHighlight)
            .shadow(color: ambientShadowColor, radius: 10, x: 0, y: 5)
            .shadow(color: contactShadowColor, radius: 2, x: 0, y: 1.5)
    }

    // MARK: - 内部图标/文本呈现

    @ViewBuilder
    private var innerContent: some View {
        switch content {
        case .symbol(let name, let fallback):
            Image(systemName: name)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(foregroundColor)
                .accessibilityLabel(fallback)
        case .text(let str):
            Text(str)
                .font(.system(size: str.count > 2 ? 17 : 22, weight: .semibold, design: .rounded))
                .foregroundColor(foregroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - 拟物键帽背景层

    @ViewBuilder
    private var backgroundLayer: some View {
        switch style {
        case .classicDark:
            ZStack {
                // 深度暗色渐变
                LinearGradient(
                    colors: [
                        Color(red: 0.19, green: 0.20, blue: 0.23),
                        Color(red: 0.11, green: 0.12, blue: 0.14)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // 顶部微弱内凹阴影增强立体感
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.clear,
                        Color.black.opacity(0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // 特殊按键色彩微晕底衬（Keystroke Pro 质感）
                if isSpecialKey && accentColor != .monochrome {
                    accentColor.color.opacity(0.12)
                }
            }

        case .frostedGlass:
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                Color.white.opacity(0.1)
                if isSpecialKey && accentColor != .monochrome {
                    accentColor.color.opacity(0.15)
                }
            }

        case .auroraGlow:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.10, blue: 0.16),
                        Color(red: 0.04, green: 0.05, blue: 0.09)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // 极光渐变弥散内衬
                RadialGradient(
                    colors: [
                        (isSpecialKey && accentColor != .monochrome ? accentColor.color : Color(red: 0.0, green: 0.85, blue: 1.0)).opacity(0.2),
                        Color(red: 0.6, green: 0.2, blue: 1.0).opacity(0.08),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 5,
                    endRadius: 50
                )
            }
        }
    }

    // MARK: - 边缘微边框高光（模拟物理键帽倒角高光）

    @ViewBuilder
    private var borderHighlight: some View {
        if isSpecialKey && accentColor != .monochrome {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(accentColor.borderGradient, lineWidth: 1.2)
        } else {
            defaultBorderHighlight
        }
    }

    @ViewBuilder
    private var defaultBorderHighlight: some View {
        switch style {
        case .classicDark:
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.12),
                            Color.black.opacity(0.45)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )

        case .frostedGlass:
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )

        case .auroraGlow:
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(red: 0.0, green: 0.95, blue: 1.0, opacity: 0.8),
                            Color(red: 0.7, green: 0.3, blue: 1.0, opacity: 0.8),
                            Color(red: 0.2, green: 0.1, blue: 0.4, opacity: 0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        }
    }

    // MARK: - 色彩与阴影配置

    private var foregroundColor: Color {
        if isSpecialKey && accentColor != .monochrome {
            return accentColor.color
        }

        switch style {
        case .classicDark:
            return Color(white: 0.96)
        case .frostedGlass:
            return Color.primary
        case .auroraGlow:
            return Color.white
        }
    }

    private var ambientShadowColor: Color {
        if isSpecialKey && accentColor != .monochrome {
            return accentColor.glowColor
        }

        switch style {
        case .classicDark:
            return Color.black.opacity(0.35)
        case .frostedGlass:
            return Color.black.opacity(0.18)
        case .auroraGlow:
            return Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.3)
        }
    }

    private var contactShadowColor: Color {
        switch style {
        case .classicDark:
            return Color.black.opacity(0.4)
        case .frostedGlass:
            return Color.black.opacity(0.2)
        case .auroraGlow:
            return Color.black.opacity(0.5)
        }
    }
}
