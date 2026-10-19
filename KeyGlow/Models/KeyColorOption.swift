//
//  KeyColorOption.swift
//  KeyGlow
//

import SwiftUI

// MARK: - sRGB 色彩基元

/// sRGB 色彩分量封装：作为所有键帽配色的唯一数据源，
/// 同时提供 WCAG 相对亮度与对比度计算，保证「亮色键帽配深色字符 / 深色键帽配浅色字符」始终可读。
public struct KeyColorRGB: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// 白色（字符反光）
    public static let white = KeyColorRGB(1.0, 1.0, 1.0)

    /// 深墨色字符（亮色键帽专用，比纯黑更柔和、更像丝印油墨）
    public static let ink = KeyColorRGB(0.11, 0.13, 0.16)

    public var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    public func color(opacity: Double) -> Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    /// WCAG 相对亮度（0 ~ 1），用于判断键帽明暗与自动挑选字符颜色
    public var relativeLuminance: Double {
        func linearized(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearized(red) + 0.7152 * linearized(green) + 0.0722 * linearized(blue)
    }

    /// WCAG 对比度（1 ~ 21）
    public func contrastRatio(with other: KeyColorRGB) -> Double {
        let lhs = relativeLuminance
        let rhs = other.relativeLuminance
        return (max(lhs, rhs) + 0.05) / (min(lhs, rhs) + 0.05)
    }

    /// 两色线性混合（ratio 为 other 的占比）
    public func mixed(with other: KeyColorRGB, ratio: Double) -> KeyColorRGB {
        let t = min(max(ratio, 0), 1)
        return KeyColorRGB(
            red + (other.red - red) * t,
            green + (other.green - green) * t,
            blue + (other.blue - blue) * t
        )
    }
}

/// 单个键帽的完整色彩规格（顶面双色微弧渐变 + 侧壁厚度 + 代表强调色）
public struct KeyColorPalette: Sendable {
    /// 顶面渐变起始色（受光面）
    public let top: KeyColorRGB
    /// 顶面渐变终止色（微弧下沿）
    public let bottom: KeyColorRGB
    /// 侧壁下沉厚度（Extrusion Lip）
    public let extrusion: KeyColorRGB
    /// 代表色（设置面板圆点、光晕、极光染色）
    public let accent: KeyColorRGB

    public init(top: KeyColorRGB, bottom: KeyColorRGB, extrusion: KeyColorRGB, accent: KeyColorRGB) {
        self.top = top
        self.bottom = bottom
        self.extrusion = extrusion
        self.accent = accent
    }

    /// 字符所在位置的中间调，用于判定字符颜色对比度
    public var midTone: KeyColorRGB {
        top.mixed(with: bottom, ratio: 0.5)
    }
}

// MARK: - 键帽配色选项

