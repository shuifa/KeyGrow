//
//  KeycapMaterial.swift
//  KeyGlow
//
//  键帽「材质字典」——0.100 配色的唯一数据源。
//
//  设计来源：Keystroke Pro v2 实测（见 design/keystroke-pro-visual-analysis.md）。
//  它不使用「色相主题」，而使用一套**物理材料命名**的字典：Aluminium / Graphite / Space /
//  Agate Gray / Accent + 八个手工挑选的高饱和塑料色。用户挑的是「这只键帽是什么材料做的」，
//  而不是「这张配色卡叫什么名字」。四类按键（按键 / 修饰键 / Esc / 底板）各自独立挑一种材质，
//  任意组合都被允许（原版甚至给出过浅修饰键 + 深字母键的完整反转）。
//
//  材质的核心规律有两条，全部来自像素采样：
//   1. **中性材质上亮下暗**（金属的冷感），彩色材质**上暗下亮**（保住饱和度，不读成暗块）；
//   2. 彩色键的前唇被压暗到约 25%，中性键的前唇只轻微压暗——前者像注塑 ABS，后者像阳极氧化铝。
//

import AppKit
import SwiftUI

// MARK: - 材质

/// 材质的色彩来源
public enum KeycapMaterialSource: Sendable, Equatable, Hashable {
    /// 中性材质：直接给出实测的顶面双端色（上亮下暗，幅度随材质浮动，不是固定常数）
    case neutral(top: KeyColorRGB, bottom: KeyColorRGB)
    /// 彩色材质：单一基准色，顶面/前唇/唇线全部由它派生（上暗下亮）
    case chromatic(KeyColorRGB)
    /// 跟随系统强调色（按彩色材质处理，每次渲染时解析）
    case systemAccent
}

/// 一种键帽材质
public struct KeycapMaterial: Identifiable, Sendable, Equatable, Hashable {
    public let id: String
    /// 中文名（设置面板主标题）
    public let name: String
    /// 原版材质名（保留英文，便于与 Keystroke Pro 对照）
    public let englishName: String
    public let source: KeycapMaterialSource

    public init(id: String, name: String, englishName: String, source: KeycapMaterialSource) {
        self.id = id
        self.name = name
        self.englishName = englishName
        self.source = source
    }

    /// 该材质的代表色（设置面板的色点，也是「未解析外观时」的近似色）
    public var swatch: KeyColorRGB {
        switch source {
        case .neutral(_, let bottom):
            return bottom
        case .chromatic(let base):
            return base
        case .systemAccent:
            return .systemAccent()
        }
    }

    /// 派生完整色板。`appearance` 只影响「跟随系统强调色」这一种材质。
    public func palette(appearance: NSAppearance? = nil) -> KeycapPalette {
        switch source {
        case .neutral(let top, let bottom):
            return KeycapPalette.neutral(top: top, bottom: bottom)
        case .chromatic(let base):
            return KeycapPalette.chromatic(base)
        case .systemAccent:
            return KeycapPalette.chromatic(.systemAccent(for: appearance))
        }
    }
}

// MARK: - 单个键帽的完整色板

/// 单个键帽的五层材质色（自下而上：侧壁/前唇 → 折角 → 顶面 → 唇线 → 字符）
public struct KeycapPalette: Sendable, Equatable {
    /// 顶面渐变起始色（顶边）
    public let faceTop: KeyColorRGB
    /// 顶面渐变终止色（下沿）
    public let faceBottom: KeyColorRGB
    /// 前唇／侧壁（键帽的物理厚度）
    public let wall: KeyColorRGB
    /// 顶面与前唇之间的折角暗部（没有它顶面会重新读成平面）
    public let crease: KeyColorRGB
    /// 顶面下沿被前唇反打亮的唇线
    public let lip: KeyColorRGB
    /// 代表色（选择器圆点、连按角标描边）
    public let accent: KeyColorRGB

    /// 字符所在位置的中间调，用于判定字符颜色
    public var midTone: KeyColorRGB {
        faceTop.mixed(with: faceBottom, ratio: 0.5)
    }

    /// 顶面渐变（从上到下）
    public var faceColors: [Color] {
        [faceTop.color, faceBottom.color]
    }

    /// 白字优先：只有当白字对比度低于 3:1 时才翻成深墨字。
    ///
    /// 这条规则比「永远选对比度更高的一方」更贴近原版观感：
    /// 红 / 橙 / 蓝 / 靛紫等中等明度彩色键保白字（原版同款），
    /// 只有琥珀、草绿、薄荷这类高亮度键才翻黑字，避免白字糊在键面上。
    public var usesDarkLegend: Bool {
        midTone.contrastRatio(with: .white) < 3.0
    }

    /// 字符颜色
    public var legendColor: Color {
        (usesDarkLegend ? KeyColorRGB.ink : KeyColorRGB.white).color
    }

    /// 字符实际对比度（测试与可读性校验用）
    public var legendContrastRatio: Double {
        midTone.contrastRatio(with: usesDarkLegend ? .ink : .white)
    }

