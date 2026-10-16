//
//  DisplayAnchor.swift
//  KeyGlow
//

import Foundation

/// 浮层在屏幕上的展示锚点
public enum DisplayAnchor: String, CaseIterable, Identifiable, Codable {
    case bottomCenter = "bottomCenter"
    case bottomLeft = "bottomLeft"
    case bottomRight = "bottomRight"
    case topCenter = "topCenter"
    case mouseFollow = "mouseFollow"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .bottomCenter:
            return "屏幕底部居中"
        case .bottomLeft:
            return "屏幕左下角"
        case .bottomRight:
            return "屏幕右下角"
        case .topCenter:
            return "屏幕顶部居中"
        case .mouseFollow:
            return "跟随鼠标光标"
        }
    }

    public var iconName: String {
        switch self {
        case .bottomCenter:
            return "arrow.down.to.line"
        case .bottomLeft:
            return "arrow.down.left.square"
        case .bottomRight:
            return "arrow.down.right.square"
        case .topCenter:
            return "arrow.up.to.line"
        case .mouseFollow:
            return "cursorarrow.rays"
        }
    }
}
