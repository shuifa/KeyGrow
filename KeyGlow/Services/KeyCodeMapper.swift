//
//  KeyCodeMapper.swift
//  KeyGlow
//
//  虚拟键码 → 键帽图例。
//
//  0.100 起图例不再是「符号或文字二选一」，而是 `KeyLegend`：
//  符号（右上）+ 标签（右下）+ 宽度倍数（原版键帽宽度按真实键盘比例，
//  command ≈ 1.5u、escape ≈ 1.25u、caps lock ≈ 2u）。
//

import Carbon
import CoreGraphics
import Foundation

/// macOS 虚拟按键码到键帽图例的精准映射
public struct KeyCodeMapper {

    public struct KeyInfo: Sendable {
        public let legend: KeyLegend
        /// 是否为非字符键（决定该按键单按时是否上台面）
        public let isSpecialKey: Bool
        /// 稳定标识（连按合并 / 就地升级 / 色槽判定都依赖它）
        public let identifier: String
    }

    /// 根据按键事件和键码解析键帽图例
    public static func map(event: CGEvent, keyCode: CGKeyCode) -> KeyInfo {
        // 1. 系统特殊键优先（功能键、编辑键、方向键、修饰键、小键盘）
        if let special = specialKeyMap[keyCode] {
            return special
        }

        let flags = event.flags
        let hasShortcutModifier = flags.contains(.maskControl)
            || flags.contains(.maskAlternate)
            || flags.contains(.maskCommand)

        // 2. 含 ⌃ / ⌥ / ⌘ 的组合：走 Carbon TIS 取「基础字符」，
        //    避免 Control 产生控制字符、Option 产生死键变音符（⌥E 会输出 ´）
        if hasShortcutModifier {
            if let base = translateWithCarbonTIS(keyCode: keyCode) ?? ansiKeyMap[keyCode] {
                // 快捷键按 macOS 菜单惯例统一大写（⌘C 而非 ⌘c）
                let text = base.uppercased()
                return KeyInfo(
                    legend: KeyLegend(text: text),
                    isSpecialKey: false,
                    identifier: text.lowercased()
                )
            }
        }

        // 3. 普通字符：直接读事件里的 Unicode（保留用户实际输入的大小写）
        if let display = unicodeFromEvent(event) {
            return KeyInfo(
                legend: KeyLegend(text: display),
                isSpecialKey: false,
                identifier: display.lowercased()
            )
        }

        // 4. 死键 / 未捕获组合：用 Carbon TIS 与 ANSI 表补救
        if let display = translateWithCarbonTIS(keyCode: keyCode) ?? ansiKeyMap[keyCode] {
            let text = hasShortcutModifier ? display.uppercased() : display
            return KeyInfo(
                legend: KeyLegend(text: text),
                isSpecialKey: false,
                identifier: text.lowercased()
            )
        }

        // 5. 最终兜底（不可识别的键码：既非特殊键也无字符，不上台面）
        let fallback = "key_\(keyCode)"
        return KeyInfo(
            legend: KeyLegend(text: fallback),
            isSpecialKey: false,
            identifier: fallback
        )
    }

    /// 从事件里读取可打印字符（过滤控制字符）
    private static func unicodeFromEvent(_ event: CGEvent) -> String? {
        var length: Int = 0
        event.keyboardGetUnicodeString(maxStringLength: 0, actualStringLength: &length, unicodeString: nil)
        guard length > 0 else { return nil }

        var buffer = [UniChar](repeating: 0, count: length)
        event.keyboardGetUnicodeString(maxStringLength: length, actualStringLength: &length, unicodeString: &buffer)
        let raw = String(utf16CodeUnits: buffer, count: length)
        let trimmed = raw.trimmingCharacters(in: .controlCharacters)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 使用 Carbon TIS 键盘布局把虚拟键码转成基础字符（无修饰、无死键状态）
    private static func translateWithCarbonTIS(keyCode: CGKeyCode) -> String? {
        // 优先取 ASCII 能力布局：拼音等非拉丁输入法下也能拿到英文键位，避免标点变全角
        guard let inputSource = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue()
            ?? TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return nil
        }

        guard let layoutDataPtr = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let layoutData = unsafeBitCast(layoutDataPtr, to: CFData.self)
        guard let layout = CFDataGetBytePtr(layoutData) else { return nil }

        var deadKeyState: UInt32 = 0
        var length: Int = 0
        var chars = [UniChar](repeating: 0, count: 4)

        let result = layout.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { layoutPtr in
            UCKeyTranslate(
                layoutPtr,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                4,
                &length,
                &chars
            )
        }

        if result == noErr, length > 0 {
            let str = String(utf16CodeUnits: chars, count: length).trimmingCharacters(in: .controlCharacters)
            if !str.isEmpty { return str }
        }

        return nil
    }

