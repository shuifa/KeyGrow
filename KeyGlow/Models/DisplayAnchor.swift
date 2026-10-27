//
//  DisplayAnchor.swift
//  KeyGlow
//
//  屏幕吸附点。0.100 起对齐 Keystroke Pro：3×3 网格去掉正中心，共 **8 个吸附点**。
//  原版把中心位置留给显示器名称，因此中心不可选；我们也保持这一约束，
//  并下线了「跟随鼠标光标」——它在录屏里会让键帽随光标漂移，反而干扰构图。
//

import Foundation

/// 锚点所在列
public enum DisplayAnchorColumn: String, Sendable, CaseIterable {
    case leading
    case center
    case trailing
}

/// 锚点所在行
public enum DisplayAnchorRow: String, Sendable, CaseIterable {
    case top
    case middle
    case bottom
}

/// 浮层在屏幕上的吸附位置
public enum DisplayAnchor: String, CaseIterable, Identifiable, Codable, Sendable {
    case topLeading = "topLeading"
    case topCenter = "topCenter"
    case topTrailing = "topTrailing"
    case middleLeading = "middleLeading"
    case middleTrailing = "middleTrailing"
    case bottomLeading = "bottomLeading"
    case bottomCenter = "bottomCenter"
    case bottomTrailing = "bottomTrailing"

    public var id: String { rawValue }

    public var column: DisplayAnchorColumn {
        switch self {
        case .topLeading, .middleLeading, .bottomLeading: return .leading
        case .topCenter, .bottomCenter: return .center
        case .topTrailing, .middleTrailing, .bottomTrailing: return .trailing
        }
    }

    public var row: DisplayAnchorRow {
        switch self {
        case .topLeading, .topCenter, .topTrailing: return .top
        case .middleLeading, .middleTrailing: return .middle
        case .bottomLeading, .bottomCenter, .bottomTrailing: return .bottom
        }
    }

    public var title: String {
        switch (row, column) {
        case (.top, .leading): return "左上角"
        case (.top, .center): return "顶部居中"
        case (.top, .trailing): return "右上角"
        case (.middle, .leading): return "左侧居中"
        case (.middle, .trailing): return "右侧居中"
        case (.bottom, .leading): return "左下角"
        case (.bottom, .center): return "底部居中"
        case (.bottom, .trailing): return "右下角"
        // 正中心在 3×3 网格里被显示器名称占用，不可选；兜底给底部居中
        case (.middle, .center): return "底部居中"
        }
    }

    public var iconName: String {
        switch (row, column) {
        case (.top, .leading): return "arrow.up.left"
        case (.top, .center): return "arrow.up.to.line"
        case (.top, .trailing): return "arrow.up.right"
        case (.middle, .leading): return "arrow.left.to.line"
        case (.middle, .trailing): return "arrow.right.to.line"
        case (.bottom, .leading): return "arrow.down.left"
        case (.bottom, .center): return "arrow.down.to.line"
        case (.bottom, .trailing): return "arrow.down.right"
        case (.middle, .center): return "arrow.down.to.line"
        }
    }

    /// 3×3 网格的排布顺序（用于设置面板的九宫格，中心留空）
    public static let grid: [[DisplayAnchor?]] = [
        [.topLeading, .topCenter, .topTrailing],
        [.middleLeading, nil, .middleTrailing],
        [.bottomLeading, .bottomCenter, .bottomTrailing]
    ]

    /// 出厂默认锚点
    public static let `default`: DisplayAnchor = .bottomCenter
}