    /// 字符雕刻阴影：浅键用亮边提字、深键用暗边压字
    public var legendShadowColor: Color {
        usesDarkLegend ? Color.white.opacity(0.55) : Color.black.opacity(0.35)
    }

    /// 键帽外缘的微倒角描边（顶亮底暗的 1px 物理描边）
    public var borderHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(usesDarkLegend ? 0.45 : 0.26),
                Color.white.opacity(0.03),
                Color.black.opacity(usesDarkLegend ? 0.08 : 0.24)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - 派生规则

    /// 中性材质：上亮下暗。前唇压暗幅度按明暗分档（浅铝只轻微压暗，石墨压得深）
    public static func neutral(top: KeyColorRGB, bottom: KeyColorRGB) -> KeycapPalette {
        let mid = top.mixed(with: bottom, ratio: 0.5)
        let isLight = mid.contrastRatio(with: .white) < 3.0
        return KeycapPalette(
            faceTop: top,
            faceBottom: bottom,
            wall: bottom.darkened(isLight ? 0.14 : 0.42),
            crease: bottom.darkened(0.18),
            lip: bottom.lightened(0.10),
            accent: mid
        )
    }

    /// 彩色材质：上暗下亮。顶面几乎就是原色，前唇压到约 25% 亮度，唇线打亮 22%
    ///
    /// 提亮幅度刻意收到 9% 以内：早期版本用 13%，实机渲染会整块偏粉，
    /// 失去「注塑 ABS 塑料」那种饱和而不飘的观感。
    public static func chromatic(_ base: KeyColorRGB) -> KeycapPalette {
        KeycapPalette(
            faceTop: base.darkened(0.08),
            faceBottom: base.lightened(0.09),
            wall: base.darkened(0.70),
            crease: base.darkened(0.18),
            lip: base.lightened(0.22),
            accent: base
        )
    }
}

// MARK: - 材质字典

extension KeycapMaterial {
    // —— 中性材质（实测双端色） ——

    /// 浅铝：原版 Key Color 出厂值，MacBook 银灰机身同源
    public static let aluminium = KeycapMaterial(
        id: "aluminium",
        name: "浅铝",
        englishName: "Aluminium",
        source: .neutral(top: KeyColorRGB(hex: 0xF4F4F4), bottom: KeyColorRGB(hex: 0xB8B8B8))
    )

    /// 象牙白：纯白键帽，深色底板上对比最锐
    public static let ivory = KeycapMaterial(
        id: "ivory",
        name: "象牙白",
        englishName: "Ivory",
        source: .neutral(top: KeyColorRGB(hex: 0xFFFFFF), bottom: KeyColorRGB(hex: 0xDCDCDE))
    )

    /// 石墨：原版 Escape 档常见的中性深灰
    public static let graphite = KeycapMaterial(
        id: "graphite",
        name: "石墨",
        englishName: "Graphite",
        source: .neutral(top: KeyColorRGB(hex: 0x525252), bottom: KeyColorRGB(hex: 0x2D2D2D))
    )

    /// 深空：近黑的哑光深灰，原版 Modifier Color 出厂值
    public static let space = KeycapMaterial(
        id: "space",
        name: "深空",
        englishName: "Space",
        source: .neutral(top: KeyColorRGB(hex: 0x2E2E30), bottom: KeyColorRGB(hex: 0x131315))
    )

    // —— 彩色材质（单一基准色） ——

    /// 八个手工挑选的高饱和塑料色，色相间隔不均（原版即如此，不是算法匀分）
    public static let red = KeycapMaterial(
        id: "red", name: "朱红", englishName: "Red",
        source: .chromatic(KeyColorRGB(hex: 0xFC2C32))
    )
    public static let orange = KeycapMaterial(
        id: "orange", name: "橙", englishName: "Orange",
        source: .chromatic(KeyColorRGB(hex: 0xFC5219))
    )
    public static let amber = KeycapMaterial(
        id: "amber", name: "琥珀", englishName: "Amber",
        source: .chromatic(KeyColorRGB(hex: 0xFCA827))
    )
    public static let grass = KeycapMaterial(
        id: "grass", name: "草绿", englishName: "Grass",
        source: .chromatic(KeyColorRGB(hex: 0x74CD25))
    )
    public static let mint = KeycapMaterial(
        id: "mint", name: "薄荷", englishName: "Mint",
        source: .chromatic(KeyColorRGB(hex: 0x1AC884))
    )
    public static let cobalt = KeycapMaterial(
        id: "cobalt", name: "钴蓝", englishName: "Cobalt",
        source: .chromatic(KeyColorRGB(hex: 0x3A53F5))
    )
    public static let indigo = KeycapMaterial(
        id: "indigo", name: "靛紫", englishName: "Indigo",
        source: .chromatic(KeyColorRGB(hex: 0x5E39F0))
    )
    public static let fuchsia = KeycapMaterial(
        id: "fuchsia", name: "品红", englishName: "Fuchsia",
        source: .chromatic(KeyColorRGB(hex: 0xE804C7))
    )

