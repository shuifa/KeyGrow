//
//  KeycapTheme.swift
//  KeyGlow
//
//  内置键帽主题系统：一套主题同时提供「白天 / 夜晚」两套完整配色。
//
//  0.2 配色重构：
//  旧版四光位（regular / special / modifier / escape）只能表达「底色 + 结构 + 强调 + 英雄键」四层，
//  无法满足「不同类型的按键有不同颜色」的诉求。新版把配色角色扩展到 **七档色相**：
//    alpha 字母 / digit 数字 / function F 区 / arrow 方向键 / structural 结构键 / modifier 修饰键 / escape 英雄键
//
//  七档色相全部由 OKLCH 以「固定感知明度、只变色相」的方式派生，因此整块键盘明度一致，
//  色相是唯一区分维度。这样既做到了「每类按键不同色」，又不会因为明度打架而显得杂乱；
//  所有档位的字符色对比度均 ≥ 5.2:1（深色档）/ ≥ 8.5:1（浅色档），远超 WCAG AA。
//

import AppKit
import SwiftUI

// MARK: - sRGB 色彩基元

/// sRGB 色彩分量封装：作为所有键帽配色的唯一数据源，
/// 同时提供 WCAG 相对亮度与对比度计算，保证「亮色键帽配深色字符 / 深色键帽配浅色字符」始终可读。
public struct KeyColorRGB: Sendable, Equatable, Hashable {
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

    /// 色度（最大通道与最小通道之差），用于校验「七档色相同明度、只差色相」的设计不变量
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
    /// 代表色（选择器圆点、光晕、描边）
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
    ///
    /// 0.2 起收窄了提亮与压暗幅度：新材质要求「直接显示原色、明亮优先」，
    /// 过大的明度落差会把七档色相压成同一团暗色，色相区分反而丢失。
    public static func tone(_ base: KeyColorRGB) -> KeycapPalette {
        let luminance = base.relativeLuminance
        // 浅色键帽本身亮度高，提亮幅度收窄，避免渐变糊成一片；深色键帽需要更大反差才看得出弧面
        let lift = luminance > 0.55 ? 0.05 : 0.10
        let drop = luminance > 0.55 ? 0.09 : 0.13
        let depth = luminance > 0.55 ? 0.20 : 0.30

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
        isLightSurface ? Color.white.opacity(0.55) : Color.black.opacity(0.35)
    }

    /// 环境光晕：由强调色派生，但强度刻意压低，避免饱和色在浅背景上晕成彩雾
    public var glowColor: Color {
        accent.color(opacity: isLightSurface ? 0.14 : 0.22)
    }

    /// 键帽顶面渐变
    public var topFaceColors: [Color] {
        [top.color, bottom.color]
    }
}

// MARK: - 描边策略