    // MARK: - 标准 ANSI 虚拟键码备用映射表

    private static let ansiKeyMap: [CGKeyCode: String] = [
        // 字母 A ~ Z
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
        38: "J", 40: "K", 45: "N", 46: "M",

        // 数字 0 ~ 9
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7",
        28: "8", 25: "9", 29: "0",

        // 标点
        27: "-", 24: "=", 33: "[", 30: "]", 42: "\\", 41: ";", 39: "'",
        43: ",", 47: ".", 44: "/", 50: "`",

        // 小键盘
        65: ".", 67: "*", 69: "+", 75: "/", 78: "-", 81: "=",
        82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5",
        88: "6", 89: "7", 91: "8", 92: "9"
    ]

    // MARK: - 特殊键映射表
    //
    // 排版约定（与原版一致）：
    //   - 命名键给「符号 + 小写标签」，宽度按真实键盘比例（1.25u ~ 2u）；
    //   - 方向键只有符号，居中放大；
    //   - F1~F12 没有同义符号，退回居中文字。

    private static let specialKeyMap: [CGKeyCode: KeyInfo] = [
        // 编辑与换行
        36: KeyInfo(legend: KeyLegend(symbol: "return", text: "return", widthUnits: 1.75), isSpecialKey: true, identifier: "return"),
        76: KeyInfo(legend: KeyLegend(symbol: "return", text: "enter", widthUnits: 1.75), isSpecialKey: true, identifier: "enter"),
        48: KeyInfo(legend: KeyLegend(symbol: "arrow.right.to.line", text: "tab", widthUnits: 1.25), isSpecialKey: true, identifier: "tab"),
        49: KeyInfo(legend: KeyLegend(symbol: "space", text: "space", widthUnits: 2.0), isSpecialKey: true, identifier: "space"),
        51: KeyInfo(legend: KeyLegend(symbol: "delete.left", text: "delete", widthUnits: 1.75), isSpecialKey: true, identifier: "delete"),
        53: KeyInfo(legend: KeyLegend(symbol: "escape", text: "escape", widthUnits: 1.25), isSpecialKey: true, identifier: "esc"),
        117: KeyInfo(legend: KeyLegend(symbol: "delete.right", text: "delete", widthUnits: 1.75), isSpecialKey: true, identifier: "forward_delete"),

        // 方向键（只有符号，居中放大）
        123: KeyInfo(legend: KeyLegend(symbol: "arrow.left"), isSpecialKey: true, identifier: "left_arrow"),
        124: KeyInfo(legend: KeyLegend(symbol: "arrow.right"), isSpecialKey: true, identifier: "right_arrow"),
        125: KeyInfo(legend: KeyLegend(symbol: "arrow.down"), isSpecialKey: true, identifier: "down_arrow"),
        126: KeyInfo(legend: KeyLegend(symbol: "arrow.up"), isSpecialKey: true, identifier: "up_arrow"),

        // 导航键
        115: KeyInfo(legend: KeyLegend(symbol: "arrow.up.to.line", text: "home", widthUnits: 1.25), isSpecialKey: true, identifier: "home"),
        119: KeyInfo(legend: KeyLegend(symbol: "arrow.down.to.line", text: "end", widthUnits: 1.25), isSpecialKey: true, identifier: "end"),
        116: KeyInfo(legend: KeyLegend(text: "page up", widthUnits: 1.5), isSpecialKey: true, identifier: "page_up"),
        121: KeyInfo(legend: KeyLegend(text: "page down", widthUnits: 1.5), isSpecialKey: true, identifier: "page_down"),

        // 功能键 F1 ~ F12
        122: KeyInfo(legend: KeyLegend(text: "f1"), isSpecialKey: true, identifier: "f1"),
        120: KeyInfo(legend: KeyLegend(text: "f2"), isSpecialKey: true, identifier: "f2"),
        99: KeyInfo(legend: KeyLegend(text: "f3"), isSpecialKey: true, identifier: "f3"),
        118: KeyInfo(legend: KeyLegend(text: "f4"), isSpecialKey: true, identifier: "f4"),
        96: KeyInfo(legend: KeyLegend(text: "f5"), isSpecialKey: true, identifier: "f5"),
        97: KeyInfo(legend: KeyLegend(text: "f6"), isSpecialKey: true, identifier: "f6"),
        98: KeyInfo(legend: KeyLegend(text: "f7"), isSpecialKey: true, identifier: "f7"),
        100: KeyInfo(legend: KeyLegend(text: "f8"), isSpecialKey: true, identifier: "f8"),
        101: KeyInfo(legend: KeyLegend(text: "f9"), isSpecialKey: true, identifier: "f9"),
        109: KeyInfo(legend: KeyLegend(text: "f10"), isSpecialKey: true, identifier: "f10"),
        103: KeyInfo(legend: KeyLegend(text: "f11"), isSpecialKey: true, identifier: "f11"),
        111: KeyInfo(legend: KeyLegend(text: "f12"), isSpecialKey: true, identifier: "f12"),

        // 修饰键与锁定键（flagsChanged 路径通常自行构造，这里保留以覆盖直接 keyDown 的场景）
        55: KeyInfo(legend: KeyModifier.command.legend, isSpecialKey: true, identifier: "command"),
        54: KeyInfo(legend: KeyModifier.command.legend, isSpecialKey: true, identifier: "command"),
        58: KeyInfo(legend: KeyModifier.option.legend, isSpecialKey: true, identifier: "option"),
        61: KeyInfo(legend: KeyModifier.option.legend, isSpecialKey: true, identifier: "option"),
        59: KeyInfo(legend: KeyModifier.control.legend, isSpecialKey: true, identifier: "control"),
        62: KeyInfo(legend: KeyModifier.control.legend, isSpecialKey: true, identifier: "control"),
        56: KeyInfo(legend: KeyModifier.shift.legend, isSpecialKey: true, identifier: "shift"),
        60: KeyInfo(legend: KeyModifier.shift.legend, isSpecialKey: true, identifier: "shift"),
        57: KeyInfo(legend: KeyLegend(symbol: "capslock", text: "caps lock", widthUnits: 1.75), isSpecialKey: true, identifier: "caps_lock"),

        // FN / 地球仪键（63 为传统 Mac Fn，179 为现代 Globe/Fn）
        63: KeyInfo(legend: KeyLegend(symbol: "globe", text: "fn", widthUnits: 1.5), isSpecialKey: true, identifier: "fn"),
        179: KeyInfo(legend: KeyLegend(symbol: "globe", text: "fn", widthUnits: 1.5), isSpecialKey: true, identifier: "fn"),

        // 扩展功能键 F13 ~ F20（外接键盘）
        105: KeyInfo(legend: KeyLegend(text: "f13"), isSpecialKey: true, identifier: "f13"),
        107: KeyInfo(legend: KeyLegend(text: "f14"), isSpecialKey: true, identifier: "f14"),
        113: KeyInfo(legend: KeyLegend(text: "f15"), isSpecialKey: true, identifier: "f15"),
        106: KeyInfo(legend: KeyLegend(text: "f16"), isSpecialKey: true, identifier: "f16"),
        64: KeyInfo(legend: KeyLegend(text: "f17"), isSpecialKey: true, identifier: "f17"),
        79: KeyInfo(legend: KeyLegend(text: "f18"), isSpecialKey: true, identifier: "f18"),
        80: KeyInfo(legend: KeyLegend(text: "f19"), isSpecialKey: true, identifier: "f19"),
        90: KeyInfo(legend: KeyLegend(text: "f20"), isSpecialKey: true, identifier: "f20"),

        // 辅助键
        71: KeyInfo(legend: KeyLegend(text: "clear", widthUnits: 1.25), isSpecialKey: true, identifier: "clear"),
        114: KeyInfo(legend: KeyLegend(text: "help", widthUnits: 1.25), isSpecialKey: true, identifier: "help")
    ]
}