    /// 跟随系统强调色（原版 Escape Color 的出厂值）
    public static let accent = KeycapMaterial(
        id: "accent",
        name: "强调色",
        englishName: "Accent Color",
        source: .systemAccent
    )

    // —— 仅用于底板的材质 ——

    /// 玛瑙灰：原版 Border Color 出厂值
    public static let agate = KeycapMaterial(
        id: "agate",
        name: "玛瑙灰",
        englishName: "Agate Gray",
        source: .neutral(top: KeyColorRGB(hex: 0x1C1C1E), bottom: KeyColorRGB(hex: 0x0E0E10))
    )

    /// 白垩：浅色底板上使用，浅色桌面下依然保留一条可见的托板边界
    public static let chalk = KeycapMaterial(
        id: "chalk",
        name: "白垩",
        englishName: "Chalk",
        source: .neutral(top: KeyColorRGB(hex: 0xF2F2F4), bottom: KeyColorRGB(hex: 0xD4D4D8))
    )

    /// 中灰：介于玛瑙灰与白垩之间的中性托板
    public static let chromium = KeycapMaterial(
        id: "chromium",
        name: "中灰",
        englishName: "Chromium",
        source: .neutral(top: KeyColorRGB(hex: 0x6E6E72), bottom: KeyColorRGB(hex: 0x4A4A4E))
    )

    /// 可作为键帽颜色的材质（顺序即设置面板展示顺序：中性在前，彩色在后）
    public static let keyCatalog: [KeycapMaterial] = [
        aluminium, ivory, graphite, space,
        red, orange, amber, grass, mint, cobalt, indigo, fuchsia,
        accent
    ]

    /// 可作为底板颜色的材质
    public static let plateCatalog: [KeycapMaterial] = [
        agate, space, chromium, chalk
    ]

    /// 目录内含底板材质在内的全部材质
    public static let all: [KeycapMaterial] = {
        var seen = Set<String>()
        return (keyCatalog + plateCatalog).filter { seen.insert($0.id).inserted }
    }()

    /// 按 id 查找；找不到时回退到给定默认材质（防止旧配置残留导致空白）
    public static func material(id: String, fallback: KeycapMaterial) -> KeycapMaterial {
        all.first(where: { $0.id == id }) ?? fallback
    }
}

// MARK: - 四色槽

/// 键帽在配色体系中的角色——只有三档，与原版的三个按键色槽一一对应
public enum KeycapColorRole: String, CaseIterable, Sendable, Equatable {
    /// Esc：唯一的「英雄键」，通常给强调色或高饱和彩色
    case escape
    /// 修饰键：⌘ ⌥ ⌃ ⇧ Fn CapsLock
    case modifier
    /// 其余所有按键：字母/数字/功能键/方向键/回车等
    case key

    public var title: String {
        switch self {
        case .escape: return "Esc 键"
        case .modifier: return "修饰键"
        case .key: return "按键"
        }
    }

    /// 设置面板的展示顺序（按视觉层级从最抢眼到最安静）
    public static let displayOrder: [KeycapColorRole] = [.escape, .modifier, .key]
}

/// 四色槽：按键 / 修饰键 / Esc / 底板，各自独立挑材质，任意组合都被允许
public struct KeycapColorSlots: Sendable, Equatable {
    public var escape: String
    public var modifier: String
    public var key: String
    public var border: String

    public init(escape: String, modifier: String, key: String, border: String) {
        self.escape = escape
        self.modifier = modifier
        self.key = key
        self.border = border
    }

    /// 出厂四槽：完全对齐 Keystroke Pro 的默认外观
    /// （Key = Aluminium / Modifier = Space / Escape = Accent Color / Border = Agate Gray）
    public static let defaults = KeycapColorSlots(
        escape: KeycapMaterial.accent.id,
        modifier: KeycapMaterial.space.id,
        key: KeycapMaterial.aluminium.id,
        border: KeycapMaterial.agate.id
    )

    public func materialID(for role: KeycapColorRole) -> String {
        switch role {
        case .escape: return escape
        case .modifier: return modifier
        case .key: return key
        }
    }

    public mutating func setMaterialID(_ id: String, for role: KeycapColorRole) {
        switch role {
        case .escape: escape = id
        case .modifier: modifier = id
        case .key: key = id
        }
    }

    public func material(for role: KeycapColorRole) -> KeycapMaterial {
        KeycapMaterial.material(
            id: materialID(for: role),
            fallback: KeycapMaterial.material(id: Self.defaults.materialID(for: role), fallback: .aluminium)
        )
    }

    /// 底板材质
    public var borderMaterial: KeycapMaterial {
        KeycapMaterial.material(id: border, fallback: .agate)
    }

    public func palette(for role: KeycapColorRole, appearance: NSAppearance? = nil) -> KeycapPalette {
        material(for: role).palette(appearance: appearance)
    }

    /// 把无法识别的材质 id 归位到出厂值（用于读取旧配置后的自愈）
    public func normalized() -> KeycapColorSlots {
        var result = self
        for role in KeycapColorRole.allCases {
            let material = self.material(for: role)
            result.setMaterialID(material.id, for: role)
        }
        result.border = borderMaterial.id
        return result
    }
}
