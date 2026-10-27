//
//  KeyStroke.swift
//  KeyGlow
//
//  按键数据模型：修饰键、键帽图例与一次按键事件。
//
//  0.100 的三个变化：
//   1. `KeyDisplayContent`（符号 / 文本二选一）换成 `KeyLegend`（符号 + 标签 + 键帽宽度），
//      才能表达原版「符号右上、标签右下、宽键按真实键盘比例」的排版；
//   2. 新增 `isDisplayable` 显示策略：只有特殊键与含修饰键的组合才上台面；
//   3. `colorRole` 从七档收敛为三档，对齐原版的三个按键色槽。
//

import CoreGraphics
import Foundation

// MARK: - 修饰键

/// 键盘修饰键
public enum KeyModifier: String, CaseIterable, Codable, Hashable, Sendable {
    case control = "control"
    case option = "option"
    case shift = "shift"
    case command = "command"

    /// SF Symbol 名称（与 macOS 原生符号字形一致）
    public var sfSymbol: String {
        switch self {
        case .control: return "control"
        case .option: return "option"
        case .shift: return "shift"
        case .command: return "command"
        }
    }

    /// 传统符号字符（备用与无障碍标签）
    public var glyph: String {
        switch self {
        case .control: return "⌃"
        case .option: return "⌥"
        case .shift: return "⇧"
        case .command: return "⌘"
        }
    }

    /// 小写英文标签，与原版键帽一致（command / option / control / shift）
    public var label: String { rawValue }

    /// 排序权重（macOS 标准顺序：⌃ ⌥ ⇧ ⌘）
    public var sortOrder: Int {
        switch self {
        case .control: return 1
        case .option: return 2
        case .shift: return 3
        case .command: return 4
        }
    }

    /// 修饰键键帽：符号 + 标签，宽度 1.5u（原版 command 实测 1.51u）
    public var legend: KeyLegend {
        KeyLegend(symbol: sfSymbol, text: label, widthUnits: 1.5)
    }
}

// MARK: - 键帽图例

/// 键帽上要画什么：SF Symbol、文字标签，以及这只键帽在键盘上的宽度（1u 为基准）
///
/// 排版由视图按三条规则决定：
///   - 符号 + 标签同时存在 → 符号右上、标签右下（原版排版）
///   - 只有符号 → 居中放大（方向键）
///   - 只有文字 → 单字符居中放大，"F1" 之类多字符居中缩小
public struct KeyLegend: Equatable, Hashable, Sendable {
    public let symbol: String?
    public let text: String?
    /// 键帽宽度倍数（1u 为 0.97 × 高度）
    public let widthUnits: Double

    public init(symbol: String? = nil, text: String? = nil, widthUnits: Double = 1.0) {
        self.symbol = symbol
        self.text = text
        self.widthUnits = widthUnits
    }

    /// 是否为「符号 + 标签」的双元素排版
    public var isDualElement: Bool {
        symbol != nil && text != nil
    }

    /// 是否为单字符键帽（居中大字号）
    public var isSingleCharacter: Bool {
        symbol == nil && (text?.count ?? 0) == 1
    }

    /// 纯文本图例（无障碍标签 / 胶囊排版使用）
    public var plainText: String {
        if let text { return text }
        if let symbol { return symbol }
        return ""
    }
}

// MARK: - 单次按键

/// 单次键盘触发的组合或按键对象
public struct KeyStroke: Identifiable, Equatable, Sendable {
    public let id: UUID
    /// 修饰键前缀（不含主键本身）
    public let modifiers: [KeyModifier]
    /// 主键图例
    public let legend: KeyLegend
    /// 稳定标识：`cmd+option+c` / `esc` / `f5`，用于连按合并与就地升级
    public let rawIdentifier: String
    /// 是否为非字符键（特殊键、功能键、修饰键）
    public let isSpecialKey: Bool
    /// 是否只按下了修饰键本身（⌘ / ⌘⌥ 这类尚未落到主键的中间态）
    public let isModifierOnly: Bool
    public var timestamp: Date
    /// 连按次数（关闭连按角标时不参与渲染）
    public var repeatCount: Int

    public init(
        id: UUID = UUID(),
        modifiers: [KeyModifier] = [],
        legend: KeyLegend,
        rawIdentifier: String,
        isSpecialKey: Bool = false,
        isModifierOnly: Bool = false,
        timestamp: Date = Date(),
        repeatCount: Int = 1
    ) {
        self.id = id
        // 修饰键始终按 macOS 官方标准顺序排列
        self.modifiers = modifiers.sorted(by: { $0.sortOrder < $1.sortOrder })
        self.legend = legend
        self.rawIdentifier = rawIdentifier
        self.isSpecialKey = isSpecialKey
        self.isModifierOnly = isModifierOnly
        self.timestamp = timestamp
        self.repeatCount = repeatCount
    }

    /// 该按键是否应该出现在屏幕上
    ///
    /// 0.100 起与 Keystroke Pro 一致：**不再逐字回显打字内容**。
    /// 只有两类按键上台面——
    ///   1. 非字符键（F1–F12 / Fn / ⌘⌥⌃⇧ / 方向键 / esc / return / delete / tab / space 等）；
    ///   2. 含 ⌘ / ⌃ / ⌥ 的组合（⌘S、⌃⇧Tab、⌥←）。
    ///
    /// 单独敲字母、数字、标点一律静默，避免录屏里泄漏正在输入的文字内容。
    /// 「⇧ + 字符键」同样不上台面：那只是**打了一个大写字母**，不是快捷键——
    /// 否则每敲一句英文就会闪一片 ⇧H、⇧W。
    public var isDisplayable: Bool {
        if isSpecialKey { return true }
        // 只有 ⇧ 参与的字符组合仍属于普通输入
        return modifiers.contains(where: { $0 != .shift })
    }

    /// 该按键取哪个色槽
    public var colorRole: KeycapColorRole {
        let baseID = rawIdentifier.split(separator: "+").last.map(String.init) ?? rawIdentifier
        if baseID == "esc" || baseID == "escape" { return .escape }
        if isModifierOnly { return .modifier }
        return .key
    }

    /// 整组键帽在键盘上的总宽度（单位 u），用于底板与胶囊的自适应宽度
    public var totalWidthUnits: Double {
        modifiers.reduce(0) { $0 + $1.legend.widthUnits } + legend.widthUnits
    }
}
