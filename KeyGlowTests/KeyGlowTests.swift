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
}
