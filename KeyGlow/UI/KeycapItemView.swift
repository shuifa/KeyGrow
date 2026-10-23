//
//  KeycapItemView.swift
//  KeyGlow
//

import SwiftUI

/// 单个物理质感拟物（Skeuomorph）实体键帽组件
///
/// 自 0.12 起，颜色不再由视图内部猜测，而是由调用方传入 `KeycapPalette`（通常来自当前主题 + 按键角色），
/// 视图本身只负责「材质、光照、排版」三件事。
public struct KeycapItemView: View {
    public let style: KeycapStyle
    public let content: KeyDisplayContent
    public let palette: KeycapPalette
    public let borderStyle: KeycapBorderStyle

    public var minWidth: CGFloat = 54
    public var height: CGFloat = 54
    public var opacity: Double = 1.0

    public init(
        style: KeycapStyle = .matte,
        content: KeyDisplayContent,
        palette: KeycapPalette,
        borderStyle: KeycapBorderStyle = .adaptive,
        minWidth: CGFloat = 54,
        height: CGFloat = 54,
        opacity: Double = 1.0
    ) {
        self.style = style
        self.content = content
        self.palette = palette
        self.borderStyle = borderStyle
        self.minWidth = minWidth
        self.height = height
        self.opacity = opacity
    }

    // MARK: - 动态尺寸与字体规范（根据键帽高度自适应缩放）

    private var cornerRadius: CGFloat {
        max(6, round(height * 0.22))
    }

    private var singleCharFontSize: CGFloat {
        max(11, round(height * 0.33))
    }

    private var multiCharFontSize: CGFloat {
        max(10, round(height * 0.24))
    }

    private var horizontalPadding: CGFloat {
        max(6, round(height * 0.16))
    }

    /// SF Symbols 各自的光学包围盒并不一致（⌃ 明显偏小、⌘ 偏大），
    /// 统一按符号做一次视觉尺寸校正，保证一排修饰键看起来是「同号字」。
    private var symbolOpticalScale: CGFloat {
        guard case .symbol(let name, _) = content else { return 1.0 }
        switch name {
        case "command": return 0.94
        case "control": return 1.16
        case "option": return 1.03
        case "shift": return 1.0
        case "capslock": return 1.02
        default: return 1.0
        }
    }

    // MARK: - 主体渲染

    public var body: some View {
        innerContent
            .padding(.horizontal, horizontalPadding)
            .frame(minWidth: minWidth, minHeight: height)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                ZStack {
                    // 1. 物理侧面立体下沉底座（Extrusion Base，营造键帽物理厚度）
                    RoundedRectangle(cornerRadius: cornerRadius + 1, style: .continuous)
                        .fill(palette.extrusion.color)
                        .offset(y: 3)

                    // 2. 拟物实体按键顶面（Dish Concave Face）
                    faceBackgroundLayer
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .overlay(concaveDishOverlay)
                        .overlay(borderHighlight)
                }
            )
            .frame(minHeight: height + 3) // 包含侧面下沉厚度
            .opacity(opacity)
            // 双层立体物理投影：低强度彩色环境光晕 + 中性接触暗影（保证边缘锐度，避免彩雾）
            .shadow(color: palette.glowColor, radius: 4, x: 0, y: 3)
            .shadow(color: Color.black.opacity(0.34), radius: 2, x: 0, y: 1.5)
    }

    // MARK: - 内部图标/文本呈现

    @ViewBuilder
    private var innerContent: some View {
        switch content {
        case .symbol(let name, let fallback):
            Image(systemName: name)
                .font(.system(size: singleCharFontSize, weight: .semibold))
                .scaleEffect(symbolOpticalScale)
                .foregroundColor(palette.foregroundColor)
                .shadow(color: palette.textShadowColor, radius: 0.5, x: 0, y: palette.isLightSurface ? 1 : -1)
                .accessibilityLabel(fallback)

        case .text(let str):
            Text(str)
                .font(.system(size: str.count > 2 ? multiCharFontSize : singleCharFontSize, weight: .semibold, design: .rounded))
                .foregroundColor(palette.foregroundColor)
                .shadow(color: palette.textShadowColor, radius: 0.5, x: 0, y: palette.isLightSurface ? 1 : -1)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .accessibilityLabel(str)
        }
    }

    // MARK: - 拟物顶面微弧碟面层（Concave Dish Overlay）

    @ViewBuilder
    private var concaveDishOverlay: some View {
        switch style {
        case .matte:
            ZStack {
                // 顶部微弧受光面
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(palette.isLightSurface ? 0.40 : 0.32), location: 0.0),
                        .init(color: Color.white.opacity(palette.isLightSurface ? 0.10 : 0.07), location: 0.38),
                        .init(color: Color.clear, location: 0.72),
                        .init(color: Color.black.opacity(palette.isLightSurface ? 0.035 : 0.10), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                // 左上角柔和镜面反射
                RadialGradient(
                    colors: [
                        Color.white.opacity(palette.isLightSurface ? 0.26 : 0.14),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: round(height * 0.62)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                // 中央内凹碟面光影
                RadialGradient(
                    colors: [
                        Color.black.opacity(palette.isLightSurface ? 0.018 : 0.06),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: round(height * 0.52)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }

        case .frosted:
            ZStack {
                LinearGradient(
                    colors: [Color.white.opacity(palette.isLightSurface ? 0.18 : 0.26), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // 玻璃边缘一圈极细的内反射，避免整块毛玻璃失去层次
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.8)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

        case .aurora:
            RadialGradient(
                colors: [
                    palette.accent.color(opacity: 0.30),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 2,
                endRadius: round(height * 0.78)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    // MARK: - 顶面材质背景

    private var faceBackgroundLayer: some View {
        KeycapFaceBackground(style: style, palette: palette)
    }

    // MARK: - 边缘微倒角物理高光（Chamfer Border Highlight）

    private var borderHighlight: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(borderStyle.strokeGradient(for: palette), lineWidth: 1.2)
    }
}

/// 键帽顶面材质背景（键帽本体与连按角标共用，保证二者的底色、色相与明度完全一致）
struct KeycapFaceBackground: View {
    let style: KeycapStyle
    let palette: KeycapPalette

    var body: some View {
        switch style {
        case .matte:
            LinearGradient(
                colors: palette.topFaceColors,
                startPoint: .top,
                endPoint: .bottom
            )

        case .frosted:
            // 玻璃质感：以主题色本身着色（而非把强调色稀释上去），
            // 否则 0.3x 的淡化会把深海蓝、纸感米白全部洗成灰白，主题辨识度尽失。
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                palette.top.color.opacity(0.66)
                LinearGradient(
                    colors: [Color.white.opacity(palette.isLightSurface ? 0.16 : 0.10), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

        case .aurora:
            // 极光染色：底色由主题色压暗派生（保留色相），而不是写死的近黑，
            // 这样深色键帽在深色桌面上仍能靠霓虹描边与色相区分开。
            ZStack {
                LinearGradient(
                    colors: [
                        palette.bottom.mixed(with: .black, ratio: 0.30).color,
                        palette.bottom.mixed(with: .black, ratio: 0.54).color
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                palette.accent.color(opacity: 0.32)
            }
        }
    }
}
