//
//  BorderColorOption.swift
//  KeyGlow
//

import SwiftUI

/// 键帽倒角边缘高光与边框颜色选项
public enum BorderColorOption: String, CaseIterable, Identifiable, Codable, Sendable {
    case matching = "matching"         // 随键帽自适应微光
    case space = "space"               // Space 深空炭黑倒角
    case subtleWhite = "subtleWhite"   // Subtle White 微光银白高光
    case vintageBrass = "vintageBrass" // Vintage Brass 复古黄铜高光
    case neonCyan = "neonCyan"         // Neon Cyan 霓虹青蓝
    case minimal = "minimal"           // Minimal 极简微弱描边

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .matching: return "Auto (Matching)"
        case .space: return "Space"
        case .subtleWhite: return "Subtle White"
        case .vintageBrass: return "Vintage Brass"
        case .neonCyan: return "Neon Cyan"
        case .minimal: return "Minimal"
        }
    }

    public var localizedName: String {
        switch self {
        case .matching: return "自适应匹配"
        case .space: return "深空微黑"
        case .subtleWhite: return "微光银白"
        case .vintageBrass: return "复古黄铜"
        case .neonCyan: return "霓虹青蓝"
        case .minimal: return "极简低调"
        }
    }

    /// 代表色（用于偏好设置选项圆点）
    public var previewColor: Color {
        switch self {
        case .matching:
            return Color.blue
        case .space:
            return Color(red: 0.18, green: 0.19, blue: 0.22)
        case .subtleWhite:
            return Color(white: 0.88)
        case .vintageBrass:
            return Color(red: 0.86, green: 0.72, blue: 0.42)
        case .neonCyan:
            return Color(red: 0.0, green: 0.95, blue: 1.0)
        case .minimal:
            return Color(white: 0.45)
        }
    }

    /// 边框顶部与底部的高光物理渐变（模拟顶光照射微倒角）
    public func strokeGradient(for baseKeyColor: KeyColorOption) -> LinearGradient {
        switch self {
        case .matching:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.55),
                    baseKeyColor.color.opacity(0.40),
                    baseKeyColor.extrusionBaseColor.opacity(0.60)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .space:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.25),
                    Color(red: 0.22, green: 0.23, blue: 0.26),
                    Color(red: 0.08, green: 0.09, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .subtleWhite:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.75),
                    Color.white.opacity(0.30),
                    Color.black.opacity(0.25)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .vintageBrass:
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.90, blue: 0.65, opacity: 0.85),
                    Color(red: 0.82, green: 0.68, blue: 0.38, opacity: 0.60),
                    Color(red: 0.45, green: 0.35, blue: 0.15, opacity: 0.70)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .neonCyan:
            return LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.98, blue: 1.0, opacity: 0.90),
                    Color(red: 0.0, green: 0.75, blue: 0.95, opacity: 0.50),
                    Color(red: 0.0, green: 0.35, blue: 0.65, opacity: 0.50)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .minimal:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.18),
                    Color.white.opacity(0.06),
                    Color.black.opacity(0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
