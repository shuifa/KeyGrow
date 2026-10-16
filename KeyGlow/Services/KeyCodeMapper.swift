//
//  KeyCodeMapper.swift
//  KeyGlow
//

import CoreGraphics
import Foundation

/// macOS 虚拟按键码到显示字符与 SF Symbols 的精准映射
public struct KeyCodeMapper {

    public struct KeyInfo: Sendable {
        public let content: KeyDisplayContent
        public let isSpecialFunctionKey: Bool
        public let identifier: String
    }

    /// 根据按键事件和键码解析键帽内容
    public static func map(event: CGEvent, keyCode: CGKeyCode) -> KeyInfo {
        // 1. 优先匹配系统特殊按键（方向键、功能键、编辑键）
        if let special = specialKeyMap[keyCode] {
            return special
        }

        // 2. 尝试从 CGEvent 读取真实的 Unicode 字符（自动适配当前输入法键盘布局）
        var length: Int = 0
        event.keyboardGetUnicodeString(maxStringLength: 0, actualStringLength: &length, unicodeString: nil)

        if length > 0 {
            var buffer = [UniChar](repeating: 0, count: length)
            event.keyboardGetUnicodeString(maxStringLength: length, actualStringLength: &length, unicodeString: &buffer)
            let rawStr = String(utf16CodeUnits: buffer, count: length)

            // 过滤不可打印字符或控制字符
            let trimmed = rawStr.trimmingCharacters(in: .controlCharacters)
            if !trimmed.isEmpty {
                let display = trimmed.uppercased()
                return KeyInfo(
                    content: .text(display),
                    isSpecialFunctionKey: false,
                    identifier: display.lowercased()
                )
            }
        }

        // 3. Fallback 到通用键码描述
        let fallback = "Key_\(keyCode)"
        return KeyInfo(
            content: .text(fallback),
            isSpecialFunctionKey: false,
            identifier: fallback.lowercased()
        )
    }

    // MARK: - 特殊键映射表 (Virtual Keycodes)

