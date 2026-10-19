//
//  KeycapItemView.swift
//  KeyGlow
//

import SwiftUI

/// 单个物理质感拟物（Skeuomorph）实体键帽组件
public struct KeycapItemView: View {
    public let style: KeycapStyle
    public let content: KeyDisplayContent
    public var minWidth: CGFloat = 54
    public var height: CGFloat = 54
    public var isSpecialKey: Bool = false
    public var isModifierKey: Bool = false
    public var isEscapeKey: Bool = false

    /// 专属键帽着色（若未指定，则根据按键类型自动选取 AppSettings 对应的颜色选项）
    public var customKeyColor: KeyColorOption?
    public var customBorderColor: BorderColorOption?
    public var customOpacity: Double?

    // 兼容原有接口
    public var accentColor: SpecialKeyColor = .blue

    public init(
        style: KeycapStyle = .classicDark,
        content: KeyDisplayContent,
        minWidth: CGFloat = 54,
        height: CGFloat = 54,
        isSpecialKey: Bool = false,
        isModifierKey: Bool = false,
        isEscapeKey: Bool = false,
        customKeyColor: KeyColorOption? = nil,
        customBorderColor: BorderColorOption? = nil,
        customOpacity: Double? = nil,
        accentColor: SpecialKeyColor = .blue
    ) {
        self.style = style
        self.content = content
        self.minWidth = minWidth
        self.height = height
        self.isSpecialKey = isSpecialKey
        self.isModifierKey = isModifierKey
        self.isEscapeKey = isEscapeKey
        self.customKeyColor = customKeyColor
        self.customBorderColor = customBorderColor
        self.customOpacity = customOpacity
        self.accentColor = accentColor
    }

    // MARK: - 计算当前生效的配色选项

    private var effectiveKeyColor: KeyColorOption {
        if let custom = customKeyColor {
            return custom
        }

        let settings = AppSettings.shared
        if isEscapeKey {
            return settings.escapeColor
        } else if isModifierKey {
            return settings.modifierColor
        } else if isSpecialKey {
            // 特殊功能键（如 Return、Tab、Space、方向键）默认跟随 Escape Color 或 Modifier Color
            return settings.escapeColor
        } else {
            // 普通字符/字母键（Key Color，如 1984s Beige）
            return settings.keyColor
        }
    }

    private var effectiveBorderColor: BorderColorOption {
        customBorderColor ?? AppSettings.shared.borderColor
    }

    private var effectiveOpacity: Double {
        customOpacity ?? AppSettings.shared.keyOpacity
    }

    // MARK: - 主体渲染

    public var body: some View {
        ZStack {
            // 1. 物理侧面立体下沉底座（Extrusion Base，营造键帽物理厚度）
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(effectiveKeyColor.extrusionBaseColor)
                .offset(y: 3)
                .frame(minWidth: minWidth, minHeight: height)

            // 2. 拟物实体按键顶面（Dish Concave Face）
            faceBackgroundLayer
                .frame(minWidth: minWidth, minHeight: height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(concaveDishOverlay)
                .overlay(borderHighlight)

            // 3. 内部激光雕刻/双色注塑字符
            innerContent
                .padding(.horizontal, 10)
        }
        .frame(minWidth: minWidth, minHeight: height + 3) // 包含侧面下沉厚度
        .opacity(effectiveOpacity)
        // 双层立体物理投影：底部真实接触暗影 + 环境光晕投影
        .shadow(color: ambientShadowColor, radius: 10, x: 0, y: 5)
        .shadow(color: contactShadowColor, radius: 2.5, x: 0, y: 2.5)
    }

    // MARK: - 内部图标/文本呈现（带下沉凹刻立体光影）

    @ViewBuilder
    private var innerContent: some View {
        switch content {
        case .symbol(let name, let fallback):
            Image(systemName: name)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(effectiveKeyColor.foregroundColor)
                .shadow(color: effectiveKeyColor.textShadowColor, radius: 0.5, x: 0, y: isLightKey ? 1 : -1)
                .accessibilityLabel(fallback)
        case .text(let str):
            Text(str)
                .font(.system(size: str.count > 2 ? 17 : 22, weight: .semibold, design: .rounded))
                .foregroundColor(effectiveKeyColor.foregroundColor)
                .shadow(color: effectiveKeyColor.textShadowColor, radius: 0.5, x: 0, y: isLightKey ? 1 : -1)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var isLightKey: Bool {
        effectiveKeyColor == .beige1984 || effectiveKeyColor == .pureWhite || effectiveKeyColor == .mambaGreen
    }

    // MARK: - 拟物顶面微弧碟面层（Concave Dish Overlay）

    @ViewBuilder
    private var concaveDishOverlay: some View {
        switch style {
        case .classicDark:
            // 实体拟物：顶部微弱光漫反射与中心内凹渐变
            ZStack {
                // 顶部 1px 微弧高光漫反射
                LinearGradient(
                    colors: [
                        Color.white.opacity(isLightKey ? 0.35 : 0.18),
                        Color.clear,
                        Color.black.opacity(isLightKey ? 0.08 : 0.22)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // 中央内凹碟面光影（中心略暗，边缘稍亮）
                RadialGradient(
                    colors: [
                        Color.black.opacity(isLightKey ? 0.04 : 0.15),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: 28
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

        case .frostedGlass:
            LinearGradient(
                colors: [Color.white.opacity(0.18), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        case .auroraGlow:
            RadialGradient(
                colors: [
                    effectiveKeyColor.color.opacity(0.25),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 2,
                endRadius: 40
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - 顶面材质背景

    @ViewBuilder
    private var faceBackgroundLayer: some View {
        switch style {
        case .classicDark:
            LinearGradient(
                colors: effectiveKeyColor.topFaceColors(for: style),
                startPoint: .top,
                endPoint: .bottom
            )

        case .frostedGlass:
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                effectiveKeyColor.color.opacity(0.20)
            }

        case .auroraGlow:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.11, green: 0.12, blue: 0.18),
                        Color(red: 0.05, green: 0.06, blue: 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                effectiveKeyColor.color.opacity(0.18)
            }
        }
    }

    // MARK: - 边缘微倒角物理高光（Chamfer Border Highlight）

    @ViewBuilder
    private var borderHighlight: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(
                effectiveBorderColor.strokeGradient(for: effectiveKeyColor),
                lineWidth: 1.2
            )
    }

    // MARK: - 阴影色彩

    private var ambientShadowColor: Color {
        effectiveKeyColor.glowColor
    }

    private var contactShadowColor: Color {
        Color.black.opacity(0.45)
    }
}
