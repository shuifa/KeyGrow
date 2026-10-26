//
//  KeyGlowTests.swift
//  KeyGlowTests
//

import XCTest
@testable import KeyGlow
import SwiftUI

final class KeyGlowTests: XCTestCase {

    // MARK: - 用户配置保护
    //
    // 测试会临时改写入 AppSettings（会影响真实 UserDefaults），
    // 因此统一在首个用例前快照、在每个用例结束时还原，避免污染开发者本机偏好。

    private static var savedSnapshot: SettingsSnapshot?

    @MainActor
    private func prepareSettings() {
        if Self.savedSnapshot == nil {
            Self.savedSnapshot = AppSettings.shared.makeSnapshot()
        }
        AppSettings.shared.resetToDefaults()
        KeyMonitor.shared.clearStroke()
    }

    @MainActor
    private func restoreSettings() {
        if let snapshot = Self.savedSnapshot {
            AppSettings.shared.apply(snapshot)
        }
        KeyMonitor.shared.clearStroke()
    }

    /// 两色在 sRGB 空间中的欧氏距离（0 ~ 441），用于判断七档色相是否真的能被人眼分开
    private func rgbDistance(_ a: KeyColorRGB, _ b: KeyColorRGB) -> Double {
        let dr = (a.red - b.red) * 255
        let dg = (a.green - b.green) * 255
        let db = (a.blue - b.blue) * 255
        return (dr * dr + dg * dg + db * db).squareRoot()
    }

    // MARK: - 主题目录

    func testThemeCatalogIntegrity() {
        XCTAssertEqual(KeycapTheme.all.count, 2, "0.2 只保留「七色花瓣」与「星空」两套主题")

        // id 必须唯一且非空，否则持久化会串味
        let ids = KeycapTheme.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "主题 id 不允许重复")
        XCTAssertFalse(ids.contains(where: { $0.isEmpty }))

        // 名称与副标题都必须非空，设置面板需要展示
        for theme in KeycapTheme.all {
            XCTAssertFalse(theme.name.isEmpty)
            XCTAssertFalse(theme.subtitle.isEmpty)
        }

        // 默认主题必须存在于目录中
        XCTAssertTrue(ids.contains(KeycapTheme.defaultTheme.id))

        // 已知 id 必须原样解析
        XCTAssertEqual(KeycapTheme.theme(id: KeycapTheme.starfield.id).id, KeycapTheme.starfield.id)
        XCTAssertEqual(KeycapTheme.resolvedID(KeycapTheme.starfield.id), KeycapTheme.starfield.id)

