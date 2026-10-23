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

    // MARK: - 主题目录

    func testThemeCatalogIntegrity() {
        XCTAssertEqual(KeycapTheme.all.count, 6, "内置主题数量应与设计文档一致")

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

        // 未知 id 必须回退默认主题，避免旧配置导致空白配色
        XCTAssertEqual(KeycapTheme.theme(id: "not-a-theme").id, KeycapTheme.defaultTheme.id)
        XCTAssertEqual(KeycapTheme.theme(id: KeycapTheme.neon.id).id, KeycapTheme.neon.id)
    }

    /// 0.12 的主题 id 被 0.13 的设计命名取代，老用户升级后必须停留在同一套配色上
    func testLegacyThemeIDsMigrateToRedesignedColorways() {
        let legacyMap: [String: String] = [
            "graphite": KeycapTheme.obsidian.id,
            "paper": KeycapTheme.latte.id,
            "ocean": KeycapTheme.glacier.id,
            "sunset": KeycapTheme.sakura.id,
            "terminal": KeycapTheme.phosphor.id,
            "neon": KeycapTheme.neon.id
        ]

        for (legacy, expected) in legacyMap {
            XCTAssertEqual(KeycapTheme.resolvedID(legacy), expected, "旧 id \(legacy) 未迁移到新配色")
            XCTAssertEqual(KeycapTheme.theme(id: legacy).id, expected, "按旧 id 查找应命中新配色")
        }

        // 未知 id 与空串一律回退默认主题
        XCTAssertEqual(KeycapTheme.resolvedID("legacy-theme-that-does-not-exist"), KeycapTheme.defaultTheme.id)
        XCTAssertEqual(KeycapTheme.resolvedID(""), KeycapTheme.defaultTheme.id)
        // 新 id 必须原样返回
        XCTAssertEqual(KeycapTheme.resolvedID(KeycapTheme.sakura.id), KeycapTheme.sakura.id)
    }

    /// 0.13 的设计前提：四档颜色是四个光位，任一档都不能与另一档糊在一起，
    /// 且结构键（Return / Tab / 方向键）必须与字母键拉开明度台阶，否则组合键读不出三段结构。
    func testColorRolesFormDistinctValuePlanes() {
        for theme in KeycapTheme.all {
            for scheme in [ColorScheme.light, .dark] {
                let colors = theme.colors(for: scheme)
                let label = "\(theme.name) / \(scheme == .dark ? "夜晚" : "白天")"

                // 结构层与字母键的明度台阶
                XCTAssertGreaterThanOrEqual(
                    colors.regular.midTone.contrastRatio(with: colors.special.midTone), 1.28,
                    "\(label) 的功能键与字母键明度过于接近，结构层次读不出来"
                )

                // 四档两两之间必须可分辨：要么明度差够，要么饱和度差够
                let palettes = colors.allPalettes
                for i in palettes.indices {
                    for j in palettes.indices where j > i {
                        let ratio = palettes[i].midTone.contrastRatio(with: palettes[j].midTone)
                        let chromaGap = abs(palettes[i].accent.chroma - palettes[j].accent.chroma)
                        XCTAssertTrue(
                            ratio >= 1.25 || chromaGap >= 0.08,
                            "\(label) 第 \(i) 档与第 \(j) 档在明度和饱和度上都过于接近，视觉上无法区分"
                        )
                    }
                }
            }
        }
    }

    /// 色卡带按「底色 → 结构 → 强调 → 英雄键」排列，顺序不能随实现漂移
    func testColorwayHierarchyOrder() {
        let colors = KeycapTheme.obsidian.colors(for: .light)
        XCTAssertEqual(colors.hierarchy.count, 4)
        XCTAssertEqual(colors.hierarchy[0].accent, colors.regular.accent)
        XCTAssertEqual(colors.hierarchy[1].accent, colors.special.accent)
        XCTAssertEqual(colors.hierarchy[2].accent, colors.modifier.accent)
        XCTAssertEqual(colors.hierarchy[3].accent, colors.escape.accent)
    }

    func testThemeSwitchesBetweenDayAndNight() {
        for theme in KeycapTheme.all {
            let light = theme.colors(for: .light)
            let dark = theme.colors(for: .dark)

            // 白天档的普通键必须明显比夜晚档更亮（保证跟随系统时观感真的会变）
            XCTAssertGreaterThan(
                light.regular.midTone.relativeLuminance,
                dark.regular.midTone.relativeLuminance + 0.25,
                "\(theme.name) 的昼夜两档亮度差不足，跟随系统时几乎看不出变化"
            )

            // 四档色板在昼夜之间都不能相同
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

    func testLegendContrastMeetsAccessibilityThreshold() {
        for theme in KeycapTheme.all {
            for scheme in [ColorScheme.light, .dark] {
                let colors = theme.colors(for: scheme)
                for role in KeyColorRole.allCases {
                    let palette = colors.palette(for: role)
                    XCTAssertGreaterThanOrEqual(
                        palette.legendContrastRatio, 3.0,
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

    /// 设计要求：普通字母键「普通颜色」（低饱和），功能键才有强调色
    func testRegularKeysStayNeutralWhileFunctionKeysAreAccented() {
        for theme in KeycapTheme.all {
            for scheme in [ColorScheme.light, .dark] {
                let colors = theme.colors(for: scheme)
                let label = "\(theme.name) / \(scheme == .dark ? "夜晚" : "白天")"

                XCTAssertLessThan(
                    colors.regular.accent.chroma, 0.12,
                    "\(label) 的普通键饱和度过高，已经不是「普通颜色」"
                )
                XCTAssertGreaterThan(
                    colors.modifier.accent.chroma, colors.regular.accent.chroma + 0.08,
                    "\(label) 的修饰键与普通键区分度不足"
                )
            }
        }
    }

    /// P0 修复：Esc 与其余特殊功能键必须是两套颜色，而不是共用一个色号
    func testEscapeAndSpecialKeyColorsAreIndependent() {
        for theme in KeycapTheme.all {
            for scheme in [ColorScheme.light, .dark] {
                let colors = theme.colors(for: scheme)
                XCTAssertNotEqual(
                    colors.escape.accent, colors.special.accent,
                    "\(theme.name) 的 Esc 与功能键同色，语义层次丢失"
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

    // MARK: - 外观模式与材质

    func testAppearanceModeMapsToWindowAppearance() {
        XCTAssertNil(ThemeAppearanceMode.system.nsAppearance, "跟随系统必须交出 appearance 控制权")
        XCTAssertEqual(ThemeAppearanceMode.light.nsAppearance?.name, .aqua)
        XCTAssertEqual(ThemeAppearanceMode.dark.nsAppearance?.name, .darkAqua)
        XCTAssertEqual(ThemeAppearanceMode.allCases.count, 3)
    }

    func testKeycapStyleNamingAndLegacyMigration() {
        XCTAssertEqual(KeycapStyle.allCases.count, 3)
        XCTAssertEqual(KeycapStyle.matte.title, "哑光实体")
        XCTAssertEqual(KeycapStyle.frosted.title, "磨砂玻璃")
        XCTAssertEqual(KeycapStyle.aurora.title, "极光染色")

        // 旧版本 rawValue 必须能平滑迁移，避免老用户升级后材质回退默认
        XCTAssertEqual(KeycapStyle.migrate(fromLegacy: "classicDark"), .matte)
        XCTAssertEqual(KeycapStyle.migrate(fromLegacy: "frostedGlass"), .frosted)
        XCTAssertEqual(KeycapStyle.migrate(fromLegacy: "auroraGlow"), .aurora)
        XCTAssertEqual(KeycapStyle.migrate(fromLegacy: "matte"), .matte)
        XCTAssertNil(KeycapStyle.migrate(fromLegacy: "unknown-style"))
    }

    // MARK: - 按键角色解析

    func testColorRoleResolution() {
        let regular = KeyStroke(modifiers: [.command], content: .text("C"), rawIdentifier: "command+c", isShortcut: true)
        XCTAssertEqual(regular.colorRole, .regular)

        let modifier = KeyStroke(
            modifiers: [],
            content: .symbol(name: "command", fallbackText: "⌘"),
            rawIdentifier: "command",
            isShortcut: true,
            isSpecialFunctionKey: true,
            isModifierOnly: true
        )
        XCTAssertEqual(modifier.colorRole, .modifier)

        let escape = KeyStroke(
            modifiers: [],
            content: .text("esc"),
            rawIdentifier: "esc",
            isShortcut: true,
            isSpecialFunctionKey: true
        )
        XCTAssertEqual(escape.colorRole, .escape)

        let returnKey = KeyStroke(
            modifiers: [],
            content: .text("return"),
            rawIdentifier: "return",
            isShortcut: true,
            isSpecialFunctionKey: true
        )
        XCTAssertEqual(returnKey.colorRole, .special, "Return 属于功能键，不应再与 Esc 共用角色")
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

    func testDisplayAnchorsAndModes() {
        XCTAssertEqual(DisplayAnchor.allCases.count, 5)
        XCTAssertEqual(DisplayAnchor.bottomCenter.title, "屏幕底部居中")
        XCTAssertEqual(DisplayAnchor.mouseFollow.title, "跟随鼠标光标")

        XCTAssertEqual(DisplayMode.allCases.count, 2)
        XCTAssertEqual(DisplayMode.shortcutsOnly.title, "仅快捷键模式")
        XCTAssertEqual(DisplayMode.allCases.contains(.allKeys), true)
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

    // MARK: - 队列容量（P0：文档写 3、实现写 2 的不一致）

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
                isShortcut: true,
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
                isShortcut: true,
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
                rawIdentifier: "option+command+k",
                isShortcut: true
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

        let first = KeyStroke(modifiers: [.command], content: .text("C"), rawIdentifier: "cmd+c", isShortcut: true)
        monitor.simulateKeyStroke(first)
        XCTAssertEqual(monitor.punchCounters[first.id], 1)

        let modifier = KeyStroke(
            modifiers: [],
            content: .symbol(name: "command", fallbackText: "⌘"),
            rawIdentifier: "command",
            isShortcut: true,
            isSpecialFunctionKey: true,
            isModifierOnly: true
        )
        monitor.simulateKeyStroke(modifier)
        XCTAssertEqual(monitor.punchCounters[first.id], 1)

        // 在未松开的修饰键上继续按 Z：就地升级，只递增该卡片的计数
        monitor.simulateKeyStroke(
            KeyStroke(modifiers: [.command], content: .text("Z"), rawIdentifier: "cmd+z", isShortcut: true)
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
                isShortcut: true,
                isSpecialFunctionKey: true,
                isModifierOnly: true
            )
        )
        let targetId = monitor.activeStrokes[0].id

        try await Task.sleep(nanoseconds: 100_000_000)
        monitor.simulateKeyStroke(
            KeyStroke(modifiers: [.command], content: .text("K"), rawIdentifier: "cmd+k", isShortcut: true)
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
        XCTAssertEqual(Defaults.displayMode, .allKeys)
        XCTAssertEqual(Defaults.keycapStyle, KeycapTheme.defaultTheme.recommendedStyle)
        XCTAssertEqual(Defaults.showKeycapTray, false)
    }

    @MainActor
    func testSettingsSnapshotRoundTrip() throws {
        prepareSettings()
        defer { restoreSettings() }

        let settings = AppSettings.shared
        settings.themeID = KeycapTheme.glacier.id
        settings.appearanceMode = .dark
        settings.keycapStyle = .frosted
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

        XCTAssertEqual(settings.themeID, KeycapTheme.glacier.id)
        XCTAssertEqual(settings.appearanceMode, .dark)
        XCTAssertEqual(settings.keycapStyle, .frosted)
        XCTAssertEqual(settings.maxVisibleKeys, 4)
        XCTAssertTrue(settings.showKeycapTray)
        XCTAssertEqual(settings.keyOpacity, 0.8, accuracy: 0.001)
    }

    @MainActor
    func testResetToDefaultsRestoresEverything() {
        prepareSettings()
        defer { restoreSettings() }

        let settings = AppSettings.shared
        settings.themeID = KeycapTheme.neon.id
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

    // MARK: - 视图可实例化

    @MainActor
    func testPreferencesAndKeycapViewsLayout() {
        let prefs = PreferencesView()
        let hosting = NSHostingView(rootView: prefs)
        hosting.frame = NSRect(x: 0, y: 0, width: 580, height: 700)
        hosting.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(hosting.fittingSize.width, 0)
        XCTAssertGreaterThan(hosting.fittingSize.height, 0)

        let palette = KeycapTheme.obsidian.colors(for: .light).modifier
        let item = KeycapItemView(
            style: .matte,
            content: .symbol(name: "command", fallbackText: "⌘"),
            palette: palette,
            borderStyle: .adaptive,
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
        for style in KeycapStyle.allCases {
            for theme in KeycapTheme.all {
                for scheme in [ColorScheme.light, .dark] {
                    let badge = KeyRepeatBadgeView(
                        count: 3,
                        style: style,
                        palette: theme.colors(for: scheme).regular,
                        borderStyle: theme.border
                    )
                    XCTAssertEqual(badge.count, 3)
                    XCTAssertEqual(badge.style, style)
                }
            }
        }
    }

    @MainActor
    func testKeycapViewCarriesThemeAndRepeatCount() {
        let stroke = KeyStroke(
            modifiers: [.command],
            content: .text("C"),
            rawIdentifier: "cmd+c",
            isShortcut: true,
            repeatCount: 4
        )

        let view = KeycapView(
            stroke: stroke,
            theme: .neon,
            style: .aurora,
            colorScheme: .dark,
            opacity: 0.9,
            punchTrigger: 2,
            repeatCount: 4
        )

        XCTAssertEqual(view.repeatCount, 4)
        XCTAssertEqual(view.punchTrigger, 2)
        XCTAssertEqual(view.theme.id, KeycapTheme.neon.id)
        XCTAssertEqual(view.style, .aurora)
        XCTAssertEqual(view.colorScheme, .dark)
    }
}
