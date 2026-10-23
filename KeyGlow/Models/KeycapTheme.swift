//
//  KeycapTheme.swift
//  KeyGlow
//
//  内置键帽主题系统：一套主题同时提供「白天 / 夜晚」两套完整配色，
//  并分别为普通键、修饰键、特殊功能键、Esc 键指定独立色板。
//
//  配色设计系统（0.13 重构）：
//  旧版六套主题共用同一公式——「浅灰字母键 + 一个饱和修饰键 + 一个暖色 Esc」，
//  彼此只差一个色相，因此观感高度同质化。新版把四档颜色升级为**四个光位**：
//    1. 字母键 regular  —— 底色：低饱和，承载整块键盘的"纸面"；
//    2. 结构键 special  —— 暗部：Return / Tab / 方向键组成结构层，与字母键拉开明度台阶，
//       让「组合键」在录屏里第一眼就能被读成"修饰 + 结构 + 主体"三段；
//    3. 修饰键 modifier —— 强调音：唯一的高饱和色相，负责主题辨识度；
//    4. Esc escape      —— 英雄键：与修饰键不同色系，整块键盘唯一的高对比焦点。
//  每套主题的明度骨架刻意不同（如「拿铁」四档单调下沉，「曜石」则是字母键极亮、
//  结构键压到近黑的反差骨架），因此六套主题不再是同一块键盘换色，而是六种键盘。
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

    /// 按视觉层级排列的四档色板：底色（字母）→ 结构（功能键）→ 强调（修饰键）→ 英雄键（Esc）。
    /// 设置面板的色卡带按这个顺序排布，读者一眼就能顺着读完整套配色的明度骨架。
    public var hierarchy: [KeycapPalette] {
        [regular, special, modifier, escape]
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
    /// 曜石 · 高反差黑金：字母键温白，结构键压到近黑，修饰键石板蓝，Esc 熔金。
    /// 四档明度是「极亮 → 极暗 → 中深 → 亮金」的反差骨架，录屏里层次最锐利，作为出厂默认。
    public static let obsidian = KeycapTheme(
        id: "obsidian",
        name: "曜石",
        subtitle: "暖白字母 · 曜石黑结构 · 熔金 Esc",
        light: ThemeColorSet(
            regular: KeyColorRGB(hex: 0xF0EDE7),
            modifier: KeyColorRGB(hex: 0x3A4C66),
            special: KeyColorRGB(hex: 0x24262B),
            escape: KeyColorRGB(hex: 0xC8952B)
        ),
        dark: ThemeColorSet(
            regular: KeyColorRGB(hex: 0x23262B),
            modifier: KeyColorRGB(hex: 0x4C6485),
            special: KeyColorRGB(hex: 0x383C43),
            escape: KeyColorRGB(hex: 0xDFAE45)
        ),
        recommendedStyle: .matte,
        border: .softLight
    )

    /// 拿铁 · 复古暖调：奶油白字母逐级下沉到灰米结构、焦糖修饰，Esc 用深樱桃红压住重心，
    /// 四档明度单调递减，是最"有纸感"、最不刺眼的一套，适合浅色文档与长时间演示。
    public static let latte = KeycapTheme(
        id: "latte",
        name: "拿铁",
        subtitle: "奶油白字母 · 焦糖修饰 · 樱桃红 Esc",
        light: ThemeColorSet(
            regular: KeyColorRGB(hex: 0xF6EFDD),
            modifier: KeyColorRGB(hex: 0x8F6A44),
            special: KeyColorRGB(hex: 0xCDC0A6),
            escape: KeyColorRGB(hex: 0x8E2A26)
        ),
        dark: ThemeColorSet(
            regular: KeyColorRGB(hex: 0x2A2620),
            modifier: KeyColorRGB(hex: 0x8C6C46),
            special: KeyColorRGB(hex: 0x453D32),
            escape: KeyColorRGB(hex: 0xC8543F)
        ),
        recommendedStyle: .matte,
        border: .softDark
    )

    /// 冰川 · 冷透材料：冰蓝白字母配深青结构，海水蓝修饰，Esc 用信号橙做冷色里的唯一暖点。
    /// 配合磨砂玻璃材质，是六套里最"轻"的一套。
    public static let glacier = KeycapTheme(
        id: "glacier",
        name: "冰川",
        subtitle: "冰蓝白字母 · 海水蓝修饰 · 信号橙 Esc",
        light: ThemeColorSet(
            regular: KeyColorRGB(hex: 0xE6EFF4),
            modifier: KeyColorRGB(hex: 0x2C7FA6),
            special: KeyColorRGB(hex: 0x1C3B46),
            escape: KeyColorRGB(hex: 0xD96A34)
        ),
        dark: ThemeColorSet(
            regular: KeyColorRGB(hex: 0x18232A),
            modifier: KeyColorRGB(hex: 0x3E9BC4),
            special: KeyColorRGB(hex: 0x2A3D46),
            escape: KeyColorRGB(hex: 0xE5854A)
        ),
        recommendedStyle: .frosted,
        border: .adaptive
    )

    /// 樱 · 柔色反差：藕粉白字母 + 雾紫结构，修饰键走梅子紫，Esc 反过来用深墨蓝，
    /// 在整块柔和粉调里落下一笔硬朗的冷色，温柔但不软弱。
    public static let sakura = KeycapTheme(
        id: "sakura",
        name: "樱",
        subtitle: "藕粉白字母 · 梅子紫修饰 · 墨蓝 Esc",
        light: ThemeColorSet(
            regular: KeyColorRGB(hex: 0xF4E6E6),
            modifier: KeyColorRGB(hex: 0x8A5878),
            special: KeyColorRGB(hex: 0xB9A2B4),
            escape: KeyColorRGB(hex: 0x2F3A55)
        ),
        dark: ThemeColorSet(
            regular: KeyColorRGB(hex: 0x2C2429),
            modifier: KeyColorRGB(hex: 0xB07C9C),
            special: KeyColorRGB(hex: 0x453A41),
            escape: KeyColorRGB(hex: 0x9BB2DE)
        ),
        recommendedStyle: .frosted,
        border: .adaptive
    )

    /// 磷光 · 终端感：灰绿白字母，松墨绿压暗结构层，修饰键用荧光绿，Esc 转琥珀，
    /// 是命令行教学与终端录屏的原生配色。
    public static let phosphor = KeycapTheme(
        id: "phosphor",
        name: "磷光",
        subtitle: "灰绿白字母 · 荧光绿修饰 · 琥珀 Esc",
        light: ThemeColorSet(
            regular: KeyColorRGB(hex: 0xE4EBE1),
            modifier: KeyColorRGB(hex: 0x2A8A5A),
            special: KeyColorRGB(hex: 0x233029),
            escape: KeyColorRGB(hex: 0xC2841F)
        ),
        dark: ThemeColorSet(
            regular: KeyColorRGB(hex: 0x171C19),
            modifier: KeyColorRGB(hex: 0x46C878),
            special: KeyColorRGB(hex: 0x2C3730),
            escape: KeyColorRGB(hex: 0xD9A63C)
        ),
        recommendedStyle: .matte,
        border: .softLight
    )

    /// 霓虹 · 赛博：冷紫白字母 + 夜紫结构，电紫修饰配荧光粉 Esc，
    /// 配合极光染色材质与霓虹描边，是唯一一套带发光骨架的配色。
    public static let neon = KeycapTheme(
        id: "neon",
        name: "霓虹",
        subtitle: "冷紫白字母 · 电紫修饰 · 荧光粉 Esc",
        light: ThemeColorSet(
            regular: KeyColorRGB(hex: 0xEAE9F4),
            modifier: KeyColorRGB(hex: 0x6B5AE0),
            special: KeyColorRGB(hex: 0x211F33),
            escape: KeyColorRGB(hex: 0xDE3F86)
        ),
        dark: ThemeColorSet(
            regular: KeyColorRGB(hex: 0x161521),
            modifier: KeyColorRGB(hex: 0x8B7BFF),
            special: KeyColorRGB(hex: 0x2B2940),
            escape: KeyColorRGB(hex: 0xFF5E9C)
        ),
        recommendedStyle: .aurora,
        border: .neon
    )

    /// 全部内置主题（顺序即设置面板展示顺序）
    public static let all: [KeycapTheme] = [obsidian, latte, glacier, sakura, phosphor, neon]

    /// 出厂默认主题
    public static let defaultTheme: KeycapTheme = obsidian

    /// 0.12 及以前的中性命名 id → 0.13 的设计命名 id。
    /// 保留这张表，老用户升级后仍停在同一套配色的设计槽位上，而不是被重置回默认主题。
    private static let legacyIDMap: [String: String] = [
        "graphite": "obsidian",
        "paper": "latte",
        "ocean": "glacier",
        "sunset": "sakura",
        "terminal": "phosphor"
    ]

    /// 把持久化/导入的主题 id 解析成当前目录下真实存在的 id（含旧 id 迁移）
    public static func resolvedID(_ stored: String) -> String {
        if all.contains(where: { $0.id == stored }) { return stored }
        if let mapped = legacyIDMap[stored], all.contains(where: { $0.id == mapped }) { return mapped }
        return defaultTheme.id
    }

    /// 按 id 查找，找不到时回退默认主题（防止旧配置残留导致空白）
    public static func theme(id: String) -> KeycapTheme {
        all.first(where: { $0.id == id })
            ?? all.first(where: { $0.id == legacyIDMap[id] })
            ?? defaultTheme
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
