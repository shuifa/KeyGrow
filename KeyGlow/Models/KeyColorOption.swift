//
//  KeyColorOption.swift
//  KeyGlow
//

import SwiftUI

/// 键帽配色选项（参考 Keystroke Pro 经典配色体系）
public enum KeyColorOption: String, CaseIterable, Identifiable, Codable, Sendable {
    case beige1984 = "beige1984"       // 1984s Beige 复古米白
    case azureBlue = "azureBlue"       // Azure Blue 科技蔚蓝
    case mambaGreen = "mambaGreen"     // Mamba Green 曼巴翠绿
    case space = "space"               // Space 深空黑曜
    case sunsetOrange = "sunsetOrange" // Sunset Orange 日落暖橙
    case cyberViolet = "cyberViolet"   // Cyber Violet 极光熏紫
    case berryPink = "berryPink"       // Berry Pink 摩登浆果
    case crimsonRed = "crimsonRed"     // Crimson Red 醒目热键红
    case pureWhite = "pureWhite"       // Pure White 素雅纯白
    case matteCharcoal = "matteCharcoal" // Matte Charcoal 哑光炭黑

    public var id: String { rawValue }

    /// 显示标题（符合 Keystroke Pro 风格）
    public var title: String {
        switch self {
        case .beige1984: return "1984s Beige"
        case .azureBlue: return "Azure Blue"
        case .mambaGreen: return "Mamba Green"
        case .space: return "Space"
        case .sunsetOrange: return "Sunset Orange"
        case .cyberViolet: return "Cyber Violet"
        case .berryPink: return "Berry Pink"
        case .crimsonRed: return "Crimson Red"
        case .pureWhite: return "Pure White"
        case .matteCharcoal: return "Matte Charcoal"
        }
    }

    /// 中文本地化辅助名称
    public var localizedName: String {
        switch self {
        case .beige1984: return "复古米白"
        case .azureBlue: return "科技蔚蓝"
        case .mambaGreen: return "曼巴翠绿"
        case .space: return "深空黑曜"
        case .sunsetOrange: return "日落暖橙"
        case .cyberViolet: return "极光熏紫"
        case .berryPink: return "摩登浆果"
        case .crimsonRed: return "醒目热红"
        case .pureWhite: return "素雅纯白"
        case .matteCharcoal: return "哑光炭黑"
        }
    }

    /// 代表主色（用于设置圆点与强调指示）
    public var color: Color {
        switch self {
        case .beige1984:
            return Color(red: 0.91, green: 0.88, blue: 0.80)
        case .azureBlue:
            return Color(red: 0.16, green: 0.53, blue: 1.0)
        case .mambaGreen:
            return Color(red: 0.0, green: 0.88, blue: 0.46)
        case .space:
            return Color(red: 0.18, green: 0.19, blue: 0.22)
        case .sunsetOrange:
            return Color(red: 1.0, green: 0.58, blue: 0.08)
        case .cyberViolet:
            return Color(red: 0.69, green: 0.32, blue: 0.95)
        case .berryPink:
            return Color(red: 1.0, green: 0.22, blue: 0.48)
        case .crimsonRed:
            return Color(red: 0.96, green: 0.22, blue: 0.22)
        case .pureWhite:
            return Color(white: 0.96)
        case .matteCharcoal:
            return Color(red: 0.28, green: 0.29, blue: 0.33)
        }
    }

