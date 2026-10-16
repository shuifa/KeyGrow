//
//  SpecialKeyColor.swift
//  KeyGlow
//

import SwiftUI

/// 特殊功能按键与修饰键的个性化强调色（参考 Keystroke Pro 独立配色设计）
public enum SpecialKeyColor: String, CaseIterable, Identifiable, Codable {
    case blue = "blue"
    case purple = "purple"
    case orange = "orange"
    case green = "green"
    case pink = "pink"
    case monochrome = "monochrome"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .blue: return "科技冰蓝"
        case .purple: return "极光熏紫"
        case .orange: return "日落暖橙"
        case .green: return "霓虹翡翠"
        case .pink: return "摩登浆果"
        case .monochrome: return "素雅纯白"
        }
    }

    /// 主要强调色
    public var color: Color {
        switch self {
        case .blue:
            return Color(red: 0.22, green: 0.60, blue: 1.0)
        case .purple:
            return Color(red: 0.73, green: 0.40, blue: 1.0)
        case .orange:
            return Color(red: 1.0, green: 0.58, blue: 0.18)
        case .green:
            return Color(red: 0.25, green: 0.86, blue: 0.52)
        case .pink:
            return Color(red: 1.0, green: 0.32, blue: 0.55)
        case .monochrome:
            return Color(white: 0.95)
        }
    }

    /// 边框高光强调渐变
    public var borderGradient: LinearGradient {
        if self == .monochrome {
            return LinearGradient(
                colors: [Color.white.opacity(0.35), Color.white.opacity(0.12), Color.black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    self.color.opacity(0.85),
                    self.color.opacity(0.4),
                    self.color.opacity(0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// 柔和氛围光晕色彩
    public var glowColor: Color {
        if self == .monochrome {
            return Color.black.opacity(0.35)
        } else {
            return self.color.opacity(0.4)
        }
    }
}
