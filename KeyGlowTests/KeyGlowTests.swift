//
//  KeyGlowTests.swift
//  KeyGlowTests
//

import XCTest
@testable import KeyGlow

final class KeyGlowTests: XCTestCase {

    func testKeyModifierOrderingAndSymbols() {
        // macOS 官方修饰键排序：⌃ ⌥ ⇧ ⌘
        let mods: [KeyModifier] = [.command, .shift, .control, .option]
        let sorted = mods.sorted(by: { $0.sortOrder < $1.sortOrder })

        XCTAssertEqual(sorted, [.control, .option, .shift, .command])
        XCTAssertEqual(KeyModifier.command.sfSymbol, "command")
        XCTAssertEqual(KeyModifier.option.sfSymbol, "option")
        XCTAssertEqual(KeyModifier.control.sfSymbol, "control")
        XCTAssertEqual(KeyModifier.shift.sfSymbol, "shift")
    }

    func testKeyStrokeInitialization() {
        let stroke = KeyStroke(
            modifiers: [.command, .shift],
            content: .text("C"),
            rawIdentifier: "cmd+shift+c",
            isShortcut: true,
            isSpecialFunctionKey: false,
            repeatCount: 1
        )

        XCTAssertEqual(stroke.modifiers, [.shift, .command])
        XCTAssertEqual(stroke.content, .text("C"))
        XCTAssertEqual(stroke.rawIdentifier, "cmd+shift+c")
        XCTAssertTrue(stroke.isShortcut)
        XCTAssertFalse(stroke.isSpecialFunctionKey)
        XCTAssertEqual(stroke.repeatCount, 1)
    }

    func testKeycapStyles() {
        XCTAssertEqual(KeycapStyle.allCases.count, 3)
        XCTAssertEqual(KeycapStyle.classicDark.title, "经典深黑")
        XCTAssertEqual(KeycapStyle.frostedGlass.title, "磨砂亚克力")
        XCTAssertEqual(KeycapStyle.auroraGlow.title, "极光微光")
    }

    func testDisplayAnchors() {
        XCTAssertEqual(DisplayAnchor.allCases.count, 5)
        XCTAssertEqual(DisplayAnchor.bottomCenter.title, "屏幕底部居中")
        XCTAssertEqual(DisplayAnchor.bottomLeft.title, "屏幕左下角")
        XCTAssertEqual(DisplayAnchor.bottomRight.title, "屏幕右下角")
        XCTAssertEqual(DisplayAnchor.topCenter.title, "屏幕顶部居中")
        XCTAssertEqual(DisplayAnchor.mouseFollow.title, "跟随鼠标光标")
    }

    func testSpecialKeyColors() {
        XCTAssertEqual(SpecialKeyColor.allCases.count, 6)
        XCTAssertEqual(SpecialKeyColor.blue.title, "科技冰蓝")
        XCTAssertEqual(SpecialKeyColor.purple.title, "极光熏紫")
        XCTAssertEqual(SpecialKeyColor.orange.title, "日落暖橙")
        XCTAssertEqual(SpecialKeyColor.green.title, "霓虹翡翠")
        XCTAssertEqual(SpecialKeyColor.pink.title, "摩登浆果")
        XCTAssertEqual(SpecialKeyColor.monochrome.title, "素雅纯白")
    }

    func testDisplayModes() {
        XCTAssertEqual(DisplayMode.allCases.count, 2)
        XCTAssertEqual(DisplayMode.shortcutsOnly.title, "仅快捷键模式")
        XCTAssertEqual(DisplayMode.allKeys.title, "全按键模式")
    }

