//
//  KeycapShape.swift
//  KeyGlow
//
//  键帽形态与几何规范。
//
//  全部比例取自 Keystroke Pro v2 截图的像素测量（以键帽高度 H 为基准，
//  见 design/keystroke-pro-visual-analysis.md §4）。这里把它们收敛成一个不可变的
//  `KeycapMetrics`，视图只消费它、不再各自算比例——改一处，整条流水线同步。
//
//  与原版一致的三条「反直觉」结论：
//   1. 键帽不是正方形，而是 **0.97H × 1H 的竖矩形**；
//   2. 圆角只有高度的 **8.6%**（比 iOS 图标克制得多）；
//   3. 底板圆角是键帽圆角的 **2.4 倍**，内边距 0.15H。
//

import CoreGraphics

/// 键帽外形架构
public enum KeycapShape: String, CaseIterable, Identifiable, Codable, Sendable {
    /// 独立实体键帽：每个按键一块独立的圆角立方体，整组共享一块底板（原版主形态）
    case classic
    /// 药丸胶囊：整组快捷键包在同一根圆滑胶囊长条里，视觉更轻
    case pill

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .classic: return "独立键帽"
        case .pill: return "胶囊"
        }
    }

    public var subtitle: String {
        switch self {
        case .classic: return "每个按键一块独立键帽，整组共享底板"
        case .pill: return "整组快捷键包进一根胶囊长条，更轻量"
        }
    }

    public var iconName: String {
        switch self {
        case .classic: return "square.grid.2x2"
        case .pill: return "capsule"
        }
    }
}

/// 键帽几何规范：所有尺寸都由键帽高度派生，缩放到任意档位比例不变
public struct KeycapMetrics: Sendable, Equatable {
    /// 键帽高度（1u 键帽的顶面高度，不含前唇）
    public let height: CGFloat

    public init(height: CGFloat) {
        self.height = max(20, height)
    }

    // MARK: - 立体与间距

    /// 键帽圆角：0.086H
    public var cornerRadius: CGFloat { max(4, (height * 0.086).rounded()) }

    /// 前唇高度（键帽的物理厚度）：0.097H
    public var lipDepth: CGFloat { max(2, (height * 0.097).rounded()) }

    /// 组内键间距：0.17H
    public var keySpacing: CGFloat { max(3, (height * 0.17).rounded()) }

    /// 底板内边距（单边）：0.15H
    public var platePadding: CGFloat { max(4, (height * 0.15).rounded()) }

    /// 底板圆角：0.21H（约 2.4 × 键帽圆角）
    public var plateCornerRadius: CGFloat { max(6, (height * 0.21).rounded()) }

    /// 相邻两个组合（各自带底板）之间的间距
    ///
    /// 原版组合之间与组合内部完全等距，但那是因为它的底板间距在视觉上已足够；
    /// 我们保留一块底板，因此组间距取 0.34H，加上两侧各 0.15H 的底板留白，
    /// 键帽与键帽之间的实际空档约 0.64H，能明确读出「两次按键」而不是一串流水。
    public var groupSpacing: CGFloat { max(6, (height * 0.34).rounded()) }

    /// 1u 键帽宽度：0.97H
    public var unitWidth: CGFloat { height * 0.97 }

    /// 指定宽度倍数（u）的键帽宽度
    public func keyWidth(units: Double) -> CGFloat {
        (unitWidth * CGFloat(max(units, 0.5))).rounded()
    }

    // MARK: - 字体

    /// 单字符键帽（X / 7 / A）的字符高度
    public var singleCharacterFontSize: CGFloat { max(9, height * 0.34) }

    /// 命名键帽的标签字号（command / escape / f1）
    public var labelFontSize: CGFloat { max(6.5, height * 0.155) }

    /// 双元素排版右上角的符号字号
    public var symbolFontSize: CGFloat { max(8, height * 0.215) }

    /// 独占居中大符号（方向键）的字号
    public var centeredSymbolFontSize: CGFloat { max(10, height * 0.30) }

    /// 图例距键帽内缘的留白
    public var legendInset: CGFloat { max(4, height * 0.13) }

    // MARK: - 胶囊形态

    /// 胶囊高度：0.72H（比键帽矮，读起来更像「卡片」而不是「键帽」）
    public var pillHeight: CGFloat { max(18, height * 0.72) }

    public var pillCornerRadius: CGFloat { pillHeight / 2 }

    /// 胶囊水平内边距
    public var pillPadding: CGFloat { max(8, height * 0.30) }
}