/// 键帽倒角高光策略（由主题指定，保证整套视觉统一，不暴露给用户调节）
public enum KeycapBorderStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    /// 自适应微光：浅键白描边、深键亮描边，最接近实体注塑键帽
    case adaptive
    /// 霓虹描边：强调色发光，七档色相的辨识度主要由这圈边承担
    case neon

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .adaptive: return "自适应微光"
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
        case .neon:
            return LinearGradient(
                colors: [
                    palette.accent.color(opacity: 0.95),
                    palette.accent.color(opacity: 0.55),
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

// MARK: - 按键颜色角色（七档）

/// 按键在配色体系中的角色（决定它读取主题中的哪一档色相）
public enum KeyColorRole: String, Sendable, Equatable, CaseIterable {
    case escape      // Esc
    case structural  // Return / Delete / Tab / Space / Home / End / PageUp / PageDown
    case function    // F1~F20 / Fn
    case arrow       // ← ↑ ↓ →
    case modifier    // ⌘ ⌥ ⌃ ⇧ / CapsLock
    case digit       // 0~9
    case alpha       // 字母与符号

    public var title: String {
        switch self {
        case .escape: return "Esc 键"
        case .structural: return "结构键"
        case .function: return "功能键"
        case .arrow: return "方向键"
        case .modifier: return "修饰键"
        case .digit: return "数字键"
        case .alpha: return "字母键"
        }
    }

    /// 该角色在设置面板色卡带中的展示顺序：
    /// 从「英雄键」到「底色」逐层退后，正好是视觉上从最抢眼到最安静的排列。
    public static let displayOrder: [KeyColorRole] = [
        .escape, .structural, .function, .arrow, .modifier, .digit, .alpha
    ]
}

// MARK: - 一套主题在某一外观下的七档配色

/// 单一外观（白天或夜晚）下，七种按键角色的完整色板
public struct ThemeColorSet: Sendable, Equatable {
    public let escape: KeycapPalette
    public let structural: KeycapPalette
    public let function: KeycapPalette
    public let arrow: KeycapPalette
    public let modifier: KeycapPalette
    public let digit: KeycapPalette
    public let alpha: KeycapPalette

    public init(
        escape: KeycapPalette,
        structural: KeycapPalette,
        function: KeycapPalette,
        arrow: KeycapPalette,
        modifier: KeycapPalette,
        digit: KeycapPalette,
        alpha: KeycapPalette
    ) {
        self.escape = escape
        self.structural = structural
        self.function = function
        self.arrow = arrow
        self.modifier = modifier
        self.digit = digit
        self.alpha = alpha
    }

    /// 由七个基准色一次性构建（内部统一走 `KeycapPalette.tone`，保证物理光照关系一致）
    public init(
        escape: KeyColorRGB,
        structural: KeyColorRGB,
        function: KeyColorRGB,
        arrow: KeyColorRGB,
        modifier: KeyColorRGB,
        digit: KeyColorRGB,
        alpha: KeyColorRGB
    ) {
        self.init(
            escape: .tone(escape),
            structural: .tone(structural),
            function: .tone(function),
            arrow: .tone(arrow),
            modifier: .tone(modifier),
            digit: .tone(digit),
            alpha: .tone(alpha)
        )
    }

    public func palette(for role: KeyColorRole) -> KeycapPalette {
        switch role {
        case .escape: return escape
        case .structural: return structural
        case .function: return function
        case .arrow: return arrow
        case .modifier: return modifier
        case .digit: return digit
        case .alpha: return alpha
        }
    }

    /// 该外观下的七档色板（供测试与遍历使用）
    public var allPalettes: [KeycapPalette] {
        [escape, structural, function, arrow, modifier, digit, alpha]
    }

    /// 按视觉层级排列的七档色板：设置面板的色卡带按这个顺序排布
    public var hierarchy: [KeycapPalette] {
        KeyColorRole.displayOrder.map { palette(for: $0) }
    }
}

// MARK: - 主题

/// 内置主题：同时携带白天 / 夜晚两套配色，并指定描边策略
public struct KeycapTheme: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let subtitle: String
    /// 白天（浅色系统外观）配色
    public let light: ThemeColorSet
    /// 夜晚（深色系统外观）配色
    public let dark: ThemeColorSet
    /// 描边策略
    public let border: KeycapBorderStyle

    /// 按 SwiftUI 环境外观解析实际配色
    public func colors(for scheme: ColorScheme) -> ThemeColorSet {
        scheme == .dark ? dark : light
    }

    /// 是否为深色主题（夜晚档整体偏暗，用于设置面板上的标签）
    public var isDarkFirst: Bool {
        dark.alpha.midTone.relativeLuminance < 0.2 && light.alpha.midTone.relativeLuminance > 0.6
    }
}

// MARK: - 内置主题清单

extension KeycapTheme {
    /// 七色花瓣 · 樱花色谱
    ///
    /// 七个色相取自樱花树的一整套意象：花瓣粉、花蕊金、嫩芽绿、暮空青、藤紫、花瓣桃、月白。
    /// 全部由 OKLCH 固定感知明度（浅色档 0.845–0.890 / 深色档 0.690–0.730）只变色相派生，
    /// 明度完全拉平，因此「每类按键不同色」不会演变成「七种亮度互相打架」。
    public static let petals = KeycapTheme(
        id: "petals",
        name: "七色花瓣",
        subtitle: "花瓣粉 · 花蕊金 · 嫩芽绿 · 暮空青 · 藤紫 · 桃 · 月白",
        light: ThemeColorSet(
            escape: KeyColorRGB(hex: 0xFFAEB8),
            structural: KeyColorRGB(hex: 0xF0CA78),
            function: KeyColorRGB(hex: 0x94D8FC),
            arrow: KeyColorRGB(hex: 0xBEDD9F),
            modifier: KeyColorRGB(hex: 0xD5BEFF),
            digit: KeyColorRGB(hex: 0xFFC4AA),
            alpha: KeyColorRGB(hex: 0xE6D6DC)
        ),
        dark: ThemeColorSet(
            escape: KeyColorRGB(hex: 0xF07683),
            structural: KeyColorRGB(hex: 0xC29733),
            function: KeyColorRGB(hex: 0x55A8D0),
            arrow: KeyColorRGB(hex: 0x8AAD66),
            modifier: KeyColorRGB(hex: 0xA68BD5),
            digit: KeyColorRGB(hex: 0xD88E71),
            alpha: KeyColorRGB(hex: 0xB6A1AA)
        ),
        border: .neon
    )

    /// 星空 · 银河色谱
    ///
    /// 色相取自深空摄影里真实存在的星体色：星尘金（北极星）、星云品红（猎户座大星云）、
    /// 深空蓝、彗星青、银河紫，以及一对色温相反的「月光暖白 / 星尘冷白」——
    /// 用色温而不是色相来区分数字区与字母区，避免七种颜色在同一个蓝紫区里挤成一团。
    public static let starfield = KeycapTheme(
        id: "starfield",
        name: "星空",
        subtitle: "星尘金 · 星云品红 · 深空蓝 · 彗星青 · 银河紫 · 月光 · 星尘",
        light: ThemeColorSet(
            escape: KeyColorRGB(hex: 0xFFD16B),
            structural: KeyColorRGB(hex: 0xFFAEDA),
            function: KeyColorRGB(hex: 0x9BCFFF),
            arrow: KeyColorRGB(hex: 0x85E4E3),
            modifier: KeyColorRGB(hex: 0xD6BEFF),
            digit: KeyColorRGB(hex: 0xF8D4BE),
            alpha: KeyColorRGB(hex: 0xD3D9E7)
        ),
        dark: ThemeColorSet(
            escape: KeyColorRGB(hex: 0xDCA81E),
            structural: KeyColorRGB(hex: 0xDC79AA),
            function: KeyColorRGB(hex: 0x649FE0),
            arrow: KeyColorRGB(hex: 0x3AB4B4),
            modifier: KeyColorRGB(hex: 0xA88CDA),
            digit: KeyColorRGB(hex: 0xC69E84),
            alpha: KeyColorRGB(hex: 0x9EA6B8)
        ),
        border: .neon
    )

    /// 夜丁香 · Noctis Lilac 色谱
    ///
    /// 取自 Noctis Lilac 终端配色：强调紫 `#7060EB` 落在修饰键档，Esc 取该方案的 bright magenta
    /// （`#DF769B`）作英雄键，其余档位依次分给它的 blue / cyan / green / yellow 四支；
    /// 字母底档沿用其紫灰中性色（`#B8B5C5` 一族），使整块键盘带一点冷紫的夜色倾向。
    /// 明度沿用七档色相的统一规律（浅色档 0.845–0.900 / 深色档 0.700–0.752），
    /// 只把色相与色度换成 Noctis Lilac 的口味，因此七档之间的亮度关系与另两套主题一致。
    public static let lilac = KeycapTheme(
        id: "lilac",
        name: "夜丁香",
        subtitle: "玫瑰粉 · 深空蓝 · 湖青 · 苔绿 · 丁香紫 · 蜜金 · 雾白",
        light: ThemeColorSet(
            escape: KeyColorRGB(hex: 0xFCB1DF),
            structural: KeyColorRGB(hex: 0xADD7FF),
            function: KeyColorRGB(hex: 0x92E4E8),
            arrow: KeyColorRGB(hex: 0xA9E7BD),
            modifier: KeyColorRGB(hex: 0xC6C6FF),
            digit: KeyColorRGB(hex: 0xFFCD88),
            alpha: KeyColorRGB(hex: 0xDCDCED)
        ),
        dark: ThemeColorSet(
            escape: KeyColorRGB(hex: 0xDE76AE),
            structural: KeyColorRGB(hex: 0x69A9E9),
            function: KeyColorRGB(hex: 0x42BBC1),
            arrow: KeyColorRGB(hex: 0x70BD8C),
            modifier: KeyColorRGB(hex: 0x9891F6),
            digit: KeyColorRGB(hex: 0xDC9D39),
            alpha: KeyColorRGB(hex: 0xABABC9)
        ),
        border: .neon
    )

    /// 全部内置主题（顺序即设置面板展示顺序）
    public static let all: [KeycapTheme] = [petals, starfield, lilac]

    /// 出厂默认主题
    public static let defaultTheme: KeycapTheme = petals

    /// 把持久化/导入的主题 id 解析成当前目录下真实存在的 id。
    /// 旧版本的六套主题已全部下线，任何无法识别的 id 一律回退到默认主题（而不是留空）。
    public static func resolvedID(_ stored: String) -> String {
        all.contains(where: { $0.id == stored }) ? stored : defaultTheme.id
    }

    /// 按 id 查找，找不到时回退默认主题（防止旧配置残留导致空白）
    public static func theme(id: String) -> KeycapTheme {
        all.first(where: { $0.id == id }) ?? defaultTheme
    }
}

// MARK: - 按键与主题的关联

extension KeyStroke {
    /// 当前按键对应的颜色角色：连按角标与键帽本身必须共用同一角色，颜色才不会错位。
    ///
    /// 判定只依赖 `rawIdentifier`：`KeyCodeMapper` 为每个物理键生成了稳定的标识
    /// （esc / return / tab / space / delete / f1...f20 / fn / left_arrow...），
    /// 组合键则为「修饰键+主键」，因此取最后一段即主键标识。
    public var colorRole: KeyColorRole {
        let identifier = rawIdentifier.lowercased()
        let baseID = identifier.split(separator: "+").last.map(String.init) ?? identifier

        if baseID == "esc" || baseID == "escape" { return .escape }
        if isModifierOnly { return .modifier }
        if Self.arrowIdentifiers.contains(baseID) { return .arrow }
        if Self.functionIdentifiers.contains(baseID) { return .function }
        // F1~F20：以 f 开头且其后全为数字（避免把字母 f 误判为功能键）
        if baseID.count > 1, baseID.hasPrefix("f"), baseID.dropFirst().allSatisfy(\.isNumber) {
            return .function
        }
        if Self.structuralIdentifiers.contains(baseID) { return .structural }
        if baseID.count == 1, baseID.first?.isNumber == true { return .digit }
        // 未逐项列出的特殊功能键（音量、Clear、Help 等）统一归入结构层，避免落进字母档
        if isSpecialFunctionKey { return .structural }
        return .alpha
    }

    /// 方向键
    private static let arrowIdentifiers: Set<String> = [
        "left_arrow", "right_arrow", "up_arrow", "down_arrow"
    ]

    /// 与 F 区同色相的顶部功能键（Fn / Globe）
    private static let functionIdentifiers: Set<String> = ["fn"]

    /// 结构键：回车 / 删除 / 制表 / 空格 / 翻页导航
    private static let structuralIdentifiers: Set<String> = [
        "return", "enter", "tab", "space", "delete", "forward_delete",
        "home", "end", "page_up", "page_down", "clear", "help"
    ]
}