    // MARK: - 问题 3 修复测试：FN 功能键显示修复（不再显示 key_179，而是 globe 图标与 Fn）
    func testFnAndGlobeKeyMapping() {
        guard let dummyEvent = CGEvent(keyboardEventSource: nil, virtualKey: 179, keyDown: true) else {
            XCTFail("无法创建测试 CGEvent")
            return
        }

        // 现代 Mac 键盘 Globe / Fn 键码 179
        let info179 = KeyCodeMapper.map(event: dummyEvent, keyCode: 179)
        XCTAssertEqual(info179.content, .symbol(name: "globe", fallbackText: "Fn"))
        XCTAssertTrue(info179.isSpecialFunctionKey)
        XCTAssertEqual(info179.identifier, "fn")
        XCTAssertNotEqual(info179.content.displayText, "Key_179")

        // 传统 Mac 键盘 Function 键码 63
        let info63 = KeyCodeMapper.map(event: dummyEvent, keyCode: 63)
        XCTAssertEqual(info63.content, .symbol(name: "globe", fallbackText: "Fn"))
        XCTAssertTrue(info63.isSpecialFunctionKey)
        XCTAssertEqual(info63.identifier, "fn")
    }

    // MARK: - 问题 1 修复测试：单独点按 Command、Control、Option、Shift、CapsLock 映射
    func testModifierKeysDirectMapping() {
        guard let dummyEvent = CGEvent(keyboardEventSource: nil, virtualKey: 55, keyDown: true) else {
            XCTFail("无法创建测试 CGEvent")
            return
        }

        // Command (55, 54)
        let cmdLeft = KeyCodeMapper.map(event: dummyEvent, keyCode: 55)
        XCTAssertEqual(cmdLeft.content, .symbol(name: "command", fallbackText: "⌘"))
        XCTAssertTrue(cmdLeft.isSpecialFunctionKey)
        let cmdRight = KeyCodeMapper.map(event: dummyEvent, keyCode: 54)
        XCTAssertEqual(cmdRight.content, .symbol(name: "command", fallbackText: "⌘"))

        // Option (58, 61)
        let optLeft = KeyCodeMapper.map(event: dummyEvent, keyCode: 58)
        XCTAssertEqual(optLeft.content, .symbol(name: "option", fallbackText: "⌥"))
        XCTAssertTrue(optLeft.isSpecialFunctionKey)
        let optRight = KeyCodeMapper.map(event: dummyEvent, keyCode: 61)
        XCTAssertEqual(optRight.content, .symbol(name: "option", fallbackText: "⌥"))

        // Control (59, 62)
        let ctrlLeft = KeyCodeMapper.map(event: dummyEvent, keyCode: 59)
        XCTAssertEqual(ctrlLeft.content, .symbol(name: "control", fallbackText: "⌃"))
        XCTAssertTrue(ctrlLeft.isSpecialFunctionKey)
        let ctrlRight = KeyCodeMapper.map(event: dummyEvent, keyCode: 62)
        XCTAssertEqual(ctrlRight.content, .symbol(name: "control", fallbackText: "⌃"))

        // Shift (56, 60)
        let shiftLeft = KeyCodeMapper.map(event: dummyEvent, keyCode: 56)
        XCTAssertEqual(shiftLeft.content, .symbol(name: "shift", fallbackText: "⇧"))
        XCTAssertTrue(shiftLeft.isSpecialFunctionKey)
        let shiftRight = KeyCodeMapper.map(event: dummyEvent, keyCode: 60)
        XCTAssertEqual(shiftRight.content, .symbol(name: "shift", fallbackText: "⇧"))

        // CapsLock (57)
        let caps = KeyCodeMapper.map(event: dummyEvent, keyCode: 57)
        XCTAssertEqual(caps.content, .symbol(name: "capslock", fallbackText: "⇪"))
        XCTAssertTrue(caps.isSpecialFunctionKey)
    }

