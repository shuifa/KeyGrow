//
//  KeycapTheme.swift
//  KeyGlow
//
//  内置键帽主题系统：一套主题同时提供「白天 / 夜晚」两套完整配色，
//  并分别为普通键、修饰键、特殊功能键、Esc 键指定独立色板。
//

import AppKit
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

    /// 0xRRGGBB 十六进制初始化（主题定义处使用，便于逐个色号核对）
    public init(hex: UInt32) {
        self.init(
            Double((hex >> 16) & 0xFF) / 255.0,
            Double((hex >> 8) & 0xFF) / 255.0,
            Double(hex & 0xFF) / 255.0
        )
    }

    public static let white = KeyColorRGB(1.0, 1.0, 1.0)
    public static let black = KeyColorRGB(0.0, 0.0, 0.0)

    /// 深墨色字符（亮色键帽专用，比纯黑更柔和、更像丝印油墨）
    public static let ink = KeyColorRGB(0.11, 0.13, 0.16)

    public var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    public func color(opacity: Double) -> Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    /// WCAG 相对亮度（0 ~ 1）
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

    /// 色度（最大通道与最小通道之差），用于校验「普通键低饱和、功能键高饱和」的设计不变量
    public var chroma: Double {
        max(red, max(green, blue)) - min(red, min(green, blue))
    }
}

// MARK: - 单个键帽的完整色板

/// 单个键帽的完整色彩规格（顶面双色微弧渐变 + 侧壁厚度 + 代表强调色）
public struct KeycapPalette: Sendable, Equatable {
    /// 顶面渐变起始色（受光面）
    public let top: KeyColorRGB
    /// 顶面渐变终止色（微弧下沿）
    public let bottom: KeyColorRGB
    /// 侧壁下沉厚度（Extrusion Lip）
    public let extrusion: KeyColorRGB
    /// 代表色（选择器圆点、光晕、极光染色）
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

    /// 由单一基准色派生完整色板：统一「顶面提亮、下沿压暗、侧壁最深」的物理光照关系，
    /// 保证所有主题、所有键位处在同一明度带与同一套立体规律中。
    public static func tone(_ base: KeyColorRGB) -> KeycapPalette {
        let luminance = base.relativeLuminance
        // 浅色键帽本身亮度高，提亮/压暗幅度收窄，避免渐变糊成一片；深色键帽需要更大反差才看得出弧面
        let lift = luminance > 0.55 ? 0.055 : 0.13
        let drop = luminance > 0.55 ? 0.09 : 0.16
        let depth = luminance > 0.55 ? 0.22 : 0.38

        return KeycapPalette(
            top: base.mixed(with: .white, ratio: lift),
            bottom: base.mixed(with: .black, ratio: drop),
            extrusion: base.mixed(with: .black, ratio: depth),
            accent: base
        )
    }

    /// 是否为浅色键帽面（决定字符颜色、内投影方向与高光强度）
    public var isLightSurface: Bool {
        midTone.contrastRatio(with: .ink) >= midTone.contrastRatio(with: .white)
    }

    /// 前景文字与图标颜色：始终选对比度更高的一方（浅键用墨色、深键用白色）
    public var foregroundColor: Color {
        (isLightSurface ? KeyColorRGB.ink : KeyColorRGB.white).color
    }

    /// 字符与键帽中间调的实际对比度（WCAG，用于测试与可读性校验）
    public var legendContrastRatio: Double {
        midTone.contrastRatio(with: isLightSurface ? .ink : .white)
    }

    /// 字符微弱立体雕刻阴影（Deboss Highlight/Shadow）
    public var textShadowColor: Color {
        isLightSurface ? Color.white.opacity(0.7) : Color.black.opacity(0.45)
    }

    /// 环境光晕：由强调色派生，但强度刻意压低，避免饱和色在浅背景上晕成彩雾
    public var glowColor: Color {
        accent.color(opacity: isLightSurface ? 0.16 : 0.26)
    }

