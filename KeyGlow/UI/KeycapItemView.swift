//
//  KeycapItemView.swift
//  KeyGlow
//
//  单颗实体键帽的渲染。
//
//  0.100 按 Keystroke Pro 的实测结构重写，自上而下只有五层，没有内凹碟面、没有磨砂噪点、
//  也没有左右斜壁（原版顶面就是一块平的渐变塑料）：
//     1. 侧壁／前唇：高度 0.097H，颜色是键帽色压到 25%（彩色）或轻微压暗（中性）；
//     2. 折角：顶面下沿一道暗线，确保顶面不会重新读成平面；
//     3. 顶面：纵向渐变，方向由材质决定（中性上亮下暗、彩色上暗下亮）；
//     4. 唇线：顶面底边被打亮 8~10%，模拟前唇反光；
//     5. 字符层：符号右上 + 标签右下，或单字符居中。
//

import SwiftUI

/// 单颗实体键帽
public struct KeycapItemView: View {
    public let legend: KeyLegend
    public let palette: KeycapPalette
    public let metrics: KeycapMetrics

    public init(legend: KeyLegend, palette: KeycapPalette, metrics: KeycapMetrics) {
        self.legend = legend
        self.palette = palette
        self.metrics = metrics
    }

    private var width: CGFloat { metrics.keyWidth(units: legend.widthUnits) }

    public var body: some View {
        ZStack(alignment: .top) {
            sideWall
            topFace
            legendLayer
        }
        .frame(width: width, height: metrics.height + metrics.lipDepth)
        // 深度漫反射投影：大扩散、低透明度的环境遮蔽 + 一道极紧的接触影
        .shadow(color: Color.black.opacity(0.26), radius: metrics.height * 0.11, x: 0, y: metrics.height * 0.05)
        .shadow(color: Color.black.opacity(0.14), radius: 0.8, x: 0, y: 0.8)
    }

    // MARK: - 侧壁／前唇

    private var sideWall: some View {
        RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        palette.wall.lightened(0.06).color,
                        palette.wall.color,
                        palette.wall.darkened(0.18).color
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: metrics.height + metrics.lipDepth)
    }

    // MARK: - 顶面

    private var topFace: some View {
        RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: palette.faceColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: metrics.height)
            // 顶边受光带：从上沿向下渐隐（不能用硬边窄条，否则会在键面上画出一个内嵌方框）
            .overlay {
                RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(palette.usesDarkLegend ? 0.26 : 0.13), location: 0.0),
                                .init(color: Color.white.opacity(palette.usesDarkLegend ? 0.06 : 0.03), location: 0.45),
                                .init(color: Color.clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            // 底边唇线：前唇反打亮的那一道
            .overlay(alignment: .bottom) { bottomLip }
            // 折角：顶面落进前唇之前先压暗
            .overlay(alignment: .bottom) { creaseLine }
            // 微倒角描边：1px 顶亮底暗的物理边界
            .overlay {
                RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                    .strokeBorder(palette.borderHighlight, lineWidth: max(0.8, metrics.height * 0.017))
            }
            .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous))
    }

    private var bottomLip: some View {
        LinearGradient(
            colors: [Color.clear, palette.lip.color],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: max(1.5, metrics.height * 0.05))
        .opacity(0.9)
    }

    private var creaseLine: some View {
        LinearGradient(
            colors: [Color.clear, palette.crease.color.opacity(0.85)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: max(2, metrics.height * 0.075))
    }

    // MARK: - 字符层

    @ViewBuilder
    private var legendLayer: some View {
        if let symbol = legend.symbol, let text = legend.text {
            // 原版排版：符号右上、标签右下，两者右边缘对齐
            VStack(alignment: .trailing, spacing: 0) {
                Image(systemName: symbol)
                    .font(.system(size: metrics.symbolFontSize, weight: .regular))
                    .foregroundColor(palette.legendColor)
                    .shadow(color: palette.legendShadowColor, radius: 0.5, x: 0, y: 0.5)

                Spacer(minLength: 0)

                Text(text)
                    .font(.system(size: metrics.labelFontSize, weight: .medium))
                    .foregroundColor(palette.legendColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .shadow(color: palette.legendShadowColor, radius: 0.5, x: 0, y: 0.5)
            }
            .padding(metrics.legendInset)
            .frame(width: width, height: metrics.height, alignment: .trailing)

        } else if let symbol = legend.symbol {
            // 只有符号：居中放大（方向键）
            Image(systemName: symbol)
                .font(.system(size: metrics.centeredSymbolFontSize, weight: .medium))
                .foregroundColor(palette.legendColor)
                .shadow(color: palette.legendShadowColor, radius: 0.6, x: 0, y: 0.6)
                .frame(width: width, height: metrics.height)

        } else if let text = legend.text {
            // 只有文字：单字符大号居中，多字符（f1 / page up）居中缩小
            Text(text)
                .font(.system(
                    size: legend.isSingleCharacter ? metrics.singleCharacterFontSize : metrics.labelFontSize * 1.55,
                    weight: legend.isSingleCharacter ? .medium : .medium
                ))
                .foregroundColor(palette.legendColor)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .shadow(color: palette.legendShadowColor, radius: 0.6, x: 0, y: 0.6)
                .padding(.horizontal, metrics.legendInset * 0.5)
                .frame(width: width, height: metrics.height)
        }
    }
}