/// 键帽配色选项（重新设计的明亮色系：统一明度带 + 高饱和主色 + 柔和受光面）
public enum KeyColorOption: String, CaseIterable, Identifiable, Codable, Sendable {
    // 中性色系
    case beige1984 = "beige1984"         // 1984s Beige 复古米白
    case pureWhite = "pureWhite"         // Pure White 素雅纯白
    case space = "space"                 // Space 深空黑曜
    case matteCharcoal = "matteCharcoal" // Matte Charcoal 哑光炭黑
    // 冷色系
    case azureBlue = "azureBlue"         // Azure Blue 科技蔚蓝
    case aquaTeal = "aquaTeal"           // Aqua Teal 冰川薄荷
    case mambaGreen = "mambaGreen"       // Mamba Green 曼巴翠绿
    case cyberViolet = "cyberViolet"     // Cyber Violet 极光薰紫
    // 暖色系
    case goldenAmber = "goldenAmber"     // Golden Amber 暖金琥珀
    case sunsetOrange = "sunsetOrange"   // Sunset Orange 日落暖橙
    case crimsonRed = "crimsonRed"       // Crimson Red 醒目热红
    case berryPink = "berryPink"         // Berry Pink 摩登浆果

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
        case .aquaTeal: return "Aqua Teal"
        case .goldenAmber: return "Golden Amber"
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
        case .cyberViolet: return "极光薰紫"
        case .berryPink: return "摩登浆果"
        case .crimsonRed: return "醒目热红"
        case .pureWhite: return "素雅纯白"
        case .matteCharcoal: return "哑光炭黑"
        case .aquaTeal: return "冰川薄荷"
        case .goldenAmber: return "暖金琥珀"
        }
    }

    // MARK: - 色彩数据源（唯一可信来源）

    /// 每种配色的完整色彩定义，所有视图均由此派生，避免多处硬编码导致色值漂移
    public var palette: KeyColorPalette {
        switch self {
        case .beige1984:
            return KeyColorPalette(
                top: KeyColorRGB(0.984, 0.957, 0.894),
                bottom: KeyColorRGB(0.941, 0.898, 0.808),
                extrusion: KeyColorRGB(0.788, 0.733, 0.620),
                accent: KeyColorRGB(0.949, 0.910, 0.827)
            )
        case .pureWhite:
            return KeyColorPalette(
                top: KeyColorRGB(0.992, 0.996, 1.000),
                bottom: KeyColorRGB(0.914, 0.937, 0.965),
                extrusion: KeyColorRGB(0.769, 0.812, 0.859),
                accent: KeyColorRGB(0.960, 0.980, 1.000)
            )
        case .space:
            return KeyColorPalette(
                top: KeyColorRGB(0.216, 0.235, 0.290),
                bottom: KeyColorRGB(0.137, 0.153, 0.192),
                extrusion: KeyColorRGB(0.086, 0.098, 0.125),
                accent: KeyColorRGB(0.180, 0.190, 0.220)
            )
        case .matteCharcoal:
            return KeyColorPalette(
                top: KeyColorRGB(0.271, 0.294, 0.349),
                bottom: KeyColorRGB(0.180, 0.200, 0.239),
                extrusion: KeyColorRGB(0.122, 0.137, 0.165),
                accent: KeyColorRGB(0.280, 0.290, 0.330)
            )
        case .azureBlue:
            return KeyColorPalette(
                top: KeyColorRGB(0.310, 0.630, 1.000),
                bottom: KeyColorRGB(0.130, 0.460, 0.940),
                extrusion: KeyColorRGB(0.050, 0.300, 0.720),
                accent: KeyColorRGB(0.180, 0.520, 1.000)
            )
        case .aquaTeal:
            return KeyColorPalette(
                top: KeyColorRGB(0.310, 0.890, 0.816),
                bottom: KeyColorRGB(0.122, 0.780, 0.706),
                extrusion: KeyColorRGB(0.043, 0.627, 0.561),
                accent: KeyColorRGB(0.180, 0.851, 0.773)
            )
        case .mambaGreen:
            return KeyColorPalette(
                top: KeyColorRGB(0.302, 0.918, 0.620),
                bottom: KeyColorRGB(0.102, 0.800, 0.502),
                extrusion: KeyColorRGB(0.024, 0.600, 0.361),
                accent: KeyColorRGB(0.122, 0.851, 0.541)
            )
        case .cyberViolet:
            return KeyColorPalette(
                top: KeyColorRGB(0.620, 0.420, 0.990),
                bottom: KeyColorRGB(0.470, 0.250, 0.910),
                extrusion: KeyColorRGB(0.330, 0.140, 0.700),
                accent: KeyColorRGB(0.580, 0.350, 0.980)
            )
        case .goldenAmber:
            return KeyColorPalette(
                top: KeyColorRGB(1.000, 0.820, 0.400),
                bottom: KeyColorRGB(0.961, 0.718, 0.192),
                extrusion: KeyColorRGB(0.788, 0.553, 0.039),
                accent: KeyColorRGB(1.000, 0.761, 0.302)
            )
        case .sunsetOrange:
            return KeyColorPalette(
                top: KeyColorRGB(1.000, 0.722, 0.322),
                bottom: KeyColorRGB(0.992, 0.580, 0.141),
                extrusion: KeyColorRGB(0.800, 0.400, 0.020),
                accent: KeyColorRGB(1.000, 0.624, 0.180)
            )
        case .crimsonRed:
            return KeyColorPalette(
                top: KeyColorRGB(0.970, 0.360, 0.380),
                bottom: KeyColorRGB(0.850, 0.160, 0.210),
                extrusion: KeyColorRGB(0.620, 0.070, 0.110),
                accent: KeyColorRGB(0.930, 0.250, 0.280)
            )
        case .berryPink:
            return KeyColorPalette(
                top: KeyColorRGB(0.990, 0.420, 0.620),
                bottom: KeyColorRGB(0.900, 0.190, 0.430),
                extrusion: KeyColorRGB(0.700, 0.070, 0.280),
                accent: KeyColorRGB(0.960, 0.280, 0.500)
            )
        }
    }

    /// 代表主色（用于设置圆点与强调指示）
    public var color: Color {
        palette.accent.color
    }

    /// 拟物键帽顶面背景渐变（根据 KeycapStyle 与配色呈现实体质感）
    public func topFaceColors(for style: KeycapStyle) -> [Color] {
        [palette.top.color, palette.bottom.color]
    }

    /// 拟物键帽侧边/下沉厚度（Extrusion Lip）暗部颜色
    public var extrusionBaseColor: Color {
        palette.extrusion.color
    }

    // MARK: - 字符与光影自适应

    /// 是否为浅色键帽面（浅色面使用深墨色字符与向内投影）
    /// 阈值 0.45 使暖白/薄荷/翠绿/琥珀/暖橙配深色字符，蔚蓝/热红/浆果/薰紫/黑曜配浅色字符。
    public var isLightSurface: Bool {
        palette.top.relativeLuminance >= 0.45
    }

    /// 前景文字与图标颜色（依据键帽中间调自动选择对比度更高的一方）
    public var foregroundColor: Color {
        (isLightSurface ? KeyColorRGB.ink : KeyColorRGB.white).color
    }

    /// 字符与键帽中间调的实际对比度（WCAG，用于测试与可读性校验）
    public var legendContrastRatio: Double {
        palette.midTone.contrastRatio(with: isLightSurface ? .ink : .white)
    }

    /// 字符微弱立体雕刻阴影（Deboss Highlight/Shadow）
    public var textShadowColor: Color {
        isLightSurface ? Color.white.opacity(0.7) : Color.black.opacity(0.45)
    }

    /// 氛围光晕颜色
    public var glowColor: Color {
        switch self {
        case .space, .matteCharcoal:
            return Color.black.opacity(0.38)
        case .beige1984, .pureWhite:
            return palette.accent.color(opacity: 0.35)
        default:
            return palette.accent.color(opacity: 0.45)
        }
    }
}

