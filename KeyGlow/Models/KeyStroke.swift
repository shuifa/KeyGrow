//
//  KeyStroke.swift
//  KeyGlow
//

import SwiftUI

/// 键盘修饰键枚举
public enum KeyModifier: String, CaseIterable, Codable, Hashable, Sendable {
    case control = "control"
    case option = "option"
    case shift = "shift"
    case command = "command"

    /// SF Symbol 系统图标名称
    public var sfSymbol: String {
        switch self {
        case .control: return "control"
        case .option: return "option"
        case .shift: return "shift"
        case .command: return "command"
        }
    }

    /// 传统按键符号（备用与描述）
    public var glyph: String {
        switch self {
        case .control: return "⌃"
        case .option: return "⌥"
        case .shift: return "⇧"
        case .command: return "⌘"
        }
    }

    /// 排序权重（macOS 标准顺序：⌃ ⌥ ⇧ ⌘）
    public var sortOrder: Int {
        switch self {
        case .control: return 1
        case .option: return 2
        case .shift: return 3
        case .command: return 4
        }
    }
}

/// 键位内容展示载体（SF Symbol 图标或字符文本）
public enum KeyDisplayContent: Equatable, Hashable, Sendable {
    case symbol(name: String, fallbackText: String)
    case text(String)

    public var displayText: String {
        switch self {
        case .symbol(_, let fallback):
            return fallback
        case .text(let str):
            return str
        }
    }
}

/// 单次键盘触发的组合或按键对象
public struct KeyStroke: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let modifiers: [KeyModifier]
    public let content: KeyDisplayContent
    public let rawIdentifier: String
    public let isShortcut: Bool
    public let isSpecialFunctionKey: Bool
    public var timestamp: Date
    public var repeatCount: Int

    public init(
        id: UUID = UUID(),
        modifiers: [KeyModifier] = [],
        content: KeyDisplayContent,
        rawIdentifier: String,
        isShortcut: Bool = false,
        isSpecialFunctionKey: Bool = false,
        timestamp: Date = Date(),
        repeatCount: Int = 1
    ) {
        self.id = id
        // 保证修饰键始终按照 macOS 官方标准顺序排序
        self.modifiers = modifiers.sorted(by: { $0.sortOrder < $1.sortOrder })
        self.content = content
        self.rawIdentifier = rawIdentifier
        self.isShortcut = isShortcut
        self.isSpecialFunctionKey = isSpecialFunctionKey
        self.timestamp = timestamp
        self.repeatCount = repeatCount
    }
}