    // MARK: - 扩展功能键映射测试（F13 ~ F20, Keypad Enter 等）
    func testExtendedFunctionKeysMapping() {
        guard let dummyEvent = CGEvent(keyboardEventSource: nil, virtualKey: 105, keyDown: true) else {
            XCTFail("无法创建测试 CGEvent")
            return
        }

        let f13 = KeyCodeMapper.map(event: dummyEvent, keyCode: 105)
        XCTAssertEqual(f13.content, .text("F13"))
        XCTAssertTrue(f13.isSpecialFunctionKey)

        let f20 = KeyCodeMapper.map(event: dummyEvent, keyCode: 90)
        XCTAssertEqual(f20.content, .text("F20"))
        XCTAssertTrue(f20.isSpecialFunctionKey)

        let keypadEnter = KeyCodeMapper.map(event: dummyEvent, keyCode: 76)
        XCTAssertEqual(keypadEnter.content, .symbol(name: "return", fallbackText: "Enter"))
        XCTAssertTrue(keypadEnter.isSpecialFunctionKey)
    }

    // MARK: - 问题 1 & 2 修复测试：单按修饰键、修饰键连按叠加与就地升级
    @MainActor
    func testModifierOnlyStrokesAndChaining() {
        let monitor = KeyMonitor.shared
        monitor.clearStroke()

        // 1. 单独点按 Command
        let cmdStroke = KeyStroke(
            modifiers: [],
            content: .symbol(name: "command", fallbackText: "⌘"),
            rawIdentifier: "command",
            isShortcut: true,
            isSpecialFunctionKey: true,
            isModifierOnly: true
        )
        monitor.simulateKeyStroke(cmdStroke)

        XCTAssertEqual(monitor.activeStrokes.count, 1)
        XCTAssertEqual(monitor.activeStrokes.last?.content, .symbol(name: "command", fallbackText: "⌘"))
        XCTAssertTrue(monitor.activeStrokes.last?.isModifierOnly ?? false)

        // 2. 在 Command 未松开的情况下连按 Option（这几个按键连着一起按）-> 就地升级为 ⌥ ⌘
        let optCmdStroke = KeyStroke(
            modifiers: [.option],
            content: .symbol(name: "command", fallbackText: "⌘"),
            rawIdentifier: "option+command",
            isShortcut: true,
            isSpecialFunctionKey: true,
            isModifierOnly: true
        )
        monitor.simulateKeyStroke(optCmdStroke)

        // 应当就地替换，依然保持 1 个卡片，内容升级为带 Option 修饰的 Command
        XCTAssertEqual(monitor.activeStrokes.count, 1)
        XCTAssertEqual(monitor.activeStrokes.last?.modifiers, [.option])
        XCTAssertEqual(monitor.activeStrokes.last?.content, .symbol(name: "command", fallbackText: "⌘"))

        // 3. 在 ⌥ ⌘ 未松开的情况下按字母 C（组合快捷键）-> 就地升级为 ⌥ ⌘ C
        let fullShortcut = KeyStroke(
            modifiers: [.option, .command],
            content: .text("C"),
            rawIdentifier: "option+command+c",
            isShortcut: true,
            isSpecialFunctionKey: false,
            isModifierOnly: false
        )
        monitor.simulateKeyStroke(fullShortcut)

        XCTAssertEqual(monitor.activeStrokes.count, 1)
        XCTAssertEqual(monitor.activeStrokes.last?.modifiers, [.option, .command])
        XCTAssertEqual(monitor.activeStrokes.last?.content, .text("C"))
        XCTAssertFalse(monitor.activeStrokes.last?.isModifierOnly ?? true)

        // 4. 用户释放所有修饰键
        monitor.simulateModifierRelease()

        // 5. 释放后用户单独点按 Control -> 作为新的按键卡片追加（队列长度变为 2）
        let ctrlStroke = KeyStroke(
            modifiers: [],
            content: .symbol(name: "control", fallbackText: "⌃"),
            rawIdentifier: "control",
            isShortcut: true,
            isSpecialFunctionKey: true,
            isModifierOnly: true
        )
        monitor.simulateKeyStroke(ctrlStroke)

        XCTAssertEqual(monitor.activeStrokes.count, 2)
        XCTAssertEqual(monitor.activeStrokes.last?.content, .symbol(name: "control", fallbackText: "⌃"))

        // 清理现场
        monitor.clearStroke()
    }
}