// MARK: - 按键颜色角色

/// 按键在配色体系中的角色（决定它读取 Key Color / Modifier Color / Escape Color）
public enum KeyColorRole: Sendable, Equatable {
    case escape     // Esc
    case special    // Return / Tab / Space / 方向键等功能键
    case modifier   // ⌘ ⌥ ⌃ ⇧ / CapsLock / Fn
    case regular    // 普通字母、数字、符号
}

extension String {
    /// Esc 键的两种历史标识（原始键码与自定义标识）
    fileprivate var isEscapeIdentifier: Bool {
        self == "esc" || self == "escape"
    }
}

extension KeyStroke {
    /// 当前按键对应的配色角色：连按角标与键帽本身必须共用同一角色，颜色才不会错位
    public var colorRole: KeyColorRole {
        if rawIdentifier.isEscapeIdentifier { return .escape }
        if isModifierOnly { return .modifier }
        if isSpecialFunctionKey { return .special }
        return .regular
    }
}

extension AppSettings {
    /// 按角色读取用户设定的键帽颜色（Key Color / Modifier Color / Escape Color）
    public func keyColor(for role: KeyColorRole) -> KeyColorOption {
        switch role {
        case .escape, .special: return escapeColor
        case .modifier: return modifierColor
        case .regular: return keyColor
        }
    }
}