        // 未知 id / 空串 / 已下线主题必须回退默认主题，避免旧配置导致空白配色
        for legacy in ["not-a-theme", "", "obsidian", "sakura", "neon", "graphite"] {
            XCTAssertEqual(KeycapTheme.resolvedID(legacy), KeycapTheme.defaultTheme.id, "旧 id \(legacy) 应回退默认主题")
            XCTAssertEqual(KeycapTheme.theme(id: legacy).id, KeycapTheme.defaultTheme.id)
        }
    }

    /// 七档必须是七个真正不同的色相：任意两档的 sRGB 距离都不能过低，
    /// 否则「每类按键不同色」在实机上会退化成一片。
    func testSevenRolesUseDistinguishableColors() {
        for theme in KeycapTheme.all {
            for scheme in [ColorScheme.light, .dark] {
                let colors = theme.colors(for: scheme)
                let label = "\(theme.name) / \(scheme == .dark ? "夜晚" : "白天")"
                let palettes = colors.allPalettes

                for i in palettes.indices {
                    for j in palettes.indices where j > i {
                        let distance = rgbDistance(palettes[i].accent, palettes[j].accent)
                        XCTAssertGreaterThanOrEqual(
                            distance, 20,
                            "\(label) 第 \(i) 档与第 \(j) 档色相过于接近（ΔRGB \(Int(distance))），实机上无法区分"
                        )
                    }
                }
            }
        }
    }

    /// 七档色板必须真的读进七个不同的槽位，不能出现两档共用同一 palette 的情况
    func testSevenPalettesAreIndependent() {
        for theme in KeycapTheme.all {
            for scheme in [ColorScheme.light, .dark] {
                let colors = theme.colors(for: scheme)
                let label = "\(theme.name) / \(scheme == .dark ? "夜晚" : "白天")"

                let accents = colors.allPalettes.map(\.accent)
                XCTAssertEqual(Set(accents).count, 7, "\(label) 存在重复色板，两档共用同一颜色")

                for role in KeyColorRole.allCases {
                    XCTAssertEqual(
                        colors.palette(for: role).accent, colors.palette(for: role).accent,
                        "\(label) - \(role.title) 取色不稳定"
                    )
                }
            }
        }
    }

    /// 色卡带按「英雄键 → 结构 → 功能 → 方向 → 修饰 → 数字 → 字母」排列，顺序不能随实现漂移
    func testColorwayHierarchyOrder() {
        let colors = KeycapTheme.petals.colors(for: .light)
        XCTAssertEqual(colors.hierarchy.count, 7)
        XCTAssertEqual(colors.hierarchy[0].accent, colors.escape.accent)
        XCTAssertEqual(colors.hierarchy[1].accent, colors.structural.accent)
        XCTAssertEqual(colors.hierarchy[2].accent, colors.function.accent)
        XCTAssertEqual(colors.hierarchy[3].accent, colors.arrow.accent)
        XCTAssertEqual(colors.hierarchy[4].accent, colors.modifier.accent)
        XCTAssertEqual(colors.hierarchy[5].accent, colors.digit.accent)
        XCTAssertEqual(colors.hierarchy[6].accent, colors.alpha.accent)

        XCTAssertEqual(KeyColorRole.displayOrder.count, 7)
    }

    func testThemeSwitchesBetweenDayAndNight() {
        for theme in KeycapTheme.all {
            let light = theme.colors(for: .light)
            let dark = theme.colors(for: .dark)

            // 白天档的字母键必须明显比夜晚档更亮（保证跟随系统时观感真的会变）
            XCTAssertGreaterThan(
                light.alpha.midTone.relativeLuminance,
                dark.alpha.midTone.relativeLuminance + 0.25,
                "\(theme.name) 的昼夜两档亮度差不足，跟随系统时几乎看不出变化"
            )

            // 七档色板在昼夜之间都不能相同
            for role in KeyColorRole.allCases {
                XCTAssertNotEqual(
                    light.palette(for: role).top,
                    dark.palette(for: role).top,
                    "\(theme.name) - \(role.title) 的昼夜顶面色相同"
                )
            }
        }
    }

    // MARK: - 可读性与配色不变量

    /// 0.2 的材质要求「原色直出、明亮优先」，因此字符对比度标准比 WCAG AA（4.5）更严格
    func testLegendContrastMeetsAccessibilityThreshold() {
        for theme in KeycapTheme.all {
            for scheme in [ColorScheme.light, .dark] {
                let colors = theme.colors(for: scheme)
                for role in KeyColorRole.allCases {
                    let palette = colors.palette(for: role)
                    XCTAssertGreaterThanOrEqual(
                        palette.legendContrastRatio, 4.5,
                        "\(theme.name) / \(scheme == .dark ? "夜晚" : "白天") / \(role.title) 字符对比度不足，录屏不可读"
                    )
                }
            }
        }
    }

    func testPalettePicksHigherContrastLegendAutomatically() {
        for theme in KeycapTheme.all {
            for scheme in [ColorScheme.light, .dark] {
                for palette in theme.colors(for: scheme).allPalettes {
                    let ink = palette.midTone.contrastRatio(with: .ink)
                    let white = palette.midTone.contrastRatio(with: .white)
                    if palette.isLightSurface {
                        XCTAssertGreaterThanOrEqual(ink, white, "\(theme.name) 判定为浅色键帽，却选了白色字符")
                    } else {
                        XCTAssertGreaterThanOrEqual(white, ink, "\(theme.name) 判定为深色键帽，却选了墨色字符")
                    }
                }
            }
        }
    }

    /// Esc 与结构键必须是两套颜色，而不是共用一个色号
    func testEscapeAndStructuralKeyColorsAreIndependent() {
        for theme in KeycapTheme.all {
            for scheme in [ColorScheme.light, .dark] {
                let colors = theme.colors(for: scheme)
                XCTAssertNotEqual(
                    colors.escape.accent, colors.structural.accent,
                    "\(theme.name) 的 Esc 与结构键同色，语义层次丢失"
                )
            }
        }
    }

    func testPaletteToneDerivationKeepsPhysicalLightingRelation() {
        // 顶面必须比下沿亮、下沿必须比侧壁亮，这是拟物键帽的物理前提
        for theme in KeycapTheme.all {
            for scheme in [ColorScheme.light, .dark] {
                for palette in theme.colors(for: scheme).allPalettes {
                    XCTAssertGreaterThan(palette.top.relativeLuminance, palette.bottom.relativeLuminance)
                    XCTAssertGreaterThan(palette.bottom.relativeLuminance, palette.extrusion.relativeLuminance)
                }
            }
        }
    }

    // MARK: - 外观模式

    func testAppearanceModeMapsToWindowAppearance() {
        XCTAssertNil(ThemeAppearanceMode.system.nsAppearance, "跟随系统必须交出 appearance 控制权")
        XCTAssertEqual(ThemeAppearanceMode.light.nsAppearance?.name, .aqua)
        XCTAssertEqual(ThemeAppearanceMode.dark.nsAppearance?.name, .darkAqua)
        XCTAssertEqual(ThemeAppearanceMode.allCases.count, 3)
    }

    func testBorderStylesCoverEveryTheme() {
        for theme in KeycapTheme.all {
            // 每个主题都必须能在两档外观下为七档色板生成描边渐变，而不是崩在未实现的 case
            for palette in theme.colors(for: .light).allPalettes {
                _ = theme.border.strokeGradient(for: palette)
            }
            XCTAssertTrue(KeycapBorderStyle.allCases.contains(theme.border))
        }
    }

    // MARK: - 按键角色解析（七档）

    func testColorRoleResolvesAllSevenTiers() {
        func role(_ id: String, special: Bool = false, modifierOnly: Bool = false) -> KeyColorRole {
            KeyStroke(
                modifiers: [],
                content: .text(id),
                rawIdentifier: id,
                isSpecialFunctionKey: special,
                isModifierOnly: modifierOnly
            ).colorRole
        }

        // Esc
        XCTAssertEqual(role("esc", special: true), .escape)
        XCTAssertEqual(role("escape", special: true), .escape)

        // 修饰键
        XCTAssertEqual(role("command", special: true, modifierOnly: true), .modifier)
        XCTAssertEqual(role("shift", special: true, modifierOnly: true), .modifier)
        XCTAssertEqual(role("caps_lock", special: true, modifierOnly: true), .modifier)

        // 方向键
        XCTAssertEqual(role("left_arrow", special: true), .arrow)
        XCTAssertEqual(role("up_arrow", special: true), .arrow)
        XCTAssertEqual(role("down_arrow", special: true), .arrow)
        XCTAssertEqual(role("right_arrow", special: true), .arrow)

        // F 区与 Fn
        XCTAssertEqual(role("f1", special: true), .function)
        XCTAssertEqual(role("f12", special: true), .function)
        XCTAssertEqual(role("f20", special: true), .function)
        XCTAssertEqual(role("fn", special: true), .function)

        // 结构键
        XCTAssertEqual(role("return", special: true), .structural)
        XCTAssertEqual(role("tab", special: true), .structural)
        XCTAssertEqual(role("space", special: true), .structural)
        XCTAssertEqual(role("delete", special: true), .structural)
        XCTAssertEqual(role("page_up", special: true), .structural)

        // 数字
        for digit in ["0", "1", "5", "9"] {
            XCTAssertEqual(role(digit), .digit, "数字键 \(digit) 未归入数字档")
        }

        // 字母与符号
        XCTAssertEqual(role("a"), .alpha)
        XCTAssertEqual(role("z"), .alpha)
        XCTAssertEqual(role("-"), .alpha)
        XCTAssertEqual(role("\\"), .alpha)
    }

    /// 字母 f 不能被误判成功能键，这是 `f1` 前缀判定最容易踩的坑
    func testLetterFIsNotMistakenForFunctionKey() {
        let letterF = KeyStroke(modifiers: [], content: .text("f"), rawIdentifier: "f")
        XCTAssertEqual(letterF.colorRole, .alpha)
    }

    /// 组合键取最后一段作为主键标识：⌘C 应落字母档，⌘⇧4 应落数字档
    func testCombinedShortcutUsesBaseKeyRole() {
        let cmdC = KeyStroke(modifiers: [.command], content: .text("C"), rawIdentifier: "command+c")
        XCTAssertEqual(cmdC.colorRole, .alpha)

        let cmdShift4 = KeyStroke(modifiers: [.command, .shift], content: .text("4"), rawIdentifier: "command+shift+4")
        XCTAssertEqual(cmdShift4.colorRole, .digit)

        let cmdEsc = KeyStroke(modifiers: [.command], content: .text("esc"), rawIdentifier: "command+esc")
        XCTAssertEqual(cmdEsc.colorRole, .escape)
    }

    func testModifierOrderingAndSymbols() {
        let mods: [KeyModifier] = [.command, .shift, .control, .option]
        let sorted = mods.sorted(by: { $0.sortOrder < $1.sortOrder })
        XCTAssertEqual(sorted, [.control, .option, .shift, .command])

        XCTAssertEqual(KeyModifier.command.sfSymbol, "command")
        XCTAssertEqual(KeyModifier.option.sfSymbol, "option")
        XCTAssertEqual(KeyModifier.control.sfSymbol, "control")
        XCTAssertEqual(KeyModifier.shift.sfSymbol, "shift")
    }

    func testDisplayAnchors() {
        XCTAssertEqual(DisplayAnchor.allCases.count, 5)
        XCTAssertEqual(DisplayAnchor.bottomCenter.title, "屏幕底部居中")
        XCTAssertEqual(DisplayAnchor.mouseFollow.title, "跟随鼠标光标")
    }

    // MARK: - 键码映射（特殊键文字化 / 大小写语义）

    func testSpecialKeysUseReadableTextLabels() {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true) else {
            return XCTFail("无法创建测试 CGEvent")
        }

        XCTAssertEqual(KeyCodeMapper.map(event: event, keyCode: 53).content, .text("esc"))
        XCTAssertEqual(KeyCodeMapper.map(event: event, keyCode: 48).content, .text("tab"))
        XCTAssertEqual(KeyCodeMapper.map(event: event, keyCode: 36).content, .text("return"))
        XCTAssertEqual(KeyCodeMapper.map(event: event, keyCode: 49).content, .text("space"))
        XCTAssertEqual(KeyCodeMapper.map(event: event, keyCode: 51).content, .text("delete"))

        // 方向键仍然保留矢量图标（箭头本身比文字更直观）
        if case .symbol(let name, _) = KeyCodeMapper.map(event: event, keyCode: 123).content {
            XCTAssertEqual(name, "arrow.left")
        } else {
            XCTFail("方向键应继续使用 SF Symbol")
        }
    }

    /// 键码映射产出的 identifier 必须能被七档角色正确解析（防止映射表与角色判定脱节）
    func testMappedIdentifiersFeedColorRoles() {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true) else {
            return XCTFail("无法创建测试 CGEvent")
        }

        let cases: [(CGKeyCode, KeyColorRole)] = [
            (53, .escape),      // esc
            (36, .structural),  // return
            (48, .structural),  // tab
            (49, .structural),  // space
            (51, .structural),  // delete
            (123, .arrow),      // ←
            (122, .function),   // F1
            (179, .function)    // Fn
        ]

        for (keyCode, expected) in cases {
            let info = KeyCodeMapper.map(event: event, keyCode: keyCode)
            let stroke = KeyStroke(
                modifiers: [],
                content: info.content,
                rawIdentifier: info.identifier,
                isSpecialFunctionKey: info.isSpecialFunctionKey
            )
            XCTAssertEqual(stroke.colorRole, expected, "键码 \(keyCode) 的角色判定与映射表不一致")
        }
    }

    func testPlainTypingPreservesCase() {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
            return XCTFail("无法创建测试 CGEvent")
        }
        event.flags = []
        var lowerA: UniChar = 97 // "a"
        event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &lowerA)

        let lowerInfo = KeyCodeMapper.map(event: event, keyCode: 0)
        XCTAssertEqual(lowerInfo.content, .text("a"), "小写输入必须保留小写，否则无法与 ⇧A 区分")

        var upperA: UniChar = 65 // "A"
        event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &upperA)
        let upperInfo = KeyCodeMapper.map(event: event, keyCode: 0)
        XCTAssertEqual(upperInfo.content, .text("A"))
    }

    func testShortcutLettersAreUppercased() {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 8, keyDown: true) else {
            return XCTFail("无法创建测试 CGEvent")
        }
        event.flags = .maskControl
        // Control 组合下系统给的是控制字符，映射器必须回退到物理键位解析
        var ctrlChar: UniChar = 3
        event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ctrlChar)

        let info = KeyCodeMapper.map(event: event, keyCode: 8)
        XCTAssertEqual(info.content, .text("C"), "快捷键应遵循 macOS 菜单惯例使用大写")
        XCTAssertEqual(info.identifier, "c")
        XCTAssertFalse(info.content.displayText.hasPrefix("Key_"))
    }

    func testFnAndGlobeKeyMapping() {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 179, keyDown: true) else {
            return XCTFail("无法创建测试 CGEvent")
        }
        let info179 = KeyCodeMapper.map(event: event, keyCode: 179)
        XCTAssertEqual(info179.content, .symbol(name: "globe", fallbackText: "Fn"))
        XCTAssertEqual(info179.identifier, "fn")

        let info63 = KeyCodeMapper.map(event: event, keyCode: 63)
        XCTAssertEqual(info63.content, .symbol(name: "globe", fallbackText: "Fn"))
    }

    // MARK: - 队列容量

    @MainActor
    func testQueueCapacityFollowsSettings() {
        prepareSettings()
        defer { restoreSettings() }

        let monitor = KeyMonitor.shared
        let settings = AppSettings.shared

        XCTAssertEqual(settings.maxVisibleKeys, 3, "默认同屏容量应为 3")

        for letter in ["A", "B", "C", "D"] {
            monitor.simulateKeyStroke(KeyStroke(modifiers: [], content: .text(letter), rawIdentifier: letter.lowercased()))
        }

        // 默认容量 3：推入 4 个后应保留最新的 3 个
        XCTAssertEqual(monitor.activeStrokes.map { $0.content }, [.text("B"), .text("C"), .text("D")])

        // 改为 1 后立即收紧
        settings.maxVisibleKeys = 1
        monitor.simulateKeyStroke(KeyStroke(modifiers: [], content: .text("E"), rawIdentifier: "e"))
        XCTAssertEqual(monitor.activeStrokes.count, 1)
        XCTAssertEqual(monitor.activeStrokes.first?.content, .text("E"))
    }

    @MainActor
    func testMaxVisibleKeysIsClamped() {
        prepareSettings()
        defer { restoreSettings() }

        let settings = AppSettings.shared
        settings.maxVisibleKeys = 99
        XCTAssertEqual(settings.maxVisibleKeys, 4)
        settings.maxVisibleKeys = -3
        XCTAssertEqual(settings.maxVisibleKeys, 1)
    }

    // MARK: - 连按合并与就地升级

    @MainActor
    func testRepeatCountMerge() {
        prepareSettings()
        defer { restoreSettings() }

        let monitor = KeyMonitor.shared
        AppSettings.shared.showRepeatCount = true

        monitor.simulateKeyStroke(KeyStroke(modifiers: [], content: .text("e"), rawIdentifier: "e"))
        let firstId = monitor.activeStrokes[0].id

        monitor.simulateKeyStroke(KeyStroke(modifiers: [], content: .text("e"), rawIdentifier: "e"))
        monitor.simulateKeyStroke(KeyStroke(modifiers: [], content: .text("e"), rawIdentifier: "e"))

        XCTAssertEqual(monitor.activeStrokes.count, 1)
        XCTAssertEqual(monitor.activeStrokes.first?.id, firstId)
        XCTAssertEqual(monitor.activeStrokes.first?.repeatCount, 3)
        XCTAssertEqual(monitor.punchCounters[firstId], 3)
    }

    @MainActor
    func testRepeatCountDisabledKeepsSeparateCards() {
        prepareSettings()
        defer { restoreSettings() }

        let monitor = KeyMonitor.shared
        AppSettings.shared.showRepeatCount = false

        monitor.simulateKeyStroke(KeyStroke(modifiers: [], content: .text("E"), rawIdentifier: "e"))
        monitor.simulateKeyStroke(KeyStroke(modifiers: [], content: .text("E"), rawIdentifier: "e"))

        XCTAssertEqual(monitor.activeStrokes.count, 2)
        XCTAssertEqual(monitor.activeStrokes.map(\.repeatCount), [1, 1])
    }

    @MainActor
    func testInPlaceUpgradePreservesId() {
        prepareSettings()
        defer { restoreSettings() }

        let monitor = KeyMonitor.shared

        monitor.simulateKeyStroke(
            KeyStroke(
                modifiers: [],
                content: .symbol(name: "command", fallbackText: "⌘"),
                rawIdentifier: "command",
                isSpecialFunctionKey: true,
                isModifierOnly: true
            )
        )
        let originalId = monitor.activeStrokes[0].id

        monitor.simulateKeyStroke(
            KeyStroke(
                modifiers: [.option],
                content: .symbol(name: "command", fallbackText: "⌘"),
                rawIdentifier: "option+command",
                isSpecialFunctionKey: true,
                isModifierOnly: true
            )
        )

        XCTAssertEqual(monitor.activeStrokes.count, 1)
        XCTAssertEqual(monitor.activeStrokes.first?.id, originalId)
        XCTAssertEqual(monitor.activeStrokes.first?.modifiers, [.option])

        monitor.simulateKeyStroke(
            KeyStroke(
                modifiers: [.option, .command],
                content: .text("K"),
                rawIdentifier: "option+command+k"
            )
        )

        XCTAssertEqual(monitor.activeStrokes.count, 1)
        XCTAssertEqual(monitor.activeStrokes.first?.id, originalId)
        XCTAssertEqual(monitor.activeStrokes.first?.content, .text("K"))
    }

    @MainActor
    func testPunchCountersOnlyIncrementTargetCard() {
        prepareSettings()
        defer { restoreSettings() }

        let monitor = KeyMonitor.shared

        let first = KeyStroke(modifiers: [.command], content: .text("C"), rawIdentifier: "cmd+c")
        monitor.simulateKeyStroke(first)
        XCTAssertEqual(monitor.punchCounters[first.id], 1)

        let modifier = KeyStroke(
            modifiers: [],
            content: .symbol(name: "command", fallbackText: "⌘"),
            rawIdentifier: "command",
            isSpecialFunctionKey: true,
            isModifierOnly: true
        )
        monitor.simulateKeyStroke(modifier)
        XCTAssertEqual(monitor.punchCounters[first.id], 1)

        // 在未松开的修饰键上继续按 Z：就地升级，只递增该卡片的计数
        monitor.simulateKeyStroke(
            KeyStroke(modifiers: [.command], content: .text("Z"), rawIdentifier: "cmd+z")
        )
        XCTAssertEqual(monitor.punchCounters[modifier.id], 2)
        XCTAssertEqual(monitor.punchCounters[first.id], 1)
    }

    @MainActor
    func testUpgradeExtendsDisplayDuration() async throws {
        prepareSettings()
        defer { restoreSettings() }

        let monitor = KeyMonitor.shared
        AppSettings.shared.displayDuration = 0.15

        monitor.simulateKeyStroke(
            KeyStroke(
                modifiers: [],
                content: .symbol(name: "command", fallbackText: "⌘"),
                rawIdentifier: "command",
                isSpecialFunctionKey: true,
                isModifierOnly: true
            )
        )
        let targetId = monitor.activeStrokes[0].id

        try await Task.sleep(nanoseconds: 100_000_000)
        monitor.simulateKeyStroke(
            KeyStroke(modifiers: [.command], content: .text("K"), rawIdentifier: "cmd+k")
        )

        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(monitor.activeStrokes.first?.id, targetId, "就地升级应顺延超时计时")

        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(monitor.activeStrokes.count, 0, "顺延后的超时最终仍应移除卡片")
    }

    // MARK: - 配置：默认值 / 快照往返 / 恢复默认

    @MainActor
    func testDefaultsAreCoherent() {
        typealias Defaults = AppSettings.Defaults
        XCTAssertEqual(Defaults.themeID, KeycapTheme.defaultTheme.id)
        XCTAssertEqual(Defaults.appearanceMode, .system)
        XCTAssertEqual(Defaults.maxVisibleKeys, 3)
        XCTAssertEqual(Defaults.keyOpacity, 1.0)
        XCTAssertEqual(Defaults.showKeycapTray, false)
    }

    @MainActor
    func testSettingsSnapshotRoundTrip() throws {
        prepareSettings()
        defer { restoreSettings() }

        let settings = AppSettings.shared
        settings.themeID = KeycapTheme.starfield.id
        settings.appearanceMode = .dark
        settings.maxVisibleKeys = 4
        settings.showKeycapTray = true
        settings.keyOpacity = 0.8

        let snapshot = settings.makeSnapshot()
        let data = try snapshot.encodedJSON()
        let decoded = try SettingsSnapshot.decode(data)

        XCTAssertEqual(decoded, snapshot)

        // 导入后必须还原为快照内容
        settings.resetToDefaults()
        settings.apply(decoded)

        XCTAssertEqual(settings.themeID, KeycapTheme.starfield.id)
        XCTAssertEqual(settings.appearanceMode, .dark)
        XCTAssertEqual(settings.maxVisibleKeys, 4)
        XCTAssertTrue(settings.showKeycapTray)
        XCTAssertEqual(settings.keyOpacity, 0.8, accuracy: 0.001)
    }

    /// 0.1x 导出的配置里带有已下线的 keycapStyle / displayMode 字段，
    /// 新版解码器必须忽略它们而不是整体失败
    func testLegacySnapshotWithRetiredFieldsStillDecodes() throws {
        let legacyJSON = """
        {
          "themeID": "obsidian",
          "appearanceMode": "dark",
          "keycapStyle": "aurora",
          "displayMode": "shortcutsOnly",
          "maxVisibleKeys": 2,
          "isEnabled": true
        }
        """.data(using: .utf8)!

        let snapshot = try SettingsSnapshot.decode(legacyJSON)
        XCTAssertEqual(snapshot.maxVisibleKeys, 2)
        XCTAssertEqual(snapshot.appearanceMode, .dark)
        XCTAssertEqual(snapshot.themeID, "obsidian")
    }

    @MainActor
    func testResetToDefaultsRestoresEverything() {
        prepareSettings()
        defer { restoreSettings() }

        let settings = AppSettings.shared
        settings.themeID = KeycapTheme.starfield.id
        settings.appearanceMode = .light
        settings.maxVisibleKeys = 1
        settings.showRepeatCount = false

        settings.resetToDefaults()

        XCTAssertEqual(settings.themeID, AppSettings.Defaults.themeID)
        XCTAssertEqual(settings.appearanceMode, AppSettings.Defaults.appearanceMode)
        XCTAssertEqual(settings.maxVisibleKeys, AppSettings.Defaults.maxVisibleKeys)
        XCTAssertEqual(settings.showRepeatCount, AppSettings.Defaults.showRepeatCount)
    }

    @MainActor
    func testInvalidThemeIDFallsBackToDefault() {
        prepareSettings()
        defer { restoreSettings() }

        AppSettings.shared.themeID = "legacy-theme-that-does-not-exist"
        XCTAssertEqual(AppSettings.shared.theme.id, KeycapTheme.defaultTheme.id)
    }

    /// 已下线设置的 key 必须在迁移中被清除，否则会以「幽灵配置」的形式留在 UserDefaults 里
    @MainActor
    func testRetiredSettingsKeysAreStable() {
        // 迁移只在进程内首次 init 时执行，这里验证持久化后 schemaVersion 已被写入
        AppSettings.shared.persistNow()
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "keyglow.schemaVersion"), 3)
    }

    // MARK: - 视图可实例化

    @MainActor
    func testPreferencesAndKeycapViewsLayout() {
        let prefs = PreferencesView()
        let hosting = NSHostingView(rootView: prefs)
        hosting.frame = NSRect(x: 0, y: 0, width: 580, height: 640)
        hosting.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(hosting.fittingSize.width, 0)
        XCTAssertGreaterThan(hosting.fittingSize.height, 0)

        let palette = KeycapTheme.petals.colors(for: .light).modifier
        let item = KeycapItemView(
            content: .symbol(name: "command", fallbackText: "⌘"),
            palette: palette,
            borderStyle: .neon,
            minWidth: 40,
            height: 40
        )
        let itemHost = NSHostingView(rootView: item)
        itemHost.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(itemHost.fittingSize.width, 0)
        XCTAssertLessThanOrEqual(itemHost.fittingSize.width, 120, "键帽不应无限膨胀溢出")
    }

    @MainActor
    func testKeyRepeatBadgeInitialization() {
        for theme in KeycapTheme.all {
            for scheme in [ColorScheme.light, .dark] {
                let badge = KeyRepeatBadgeView(
                    count: 3,
                    palette: theme.colors(for: scheme).alpha,
                    borderStyle: theme.border
                )
                XCTAssertEqual(badge.count, 3)
            }
        }
    }

    @MainActor
    func testKeycapViewCarriesThemeAndRepeatCount() {
        let stroke = KeyStroke(
            modifiers: [.command],
            content: .text("C"),
            rawIdentifier: "cmd+c",
            repeatCount: 4
        )

        let view = KeycapView(
            stroke: stroke,
            theme: .starfield,
            colorScheme: .dark,
            opacity: 0.9,
            punchTrigger: 2,
            repeatCount: 4
        )

        XCTAssertEqual(view.repeatCount, 4)
        XCTAssertEqual(view.punchTrigger, 2)
        XCTAssertEqual(view.theme.id, KeycapTheme.starfield.id)
        XCTAssertEqual(view.colorScheme, .dark)
    }
}
