//
//  KeycapGroupView.swift
//  KeyGlow
//
//  一组按键（一次按下或一个组合）的完整渲染，两种形态：
//
//   - Classic：每个按键一颗独立键帽，整组共享一块圆角底板（原版主形态）。
//     底板不是背景色块，而是这套视觉成立的关键：键帽的投影落在底板上，
//     底板再投影到桌面，形成「键帽 → 底板 → 桌面」三级空间关系。
//   - Pill：整组键帽被收进一根胶囊长条，只保留符号与文字，轻量、适合大量连续按键。
//

import AppKit
import SwiftUI

/// 一组按键（含修饰键前缀）的展示单元
public struct KeycapGroupView: View {
    public let stroke: KeyStroke
    public let slots: KeycapColorSlots
    public let metrics: KeycapMetrics
    public let shape: KeycapShape
    public let repeatCount: Int
    /// 解析系统强调色需要当前外观
    public let appearance: NSAppearance?
    public let punchTrigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        stroke: KeyStroke,
        slots: KeycapColorSlots,
        metrics: KeycapMetrics,
        shape: KeycapShape,
        repeatCount: Int = 1,
        appearance: NSAppearance? = nil,
        punchTrigger: Int = 0
    ) {
        self.stroke = stroke
        self.slots = slots
        self.metrics = metrics
        self.shape = shape
        self.repeatCount = repeatCount
        self.appearance = appearance
        self.punchTrigger = punchTrigger
    }

    // MARK: - 配色

    private var mainPalette: KeycapPalette {
        slots.palette(for: stroke.colorRole, appearance: appearance)
    }

    private var modifierPalette: KeycapPalette {
        slots.palette(for: .modifier, appearance: appearance)
    }

    private var platePalette: KeycapPalette {
        slots.borderMaterial.palette(appearance: appearance)
    }

    // MARK: - 主体

    public var body: some View {
        content
            .overlay(alignment: .topTrailing) { repeatBadge }
            // 连按冲击：按下瞬间极轻微的放大弹入
            .phaseAnimator([false, true, false], trigger: punchTrigger) { view, isPunched in
                view.scaleEffect(isPunched && !reduceMotion ? 1.045 : 1.0)
            } animation: { isPunched in
                .spring(response: 0.20, dampingFraction: 0.62, blendDuration: 0)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch shape {
        case .classic: classicGroup
        case .pill: pillGroup
        }
    }

    // MARK: - 独立键帽 + 共享底板

    private var classicGroup: some View {
        HStack(spacing: metrics.keySpacing) {
            ForEach(Array(stroke.modifiers.enumerated()), id: \.offset) { _, modifier in
                KeycapItemView(
                    legend: modifier.legend,
                    palette: modifierPalette,
                    metrics: metrics
                )
            }

            KeycapItemView(
                legend: stroke.legend,
                palette: mainPalette,
                metrics: metrics
            )
        }
        .padding(metrics.platePadding)
        .background(plateSurface)
    }

    private var plateSurface: some View {
        RoundedRectangle(cornerRadius: metrics.plateCornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [platePalette.faceTop.color, platePalette.faceBottom.color],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            // 只保留顶边 1px 亮边：托板自身的倒角受光。
            // 不再给托板加整圈描边——在深色桌面上那圈 10% 白的细边会被读成「选中框」，
            // 反而把实体托板变成一根空心中空线。
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color.white.opacity(platePalette.usesDarkLegend ? 0.20 : 0.55), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: max(1.5, metrics.height * 0.045))
                .clipShape(RoundedRectangle(cornerRadius: metrics.plateCornerRadius, style: .continuous))
            }
            // 底板投影：比键帽投影更大、更虚，负责把整组压到桌面上
            .shadow(color: Color.black.opacity(0.30), radius: metrics.height * 0.16, x: 0, y: metrics.height * 0.06)
    }

    // MARK: - 胶囊

    private var pillGroup: some View {
        HStack(spacing: metrics.height * 0.14) {
            ForEach(Array(stroke.modifiers.enumerated()), id: \.offset) { _, modifier in
                pillElement(modifier.legend)
            }
            pillElement(stroke.legend)
        }
        .padding(.horizontal, metrics.pillPadding)
        .frame(height: metrics.pillHeight)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [platePalette.faceTop.color, platePalette.faceBottom.color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(platePalette.usesDarkLegend ? 0.12 : 0.45), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.28), radius: metrics.height * 0.14, x: 0, y: metrics.height * 0.05)
        )
    }

    /// 胶囊里的一个元素：有符号用符号，没有符号用文字
    @ViewBuilder
    private func pillElement(_ legend: KeyLegend) -> some View {
        if let symbol = legend.symbol {
            Image(systemName: symbol)
                .font(.system(size: metrics.pillHeight * 0.52, weight: .medium))
                .foregroundColor(pillLegendColor)
        } else if let text = legend.text {
            Text(text)
                .font(.system(size: legend.isSingleCharacter ? metrics.pillHeight * 0.54 : metrics.pillHeight * 0.40,
                              weight: .medium))
                .foregroundColor(pillLegendColor)
                .lineLimit(1)
        }
    }

    private var pillLegendColor: Color {
        (platePalette.usesDarkLegend ? KeyColorRGB.ink : KeyColorRGB.white).color
    }

    // MARK: - 连按角标

    @ViewBuilder
    private var repeatBadge: some View {
        if repeatCount > 1 {
            RepeatBadgeView(count: repeatCount, palette: mainPalette, metrics: metrics)
                .offset(
                    x: metrics.platePadding + (shape == .classic ? 2 : -metrics.pillPadding),
                    y: shape == .classic ? -metrics.platePadding * 0.35 : -metrics.height * 0.10
                )
                .transition(
                    reduceMotion
                        ? .opacity
                        : .scale(scale: 0.5, anchor: .center).combined(with: .opacity)
                )
        }
    }
}

// MARK: - 连按角标

/// 连按次数角标：与主键帽共用同一色板，读作「一颗很小的键帽」而不是贴纸
public struct RepeatBadgeView: View {
    public let count: Int
    public let palette: KeycapPalette
    public let metrics: KeycapMetrics

    public var body: some View {
        Text("×\(count)")
            .font(.system(size: max(9, metrics.height * 0.20), weight: .semibold))
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(count)))
            .foregroundColor(palette.legendColor)
            .padding(.horizontal, max(4, metrics.height * 0.10))
            .padding(.vertical, max(1.5, metrics.height * 0.035))
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: palette.faceColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(palette.borderHighlight, lineWidth: 0.8)
                    )
            )
            .shadow(color: Color.black.opacity(0.28), radius: max(1.5, metrics.height * 0.05), x: 0, y: 1)
            .animation(.spring(duration: 0.22, bounce: 0.25), value: count)
    }
}