    /// 拟物键帽顶面背景渐变（根据 KeycapStyle 与配色呈现实体质感）
    public func topFaceColors(for style: KeycapStyle) -> [Color] {
        switch self {
        case .beige1984:
            // 经典 1984 Macintosh 米黄键帽：上浅下微暖暗，呈现微弧面
            return [
                Color(red: 0.95, green: 0.93, blue: 0.86),
                Color(red: 0.86, green: 0.83, blue: 0.74)
            ]
        case .azureBlue:
            return [
                Color(red: 0.24, green: 0.58, blue: 1.0),
                Color(red: 0.08, green: 0.42, blue: 0.92)
            ]
        case .mambaGreen:
            return [
                Color(red: 0.12, green: 0.88, blue: 0.52),
                Color(red: 0.02, green: 0.72, blue: 0.38)
            ]
        case .space:
            return [
                Color(red: 0.22, green: 0.23, blue: 0.27),
                Color(red: 0.12, green: 0.13, blue: 0.15)
            ]
        case .sunsetOrange:
            return [
                Color(red: 1.0, green: 0.62, blue: 0.16),
                Color(red: 0.92, green: 0.44, blue: 0.02)
            ]
        case .cyberViolet:
            return [
                Color(red: 0.72, green: 0.38, blue: 0.98),
                Color(red: 0.55, green: 0.20, blue: 0.86)
            ]
        case .berryPink:
            return [
                Color(red: 1.0, green: 0.30, blue: 0.56),
                Color(red: 0.88, green: 0.12, blue: 0.38)
            ]
        case .crimsonRed:
            return [
                Color(red: 0.98, green: 0.30, blue: 0.30),
                Color(red: 0.82, green: 0.12, blue: 0.12)
            ]
        case .pureWhite:
            return [
                Color(white: 0.98),
                Color(white: 0.88)
            ]
        case .matteCharcoal:
            return [
                Color(red: 0.32, green: 0.33, blue: 0.38),
                Color(red: 0.20, green: 0.21, blue: 0.25)
            ]
        }
    }

    /// 拟物键帽侧边/下沉厚度（Extrusion Lip）暗部颜色
    public var extrusionBaseColor: Color {
        switch self {
        case .beige1984:
            return Color(red: 0.72, green: 0.68, blue: 0.59)
        case .azureBlue:
            return Color(red: 0.04, green: 0.28, blue: 0.68)
        case .mambaGreen:
            return Color(red: 0.01, green: 0.52, blue: 0.26)
        case .space:
            return Color(red: 0.06, green: 0.07, blue: 0.08)
        case .sunsetOrange:
            return Color(red: 0.68, green: 0.30, blue: 0.01)
        case .cyberViolet:
            return Color(red: 0.38, green: 0.12, blue: 0.62)
        case .berryPink:
            return Color(red: 0.62, green: 0.06, blue: 0.24)
        case .crimsonRed:
            return Color(red: 0.58, green: 0.06, blue: 0.06)
        case .pureWhite:
            return Color(white: 0.76)
        case .matteCharcoal:
            return Color(red: 0.12, green: 0.13, blue: 0.16)
        }
    }

    /// 前景文字与图标颜色（自适应保证极高对比度与拟物丝印质感）
    public var foregroundColor: Color {
        switch self {
        case .beige1984:
            // 米黄色键帽搭配经典复古黑灰色字符
            return Color(red: 0.20, green: 0.21, blue: 0.24)
        case .pureWhite:
            return Color(red: 0.15, green: 0.16, blue: 0.18)
        case .mambaGreen:
            // 荧光绿搭配高对比纯黑更具电竞机械感
            return Color(red: 0.05, green: 0.16, blue: 0.08)
        case .azureBlue, .space, .sunsetOrange, .cyberViolet, .berryPink, .crimsonRed, .matteCharcoal:
            return Color.white
        }
    }

    /// 字符微弱立体雕刻阴影（Deboss Highlight/Shadow）
    public var textShadowColor: Color {
        switch self {
        case .beige1984, .pureWhite, .mambaGreen:
            // 浅色键帽：字符底部 1px 浅白反光，形成下沉凹刻感
            return Color.white.opacity(0.65)
        default:
            // 深色键帽：字符顶部 1px 深黑阴影
            return Color.black.opacity(0.55)
        }
    }

    /// 氛围光晕颜色
    public var glowColor: Color {
        switch self {
        case .space, .matteCharcoal:
            return Color.black.opacity(0.4)
        case .beige1984:
            return Color(red: 0.82, green: 0.78, blue: 0.68).opacity(0.4)
        case .pureWhite:
            return Color.white.opacity(0.3)
        default:
            return self.color.opacity(0.5)
        }
    }
}