    private static let specialKeyMap: [CGKeyCode: KeyInfo] = [
        // 编辑与排版
        36: KeyInfo(content: .symbol(name: "return", fallbackText: "Return"), isSpecialFunctionKey: true, identifier: "return"),
        48: KeyInfo(content: .symbol(name: "arrow.right.to.line", fallbackText: "Tab"), isSpecialFunctionKey: true, identifier: "tab"),
        49: KeyInfo(content: .symbol(name: "space", fallbackText: "Space"), isSpecialFunctionKey: true, identifier: "space"),
        51: KeyInfo(content: .symbol(name: "delete.left", fallbackText: "Delete"), isSpecialFunctionKey: true, identifier: "delete"),
        53: KeyInfo(content: .symbol(name: "escape", fallbackText: "Esc"), isSpecialFunctionKey: true, identifier: "esc"),
        117: KeyInfo(content: .symbol(name: "delete.forward", fallbackText: "Del"), isSpecialFunctionKey: true, identifier: "forward_delete"),

        // 方向键
        123: KeyInfo(content: .symbol(name: "arrow.left", fallbackText: "←"), isSpecialFunctionKey: true, identifier: "left_arrow"),
        124: KeyInfo(content: .symbol(name: "arrow.right", fallbackText: "→"), isSpecialFunctionKey: true, identifier: "right_arrow"),
        125: KeyInfo(content: .symbol(name: "arrow.down", fallbackText: "↓"), isSpecialFunctionKey: true, identifier: "down_arrow"),
        126: KeyInfo(content: .symbol(name: "arrow.up", fallbackText: "↑"), isSpecialFunctionKey: true, identifier: "up_arrow"),

        // 导航键
        115: KeyInfo(content: .symbol(name: "arrow.up.to.line", fallbackText: "Home"), isSpecialFunctionKey: true, identifier: "home"),
        119: KeyInfo(content: .symbol(name: "arrow.down.to.line", fallbackText: "End"), isSpecialFunctionKey: true, identifier: "end"),
        116: KeyInfo(content: .symbol(name: "pageup", fallbackText: "PgUp"), isSpecialFunctionKey: true, identifier: "page_up"),
        121: KeyInfo(content: .symbol(name: "pagedown", fallbackText: "PgDn"), isSpecialFunctionKey: true, identifier: "page_down"),

        // 功能键 F1 ~ F12
        122: KeyInfo(content: .text("F1"), isSpecialFunctionKey: true, identifier: "f1"),
        120: KeyInfo(content: .text("F2"), isSpecialFunctionKey: true, identifier: "f2"),
        99:  KeyInfo(content: .text("F3"), isSpecialFunctionKey: true, identifier: "f3"),
        118: KeyInfo(content: .text("F4"), isSpecialFunctionKey: true, identifier: "f4"),
        96:  KeyInfo(content: .text("F5"), isSpecialFunctionKey: true, identifier: "f5"),
        97:  KeyInfo(content: .text("F6"), isSpecialFunctionKey: true, identifier: "f6"),
        98:  KeyInfo(content: .text("F7"), isSpecialFunctionKey: true, identifier: "f7"),
        100: KeyInfo(content: .text("F8"), isSpecialFunctionKey: true, identifier: "f8"),
        101: KeyInfo(content: .text("F9"), isSpecialFunctionKey: true, identifier: "f9"),
        109: KeyInfo(content: .text("F10"), isSpecialFunctionKey: true, identifier: "f10"),
        103: KeyInfo(content: .text("F11"), isSpecialFunctionKey: true, identifier: "f11"),
        111: KeyInfo(content: .text("F12"), isSpecialFunctionKey: true, identifier: "f12"),

        // 多媒体控制
        72: KeyInfo(content: .symbol(name: "speaker.wave.3", fallbackText: "Vol+"), isSpecialFunctionKey: true, identifier: "vol_up"),
        73: KeyInfo(content: .symbol(name: "speaker.wave.1", fallbackText: "Vol-"), isSpecialFunctionKey: true, identifier: "vol_down"),
        74: KeyInfo(content: .symbol(name: "speaker.slash", fallbackText: "Mute"), isSpecialFunctionKey: true, identifier: "mute"),

        // 修饰键与锁定键
        55: KeyInfo(content: .symbol(name: "command", fallbackText: "⌘"), isSpecialFunctionKey: true, identifier: "command"),
        54: KeyInfo(content: .symbol(name: "command", fallbackText: "⌘"), isSpecialFunctionKey: true, identifier: "command"),
        58: KeyInfo(content: .symbol(name: "option", fallbackText: "⌥"), isSpecialFunctionKey: true, identifier: "option"),
        61: KeyInfo(content: .symbol(name: "option", fallbackText: "⌥"), isSpecialFunctionKey: true, identifier: "option"),
        59: KeyInfo(content: .symbol(name: "control", fallbackText: "⌃"), isSpecialFunctionKey: true, identifier: "control"),
        62: KeyInfo(content: .symbol(name: "control", fallbackText: "⌃"), isSpecialFunctionKey: true, identifier: "control"),
        56: KeyInfo(content: .symbol(name: "shift", fallbackText: "⇧"), isSpecialFunctionKey: true, identifier: "shift"),
        60: KeyInfo(content: .symbol(name: "shift", fallbackText: "⇧"), isSpecialFunctionKey: true, identifier: "shift"),
        57: KeyInfo(content: .symbol(name: "capslock", fallbackText: "⇪"), isSpecialFunctionKey: true, identifier: "caps_lock"),

        // FN / 地球仪键（63 为传统 Mac Fn 键，179 为现代 Mac 键盘 Globe/Fn 键）
        63: KeyInfo(content: .symbol(name: "globe", fallbackText: "Fn"), isSpecialFunctionKey: true, identifier: "fn"),
        179: KeyInfo(content: .symbol(name: "globe", fallbackText: "Fn"), isSpecialFunctionKey: true, identifier: "fn"),

        // 扩展功能键 F13 ~ F20
        105: KeyInfo(content: .text("F13"), isSpecialFunctionKey: true, identifier: "f13"),
        107: KeyInfo(content: .text("F14"), isSpecialFunctionKey: true, identifier: "f14"),
        113: KeyInfo(content: .text("F15"), isSpecialFunctionKey: true, identifier: "f15"),
        106: KeyInfo(content: .text("F16"), isSpecialFunctionKey: true, identifier: "f16"),
        64:  KeyInfo(content: .text("F17"), isSpecialFunctionKey: true, identifier: "f17"),
        79:  KeyInfo(content: .text("F18"), isSpecialFunctionKey: true, identifier: "f18"),
        80:  KeyInfo(content: .text("F19"), isSpecialFunctionKey: true, identifier: "f19"),
        90:  KeyInfo(content: .text("F20"), isSpecialFunctionKey: true, identifier: "f20"),

        // 辅助与小键盘按键
        71:  KeyInfo(content: .symbol(name: "clear", fallbackText: "Clear"), isSpecialFunctionKey: true, identifier: "clear"),
        76:  KeyInfo(content: .symbol(name: "return", fallbackText: "Enter"), isSpecialFunctionKey: true, identifier: "enter"),
        114: KeyInfo(content: .symbol(name: "questionmark.circle", fallbackText: "Help"), isSpecialFunctionKey: true, identifier: "help"),
    ]
}