    /// 键帽顶面渐变
    public var topFaceColors: [Color] {
        [top.color, bottom.color]
    }
}

// MARK: - 边框描边策略

/// 键帽倒角高光策略（由主题指定，保证整套视觉统一，不再暴露给用户逐项调节）
public enum KeycapBorderStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case adaptive   // 随键帽自适应微光（浅键白描边、深键亮描边）
    case softDark   // 柔和深色描边：浅色键帽压边，避免融入浅色桌面
    case softLight  // 柔和浅色描边：深色键帽提亮轮廓
    case neon       // 霓虹描边：强调色发光

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .adaptive: return "自适应微光"
        case .softDark: return "柔和深描边"
        case .softLight: return "柔和亮描边"
        case .neon: return "霓虹发光"
        }
    }

    /// 边框顶部与底部的高光物理渐变（模拟顶光照射微倒角）
    public func strokeGradient(for palette: KeycapPalette) -> LinearGradient {
        switch self {
        case .adaptive:
            return LinearGradient(
                colors: [
                    Color.white.opacity(palette.isLightSurface ? 0.85 : 0.42),
                    palette.accent.color(opacity: 0.35),
                    palette.extrusion.color(opacity: 0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .softDark:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.55),
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.32)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .softLight:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.75),
                    Color.white.opacity(0.22),
                    Color.black.opacity(0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .neon:
            return LinearGradient(
                colors: [
                    palette.accent.color(opacity: 0.95),
                    palette.accent.color(opacity: 0.45),
                    palette.extrusion.color(opacity: 0.65)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - 外观模式

/// 主题外观模式：跟随系统 / 固定浅色 / 固定深色
public enum ThemeAppearanceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    public var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    /// 关键：`system` 返回 nil，交由 AppKit 继承系统外观；其余强制覆盖窗口 appearance，
    /// 使 SwiftUI 的 `@Environment(\.colorScheme)` 与实际渲染外观保持一致。
    public var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

// MARK: - 按键颜色角色

/// 按键在配色体系中的角色（决定它读取主题中的哪一档色板）
public enum KeyColorRole: String, Sendable, Equatable, CaseIterable {
    case escape     // Esc
    case special    // Return / Tab / Space / 方向键 / F1~F12 等功能键
    case modifier   // ⌘ ⌥ ⌃ ⇧ / CapsLock / Fn
    case regular    // 普通字母、数字、符号

    public var title: String {
        switch self {
        case .escape: return "Esc 键"
        case .special: return "功能键"
        case .modifier: return "修饰键"
        case .regular: return "普通键"
        }
    }
}

// MARK: - 一套主题在某一外观下的四档配色

/// 单一外观（白天或夜晚）下，四种按键角色的完整色板
public struct ThemeColorSet: Sendable, Equatable {
    public let regular: KeycapPalette
    public let modifier: KeycapPalette
    public let special: KeycapPalette
    public let escape: KeycapPalette

    public init(regular: KeycapPalette, modifier: KeycapPalette, special: KeycapPalette, escape: KeycapPalette) {
        self.regular = regular
        self.modifier = modifier
        self.special = special
        self.escape = escape
    }

    /// 由四个基准色一次性构建（内部统一走 `KeycapPalette.tone`，保证物理光照关系一致）
    public init(regular: KeyColorRGB, modifier: KeyColorRGB, special: KeyColorRGB, escape: KeyColorRGB) {
        self.init(
            regular: .tone(regular),
            modifier: .tone(modifier),
            special: .tone(special),
            escape: .tone(escape)
        )
    }

    public func palette(for role: KeyColorRole) -> KeycapPalette {
        switch role {
        case .regular: return regular
        case .modifier: return modifier
        case .special: return special
        case .escape: return escape
        }
    }

    /// 该外观下的四档色板（供测试与遍历使用）
    public var allPalettes: [KeycapPalette] {
        [regular, modifier, special, escape]
    }
}

// MARK: - 主题

/// 内置主题：同时携带白天 / 夜晚两套配色，并推荐一种材质与描边策略
public struct KeycapTheme: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let subtitle: String
    /// 白天（浅色系统外观）配色
    public let light: ThemeColorSet
    /// 夜晚（深色系统外观）配色
    public let dark: ThemeColorSet
    /// 推荐键帽材质（选择主题时作为默认材质，用户仍可单独覆盖）
    public let recommendedStyle: KeycapStyle
    /// 描边策略
    public let border: KeycapBorderStyle

    /// 按 SwiftUI 环境外观解析实际配色
    public func colors(for scheme: ColorScheme) -> ThemeColorSet {
        scheme == .dark ? dark : light
    }

    /// 是否为深色主题（夜晚档整体偏暗，用于设置面板上的标签）
    public var isDarkFirst: Bool {
        dark.regular.midTone.relativeLuminance < 0.2 && light.regular.midTone.relativeLuminance > 0.6
    }
}

// MARK: - 内置主题清单

extension KeycapTheme {
    /// 石墨：中性灰 + 深蓝修饰键 + 珊瑚红 Esc，最克制的一套，作为出厂默认
    public static let graphite = KeycapTheme(
        id: "graphite",
        name: "石墨",
        subtitle: "中性灰键帽 · 深蓝修饰 · 珊瑚 Esc",
        light: ThemeColorSet(
            regular: KeyColorRGB(hex: 0xE9E9EC),
            modifier: KeyColorRGB(hex: 0x4C566A),
            special: KeyColorRGB(hex: 0xC3C8D0),
            escape: KeyColorRGB(hex: 0xD9584C)
        ),
        dark: ThemeColorSet(
            regular: KeyColorRGB(hex: 0x2B2F36),
            modifier: KeyColorRGB(hex: 0x5E6E8A),
            special: KeyColorRGB(hex: 0x373B43),
            escape: KeyColorRGB(hex: 0xD65C50)
        ),
        recommendedStyle: .matte,
        border: .adaptive
    )

    /// 纸感：暖米白 + 雾蓝 + 砖红，适合浅色文档与演示
    public static let paper = KeycapTheme(
        id: "paper",
        name: "纸感",
        subtitle: "复古米白 · 雾蓝修饰 · 砖红 Esc",
        light: ThemeColorSet(
            regular: KeyColorRGB(hex: 0xF3EDE1),
            modifier: KeyColorRGB(hex: 0x7FA3D4),
            special: KeyColorRGB(hex: 0xDCD3C3),
            escape: KeyColorRGB(hex: 0xC25C54)
        ),
        dark: ThemeColorSet(
            regular: KeyColorRGB(hex: 0x35322C),
            modifier: KeyColorRGB(hex: 0x6E8FBE),
            special: KeyColorRGB(hex: 0x474440),
            escape: KeyColorRGB(hex: 0xC4634F)
        ),
        recommendedStyle: .matte,
        border: .softDark
    )

    /// 深海：冷白 + 海蓝 + 落日橙，冷色系里最"科技感"的一套
    public static let ocean = KeycapTheme(
        id: "ocean",
        name: "深海",
        subtitle: "冷雾白 · 海蓝修饰 · 落日橙 Esc",
        light: ThemeColorSet(
            regular: KeyColorRGB(hex: 0xE7EEF3),
            modifier: KeyColorRGB(hex: 0x2E7BB5),
            special: KeyColorRGB(hex: 0xB8CBD8),
            escape: KeyColorRGB(hex: 0xE08A3C)
        ),
        dark: ThemeColorSet(
            regular: KeyColorRGB(hex: 0x1F2A33),
            modifier: KeyColorRGB(hex: 0x3F93CF),
            special: KeyColorRGB(hex: 0x2E3F4B),
            escape: KeyColorRGB(hex: 0xE59B4F)
        ),
        recommendedStyle: .frosted,
        border: .adaptive
    )

    /// 日落：暖陶土 + 梅红，偏纪实/生活方式的内容更搭
    public static let sunset = KeycapTheme(
        id: "sunset",
        name: "日落",
        subtitle: "暖砂白 · 陶土橙修饰 · 梅红 Esc",
        light: ThemeColorSet(
            regular: KeyColorRGB(hex: 0xF6EDE5),
            modifier: KeyColorRGB(hex: 0xD2704A),
            special: KeyColorRGB(hex: 0xE5D0BF),
            escape: KeyColorRGB(hex: 0xA9485F)
        ),
        dark: ThemeColorSet(
            regular: KeyColorRGB(hex: 0x332722),
            modifier: KeyColorRGB(hex: 0xCE7A57),
            special: KeyColorRGB(hex: 0x453730),
            escape: KeyColorRGB(hex: 0xBE5C70)
        ),
        recommendedStyle: .matte,
        border: .adaptive
    )

    /// 霓虹：电紫 + 品红，配极光材质做赛博风演示
    public static let neon = KeycapTheme(
        id: "neon",
        name: "霓虹",
        subtitle: "冷灰白 · 电紫修饰 · 品红 Esc",
        light: ThemeColorSet(
            regular: KeyColorRGB(hex: 0xEFF0F5),
            modifier: KeyColorRGB(hex: 0x6A5AE0),
            special: KeyColorRGB(hex: 0xC8CBD9),
            escape: KeyColorRGB(hex: 0xD9468C)
        ),
        dark: ThemeColorSet(
            regular: KeyColorRGB(hex: 0x1B1D24),
            modifier: KeyColorRGB(hex: 0x7C6BFF),
            special: KeyColorRGB(hex: 0x2A2D39),
            escape: KeyColorRGB(hex: 0xF0579C)
        ),
        recommendedStyle: .matte,
        border: .neon
    )

    /// 终端：灰绿 + 荧光绿 + 琥珀，终端/命令行教学场景
    public static let terminal = KeycapTheme(
        id: "terminal",
        name: "终端",
        subtitle: "灰绿白 · 荧光绿修饰 · 琥珀 Esc",
        light: ThemeColorSet(
            regular: KeyColorRGB(hex: 0xE8EDE5),
            modifier: KeyColorRGB(hex: 0x2F7D4F),
            special: KeyColorRGB(hex: 0xC9D2C5),
            escape: KeyColorRGB(hex: 0xB0741E)
        ),
        dark: ThemeColorSet(
            regular: KeyColorRGB(hex: 0x1E2420),
            modifier: KeyColorRGB(hex: 0x45C46D),
            special: KeyColorRGB(hex: 0x2B332D),
            escape: KeyColorRGB(hex: 0xD9A13B)
        ),
        recommendedStyle: .matte,
        border: .softLight
    )

    /// 全部内置主题（顺序即设置面板展示顺序）
    public static let all: [KeycapTheme] = [graphite, paper, ocean, sunset, neon, terminal]

    /// 出厂默认主题
    public static let defaultTheme: KeycapTheme = graphite

    /// 按 id 查找，找不到时回退默认主题（防止旧配置残留导致空白）
    public static func theme(id: String) -> KeycapTheme {
        all.first(where: { $0.id == id }) ?? defaultTheme
    }
}

// MARK: - 按键与主题的关联

extension KeyStroke {
    /// 当前按键对应的配色角色：连按角标与键帽本身必须共用同一角色，颜色才不会错位
    public var colorRole: KeyColorRole {
        if rawIdentifier == "esc" || rawIdentifier == "escape" { return .escape }
        if isModifierOnly { return .modifier }
        if isSpecialFunctionKey { return .special }
        return .regular
    }
}
