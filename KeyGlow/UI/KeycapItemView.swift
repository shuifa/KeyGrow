//
//  KeycapItemView.swift
//  KeyGlow
//

import SwiftUI

/// 单个物理质感拟物（Skeuomorph）实体键帽组件
///
/// 自 0.12 起，颜色不再由视图内部猜测，而是由调用方传入 `KeycapPalette`（通常来自当前主题 + 按键角色），
/// 视图本身只负责「材质、光照、排版」三件事。
///
/// 0.14 起立体结构改为「单一侧壁轮廓 + 顶面覆盖」：
/// 旧版把顶面与一块同尺寸的底座错位 3pt 叠放，四个边只有下方露出一点色带，
/// 读起来更像一张带投影的贴纸；新版把键帽本体画成一个**整体拉长的圆角矩形**（含前壁厚度），
/// 顶面按水平方向向内收窄后覆盖其上，于是左右两侧的斜壁、底部的前壁都成为真实可见的体块，
/// 配合「左上来光」的方向光与顶面/前壁交界的折角暗部，形成实体键帽的体积感。
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

    // MARK: - 立体几何规范（全部由键帽高度派生，缩放到任意尺寸比例不变）

    /// 前壁高度：键帽的「物理厚度」，54pt 键帽约 5pt
    private var wallDepth: CGFloat {
        max(3, round(height * 0.095))
    }

    /// 顶面的水平收窄量：收窄后左右两侧的斜壁才会露出来，
    /// 这是「平面贴纸」与「实体键帽」最直接的差别
    private var sideInset: CGFloat {
        max(1, round(height * 0.025))
    }

    /// 顶面圆角：与底座同心收窄，保证转角处侧壁宽度与直边一致，不出现「双描边」
    private var faceCornerRadius: CGFloat {
        max(5, cornerRadius - sideInset)
    }

    /// 侧壁基色：由顶面下沿再压暗派生（而不是直接复用 `extrusion`），
    /// 使「顶面 → 侧壁」成为连续过渡，避免一圈突兀的深色贴边
    private var wallBaseColor: KeyColorRGB {
        palette.bottom.mixed(with: .black, ratio: palette.isLightSurface ? 0.11 : 0.28)
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
            // 键帽壳体绘制在内容之外，前壁向下溢出布局尺寸，因此外层预留 wallDepth
            .background(alignment: .top) { keycapShell }
            .frame(minHeight: height + wallDepth, alignment: .top)
            .opacity(opacity)
            // 三层投影：彩色环境光晕 → 大范围柔和接触影 → 紧贴底沿的锐利投影，
            // 首层负责让键帽"落在"主题色的环境里，后两层负责把键帽压实在桌面上
            .shadow(color: palette.glowColor, radius: 4, x: 0, y: 2)
            .shadow(color: Color.black.opacity(0.16), radius: 7, x: 1, y: 5)
            .shadow(color: Color.black.opacity(0.30), radius: 1.4, x: 0, y: 1.2)
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

    // MARK: - 键帽壳体（侧壁 + 顶面）

    /// 壳体自下而上三层：
    /// 1. 侧壁：一整块「拉长的圆角矩形」，底部多出的 wallDepth 就是前壁厚度；
    /// 2. 方向光：左亮右暗的柱面明暗，说明光从左上打来；
    /// 3. 顶面：左右各收窄 sideInset 后覆盖其上，露出的边缘即斜壁。
    private var keycapShell: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(sideWallGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(sideWallDirectionalLight)
                )
                .frame(height: height + wallDepth)

            topFaceLayer
                .padding(.horizontal, sideInset)
                .frame(height: height)
        }
    }

    /// 侧壁的纵向明暗：上沿接近顶面、越往下越暗，最后半段（前壁）压到最深
    private var sideWallGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: wallBaseColor.mixed(with: .white, ratio: 0.08).color, location: 0.0),
                .init(color: wallBaseColor.color, location: 0.86),
                .init(color: wallBaseColor.mixed(with: .black, ratio: 0.30).color, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// 侧壁的横向方向光：左侧受光提亮、右侧入暗，与分层投影的偏移方向保持一致
    private var sideWallDirectionalLight: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.white.opacity(palette.isLightSurface ? 0.10 : 0.09), location: 0.0),
                .init(color: .clear, location: 0.30),
                .init(color: Color.black.opacity(palette.isLightSurface ? 0.11 : 0.18), location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// 顶面：材质底色 + 碟面光影 + 前壁折角 + 倒角描边
    private var topFaceLayer: some View {
        KeycapFaceBackground(style: style, palette: palette)
            .clipShape(RoundedRectangle(cornerRadius: faceCornerRadius, style: .continuous))
            .overlay(concaveDishOverlay)
            .overlay(frontEdgeCrease, alignment: .bottom)
            .overlay(borderHighlight)
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
                .clipShape(RoundedRectangle(cornerRadius: faceCornerRadius, style: .continuous))

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
                .clipShape(RoundedRectangle(cornerRadius: faceCornerRadius, style: .continuous))

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
                .clipShape(RoundedRectangle(cornerRadius: faceCornerRadius, style: .continuous))
            }

        case .frosted:
            ZStack {
                LinearGradient(
                    colors: [Color.white.opacity(palette.isLightSurface ? 0.18 : 0.26), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // 玻璃边缘一圈极细的内反射，避免整块毛玻璃失去层次
                RoundedRectangle(cornerRadius: faceCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.8)
            }
            .clipShape(RoundedRectangle(cornerRadius: faceCornerRadius, style: .continuous))

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
            .clipShape(RoundedRectangle(cornerRadius: faceCornerRadius, style: .continuous))
        }
    }

    // MARK: - 顶面与前壁的交界折角（Crease）

    /// 顶面下沿向内压暗，与下方前壁的暗部相接，
    /// 形成「脸 → 壁」的真实转折；没有这道折角，顶面会重新读成一块平面
    private var frontEdgeCrease: some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color.black.opacity(palette.isLightSurface ? 0.10 : 0.20)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: max(4, round(height * 0.11)))
        .clipShape(RoundedRectangle(cornerRadius: faceCornerRadius, style: .continuous))
    }

    // MARK: - 边缘微倒角物理高光（Chamfer Border Highlight）

    private var borderHighlight: some View {
        RoundedRectangle(cornerRadius: faceCornerRadius, style: .continuous)
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
