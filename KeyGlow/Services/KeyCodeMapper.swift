//
//  KeyCodeMapper.swift
//  KeyGlow
//

import Carbon
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
        // 1. 优先匹配系统特殊按键（方向键、功能键、编辑键、修饰键）
        if let special = specialKeyMap[keyCode] {
            return special
        }

        let flags = event.flags
        let isShortcutModifierActive = flags.contains(.maskControl) || flags.contains(.maskAlternate) || flags.contains(.maskCommand)

        // 2. 若当前按下修饰键（Control / Option / Command），说明处于快捷键组合中，
        // 优先通过 Carbon TIS 解析其物理/ASCII 基础字符（避免 Control 产生控制字符或 Option 产生死键/变音符），
        // 从而正确展示如 ⌃C、⌥A、⌥E 等快捷键，而非 Key_0 或 Key_14。
        if isShortcutModifierActive {
            if let display = translateWithCarbonTIS(keyCode: keyCode) ?? ansiKeyMap[keyCode] {
                return KeyInfo(
                    content: .text(display),
                    isSpecialFunctionKey: false,
                    identifier: display.lowercased()
                )
            }
        }

        // 3. 尝试从 CGEvent 读取真实的 Unicode 字符（适合正常打字、输入法输入与 Shift 大写输入）
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

        // 4. 若 CGEvent 未能解析出有效字符（如死键、未捕获的修饰组合等），使用 Carbon TIS 与 ANSI 表补救
        if let display = translateWithCarbonTIS(keyCode: keyCode) ?? ansiKeyMap[keyCode] {
            return KeyInfo(
                content: .text(display),
                isSpecialFunctionKey: false,
                identifier: display.lowercased()
            )
        }

        // 5. 最终 Fallback 到通用键码描述
        let fallback = "Key_\(keyCode)"
        return KeyInfo(
            content: .text(fallback),
            isSpecialFunctionKey: false,
            identifier: fallback.lowercased()
        )
    }

    /// 使用 Carbon TIS 键盘布局将虚拟键码转换为基础字符（无修饰、无死键状态）
    private static func translateWithCarbonTIS(keyCode: CGKeyCode) -> String? {
        // 优先使用当前支持 ASCII 的键盘布局（例如在拼音或非拉丁输入法下获取对应的英文键盘布局，避免标点符号变成全角符号）
        guard let inputSource = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue() ??
                                TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return nil
        }

        guard let layoutDataPtr = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let layoutData = unsafeBitCast(layoutDataPtr, to: CFData.self)
        guard let layout = CFDataGetBytePtr(layoutData) else {
            return nil
        }

        var deadKeyState: UInt32 = 0
        var length: Int = 0
        var chars = [UniChar](repeating: 0, count: 4)

        let result = layout.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { layoutPtr in
            UCKeyTranslate(
                layoutPtr,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0, // 无修饰键状态，提取基础按键字符
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit), // 忽略死键状态
                &deadKeyState,
                4,
                &length,
                &chars
            )
        }

        if result == noErr && length > 0 {
            let str = String(utf16CodeUnits: chars, count: length).trimmingCharacters(in: .controlCharacters)
            if !str.isEmpty {
                return str.uppercased()
            }
        }

        return nil
    }

    // MARK: - 标准 ANSI 虚拟键码备用映射表 (兜底保证无 TIS 布局时仍能正确解析)

    private static let ansiKeyMap: [CGKeyCode: String] = [
        // 字母按键 A ~ Z
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
        38: "J", 40: "K", 45: "N", 46: "M",

        // 数字按键 0 ~ 9
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7",
        28: "8", 25: "9", 29: "0",

        // 标点符号
        27: "-", 24: "=", 33: "[", 30: "]", 42: "\\", 41: ";", 39: "'",
        43: ",", 47: ".", 44: "/", 50: "`",

        // 小键盘按键
        65: ".", 67: "*", 69: "+", 75: "/", 78: "-", 81: "=",
        82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5",
        88: "6", 89: "7", 91: "8", 92: "9"
    ]

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
