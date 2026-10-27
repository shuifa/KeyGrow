//
//  KeyGlowTests.swift
//  KeyGlowTests
//
//  0.100 的测试重点随实现一起迁移：
//   1. 材质字典的两条物理规律（中性上亮下暗 / 彩色上暗下亮）与字符可读性；
//   2. Keystroke Pro 实测比例的回归保护（0.086H 圆角、0.097H 前唇、0.97H 宽度……）；
//   3. 显示策略：只上台特殊键与组合键；
//   4. 长按驻留与「松开才计时」的时序语义。
//

import AppKit
import CoreGraphics
import SwiftUI
import XCTest
@testable import KeyGlow

@MainActor
final class KeyGlowTests: XCTestCase {

    // MARK: - 用户配置保护
    //
    // 用例会临时改写入 AppSettings（落盘到真实 UserDefaults），
    // 因此在首个用例前快照、在每个用例结束时还原，避免污染开发者本机偏好。

    private struct SettingsBackup {
        let isEnabled: Bool
        let shape: KeycapShape
        let anchor: DisplayAnchor
        let sizeScale: Double
        let displayDuration: Double
        let edgeInset: Double
        let showRepeatCount: Bool
        let colorSlots: KeycapColorSlots
    }

    private static var backup: SettingsBackup?

    private func prepareSettings() {
        if Self.backup == nil {
            let settings = AppSettings.shared
            Self.backup = SettingsBackup(
                isEnabled: settings.isEnabled,
                shape: settings.shape,
                anchor: settings.anchor,
                sizeScale: settings.sizeScale,
                displayDuration: settings.displayDuration,
                edgeInset: settings.edgeInset,
                showRepeatCount: settings.showRepeatCount,
                colorSlots: settings.colorSlots
            )
        }
        AppSettings.shared.resetToDefaults()
        KeyMonitor.shared.clearStroke()
    }

    private func restoreSettings() {
        guard let backup = Self.backup else { return }
        let settings = AppSettings.shared
        settings.isEnabled = backup.isEnabled
        settings.shape = backup.shape
        settings.anchor = backup.anchor
        settings.sizeScale = backup.sizeScale
        settings.displayDuration = backup.displayDuration
        settings.edgeInset = backup.edgeInset
        settings.showRepeatCount = backup.showRepeatCount
        settings.colorSlots = backup.colorSlots
        settings.persistNow()
        KeyMonitor.shared.clearStroke()
    }

    override func setUp() async throws {
        try await super.setUp()
        prepareSettings()
    }

    override func tearDown() async throws {
        restoreSettings()
        try await super.tearDown()
    }

    // MARK: - 材质字典

    func testMaterialCatalogIntegrity() {
        let ids = KeycapMaterial.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "材质 id 不允许重复")
        XCTAssertFalse(ids.contains(where: { $0.isEmpty }))
        // 4 中性（铝/白/石墨/深空）+ 8 彩色 + 1 强调色 = 13 种按键材质，另有 3 种仅底板材质
        XCTAssertEqual(KeycapMaterial.keyCatalog.count, 13)
        XCTAssertEqual(KeycapMaterial.plateCatalog.count, 4)
        XCTAssertEqual(KeycapMaterial.all.count, 16, "space 同时属于按键与底板目录，去重后共 16 种")

        for material in KeycapMaterial.all {
            XCTAssertFalse(material.name.isEmpty)
            XCTAssertFalse(material.englishName.isEmpty)
        }

        // 按键目录必须覆盖四色槽的出厂值
        let keyIDs = Set(KeycapMaterial.keyCatalog.map(\.id))
        XCTAssertTrue(keyIDs.contains(KeycapColorSlots.defaults.key))
        XCTAssertTrue(keyIDs.contains(KeycapColorSlots.defaults.modifier))
        XCTAssertTrue(keyIDs.contains(KeycapColorSlots.defaults.escape))

        // 底板目录必须覆盖出厂底板
        XCTAssertTrue(KeycapMaterial.plateCatalog.map(\.id).contains(KeycapColorSlots.defaults.border))

        // 未知 id 回退给定默认材质，绝不返回空壳
        XCTAssertEqual(KeycapMaterial.material(id: "no-such-material", fallback: .aluminium).id, "aluminium")
    }

    /// 中性材质必须上亮下暗：这是金属冷感的来源
    func testNeutralMaterialsAreLighterOnTop() {
        for material in [KeycapMaterial.aluminium, .ivory, .graphite, .space, .agate, .chalk, .chromium] {
            let palette = material.palette()
            XCTAssertGreaterThan(
                palette.faceTop.relativeLuminance,
                palette.faceBottom.relativeLuminance,
                "\(material.name) 作为中性材质必须保持上亮下暗"
            )
        }
    }

    /// 彩色材质必须上暗下亮：反过来打光才能保住饱和度，不读成暗块
    func testChromaticMaterialsAreDarkerOnTop() {
        let chromatic: [KeycapMaterial] = [.red, .orange, .amber, .grass, .mint, .cobalt, .indigo, .fuchsia]
        for material in chromatic {
            let palette = material.palette()
            XCTAssertLessThan(
                palette.faceTop.relativeLuminance,
                palette.faceBottom.relativeLuminance,
                "\(material.name) 作为彩色材质必须是上暗下亮"
            )
            XCTAssertGreaterThan(material.swatch.chroma, 0.5, "\(material.name) 必须是高饱和塑料色")
        }
    }

    /// 前唇必须比顶面下沿更深，唇线必须比顶面下沿更亮——否则键帽读不出厚度
    func testWallAndLipBracketTheFace() {
        for material in KeycapMaterial.all {
            let palette = material.palette()
            XCTAssertLessThanOrEqual(
                palette.wall.relativeLuminance,
                palette.faceBottom.relativeLuminance + 0.001,
                "\(material.name) 的前唇必须比顶面下沿暗"
            )
            XCTAssertGreaterThan(
                palette.lip.relativeLuminance,
                palette.faceBottom.relativeLuminance,
                "\(material.name) 的唇线必须比顶面下沿亮"
            )
        }
    }

    /// 字符必须可读：白字优先，白字对比度不足 3:1 时自动翻成深墨字
    func testLegendStaysReadableAcrossAllMaterials() {
        for material in KeycapMaterial.all {
            let palette = material.palette()
            XCTAssertGreaterThanOrEqual(
                palette.legendContrastRatio,
                3.0,
                "\(material.name) 的字符对比度不足 3:1"
            )
        }
    }

    /// 浅色键帽翻深字、深色键帽保白字
    func testLegendColorSwitchesOnLightSurfaces() {
        XCTAssertTrue(KeycapMaterial.aluminium.palette().usesDarkLegend, "浅铝必须配深墨字符")
        XCTAssertTrue(KeycapMaterial.ivory.palette().usesDarkLegend, "象牙白必须配深墨字符")
        XCTAssertFalse(KeycapMaterial.space.palette().usesDarkLegend, "深空必须配白字")
        XCTAssertFalse(KeycapMaterial.cobalt.palette().usesDarkLegend, "钴蓝必须配白字")
    }

    // MARK: - 四色槽

    func testColorSlotsMapRolesToMaterials() {
        let slots = KeycapColorSlots(
            escape: "mint",
            modifier: "graphite",
            key: "ivory",
            border: "chalk"
        )

        XCTAssertEqual(slots.material(for: .escape).id, "mint")
        XCTAssertEqual(slots.material(for: .modifier).id, "graphite")
        XCTAssertEqual(slots.material(for: .key).id, "ivory")
        XCTAssertEqual(slots.borderMaterial.id, "chalk")

        // 四个色槽彼此独立：任意组合都被允许
        XCTAssertNotEqual(slots.material(for: .escape).id, slots.material(for: .key).id)
    }

    func testColorSlotsSelfHealInvalidIDs() {
        let broken = KeycapColorSlots(escape: "nope", modifier: "", key: "also-nope", border: "gone")
        let healed = broken.normalized()

        XCTAssertEqual(healed.escape, KeycapColorSlots.defaults.escape)
        XCTAssertEqual(healed.modifier, KeycapColorSlots.defaults.modifier)
        XCTAssertEqual(healed.key, KeycapColorSlots.defaults.key)
        XCTAssertEqual(healed.border, KeycapColorSlots.defaults.border)
    }

    func testDefaultSlotsMatchKeystrokeProDefaults() {
        // Key = Aluminium / Modifier = Space / Escape = Accent Color / Border = Agate Gray
        XCTAssertEqual(KeycapColorSlots.defaults.key, "aluminium")
        XCTAssertEqual(KeycapColorSlots.defaults.modifier, "space")
        XCTAssertEqual(KeycapColorSlots.defaults.escape, "accent")
        XCTAssertEqual(KeycapColorSlots.defaults.border, "agate")
    }

    // MARK: - 几何比例（Keystroke Pro 实测回归）

    func testGeometryRatiosMatchMeasuredReference() {
        let height: CGFloat = 62
        let metrics = KeycapMetrics(height: height)

        func ratio(_ value: CGFloat) -> CGFloat { value / height }

        XCTAssertEqual(ratio(metrics.cornerRadius), 0.086, accuracy: 0.03, "圆角应为高度的 8.6%")
        XCTAssertEqual(ratio(metrics.lipDepth), 0.097, accuracy: 0.03, "前唇应为高度的 9.7%")
        XCTAssertEqual(ratio(metrics.keySpacing), 0.17, accuracy: 0.03, "组内键间距应为高度的 17%")
        XCTAssertEqual(ratio(metrics.platePadding), 0.15, accuracy: 0.03, "底板内边距应为高度的 15%")
        XCTAssertEqual(ratio(metrics.plateCornerRadius), 0.21, accuracy: 0.03, "底板圆角应为高度的 21%")
        XCTAssertEqual(ratio(metrics.unitWidth), 0.97, accuracy: 0.01, "1u 键帽宽度应为高度的 97%")
    }

    func testKeycapIsTallerThanWide() {
        let metrics = KeycapMetrics(height: 62)
        // 原版键帽不是正方形，而是 0.97H × 1H 的竖矩形
        XCTAssertLessThan(metrics.unitWidth, metrics.height)
    }

    func testGeometryScalesLinearlyWithSize() {
        let small = KeycapMetrics(height: 40)
        let large = KeycapMetrics(height: 120)
        XCTAssertEqual(large.unitWidth / small.unitWidth, 3, accuracy: 0.02)
        // 间距会被取整到整点，允许更大的相对误差
        XCTAssertEqual(large.keySpacing / small.keySpacing, 3, accuracy: 0.25)
    }

    func testPlateCornerIsLargerThanKeyCorner() {
        for height in [40.0, 62.0, 120.0] as [CGFloat] {
            let metrics = KeycapMetrics(height: height)
            XCTAssertGreaterThan(metrics.plateCornerRadius, metrics.cornerRadius)
        }
    }

    // MARK: - 键帽宽度倍数

    func testWidthUnitsFollowRealKeyboardProportions() {
        XCTAssertEqual(KeyModifier.command.legend.widthUnits, 1.5, "command 实测 1.51u")
        XCTAssertEqual(KeyModifier.option.legend.widthUnits, 1.5)
        XCTAssertEqual(KeyModifier.control.legend.widthUnits, 1.5)
        XCTAssertEqual(KeyModifier.shift.legend.widthUnits, 1.5)

        let metrics = KeycapMetrics(height: 62)
        XCTAssertEqual(metrics.keyWidth(units: 1.0), 60, "1u 键帽在 62pt 高度下应为 60pt 宽")
        XCTAssertGreaterThan(metrics.keyWidth(units: 1.5), metrics.keyWidth(units: 1.0))
    }

    func testModifierLegendCarriesSymbolAndLabel() {
        for modifier in KeyModifier.allCases {
            let legend = modifier.legend
            XCTAssertNotNil(legend.symbol)
            XCTAssertEqual(legend.text, modifier.rawValue, "修饰键标签必须是小写英文名")
            XCTAssertTrue(legend.isDualElement)
        }
        // macOS 标准顺序 ⌃ ⌥ ⇧ ⌘
        XCTAssertEqual(
            KeyModifier.allCases.sorted(by: { $0.sortOrder < $1.sortOrder }),
            [.control, .option, .shift, .command]
        )
    }

    // MARK: - 显示策略

    func testPlainTypingIsNeverDisplayed() {
        for text in ["a", "Z", "7", "?", "中"] {
            let stroke = KeyStroke(legend: KeyLegend(text: text), rawIdentifier: text.lowercased())
            XCTAssertFalse(stroke.isDisplayable, "单独输入「\(text)」不应上台面")
        }
    }

    func testSpecialKeysAreDisplayed() {
        let cases: [(String, KeyLegend)] = [
            ("esc", KeyLegend(symbol: "escape", text: "escape", widthUnits: 1.25)),
            ("return", KeyLegend(symbol: "return", text: "return", widthUnits: 1.75)),
            ("delete", KeyLegend(symbol: "delete.left", text: "delete", widthUnits: 1.75)),
            ("f5", KeyLegend(text: "f5")),
            ("left_arrow", KeyLegend(symbol: "arrow.left")),
            ("space", KeyLegend(symbol: "space", text: "space", widthUnits: 2.0))
        ]
        for (identifier, legend) in cases {
            let stroke = KeyStroke(legend: legend, rawIdentifier: identifier, isSpecialKey: true)
            XCTAssertTrue(stroke.isDisplayable, "\(identifier) 是特殊键，必须上台面")
        }
    }

    func testModifierOnlyStrokeIsDisplayed() {
        let stroke = KeyStroke(
            legend: KeyModifier.command.legend,
            rawIdentifier: "command",
            isSpecialKey: true,
            isModifierOnly: true
        )
        XCTAssertTrue(stroke.isDisplayable)
        XCTAssertEqual(stroke.colorRole, .modifier)
    }

    func testShortcutCombinationsAreDisplayed() {
        let combo = KeyStroke(
            modifiers: [.command],
            legend: KeyLegend(text: "S"),
            rawIdentifier: "command+s"
        )
        XCTAssertTrue(combo.isDisplayable, "含修饰键的组合必须上台面")
        XCTAssertEqual(combo.totalWidthUnits, 2.5, "⌘(1.5u) + S(1u) = 2.5u")
    }

    /// ⇧ + 字符键只是打一个大写字母，不属于「组合快捷键」，不得闪出键帽
    func testShiftTypingIsNotTreatedAsShortcut() {
        let capitalA = KeyStroke(modifiers: [.shift], legend: KeyLegend(text: "A"), rawIdentifier: "shift+a")
        XCTAssertFalse(capitalA.isDisplayable, "⇧A 是普通输入，不应上台面")

        let shiftTab = KeyStroke(
            modifiers: [.shift],
            legend: KeyLegend(symbol: "arrow.right.to.line", text: "tab", widthUnits: 1.25),
            rawIdentifier: "shift+tab",
            isSpecialKey: true
        )
        XCTAssertTrue(shiftTab.isDisplayable, "⇧Tab 是特殊键组合，必须上台面")

        let shiftArrow = KeyStroke(
            modifiers: [.shift],
            legend: KeyLegend(symbol: "arrow.left"),
            rawIdentifier: "shift+left_arrow",
            isSpecialKey: true
        )
        XCTAssertTrue(shiftArrow.isDisplayable, "⇧← 是特殊键组合，必须上台面")

        let controlShiftTab = KeyStroke(
            modifiers: [.control, .shift],
            legend: KeyLegend(text: "Tab"),
            rawIdentifier: "control+shift+tab"
        )
        XCTAssertTrue(controlShiftTab.isDisplayable, "含 ⌃ 的组合一律上台面")
    }

    func testColorRoleUsesThreeSlots() {
        let esc = KeyStroke(legend: KeyLegend(text: "escape"), rawIdentifier: "esc", isSpecialKey: true)
        XCTAssertEqual(esc.colorRole, .escape)

        let comboWithEsc = KeyStroke(
            modifiers: [.command],
            legend: KeyLegend(text: "escape"),
            rawIdentifier: "command+esc",
            isSpecialKey: true
        )
        XCTAssertEqual(comboWithEsc.colorRole, .escape, "⌘esc 仍取 Esc 色槽")

        let modifierOnly = KeyStroke(
            legend: KeyModifier.shift.legend,
            rawIdentifier: "shift",
            isSpecialKey: true,
            isModifierOnly: true
        )
        XCTAssertEqual(modifierOnly.colorRole, .modifier)

        let f5 = KeyStroke(legend: KeyLegend(text: "f5"), rawIdentifier: "f5", isSpecialKey: true)
        XCTAssertEqual(f5.colorRole, .key)

        let combo = KeyStroke(modifiers: [.command], legend: KeyLegend(text: "S"), rawIdentifier: "command+s")
        XCTAssertEqual(combo.colorRole, .key, "组合键的主键取按键色槽")
    }

    // MARK: - 键码解析

    func testKeyCodeMapperProducesReadableLegends() throws {
        let source = CGEventSource(stateID: .hidSystemState)

        func info(for keyCode: CGKeyCode, flags: CGEventFlags = []) throws -> KeyCodeMapper.KeyInfo {
            let event = try XCTUnwrap(CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true))
            event.flags = flags
            return KeyCodeMapper.map(event: event, keyCode: keyCode)
        }

        let esc = try info(for: 53)
        XCTAssertEqual(esc.identifier, "esc")
        XCTAssertEqual(esc.legend.text, "escape")
        XCTAssertEqual(esc.legend.symbol, "escape")
        XCTAssertTrue(esc.isSpecialKey)

        let f1 = try info(for: 122)
        XCTAssertEqual(f1.identifier, "f1")
        XCTAssertEqual(f1.legend.text, "f1")
        XCTAssertTrue(f1.isSpecialKey)

        let leftArrow = try info(for: 123)
        XCTAssertEqual(leftArrow.identifier, "left_arrow")
        XCTAssertNil(leftArrow.legend.text, "方向键只画符号")
        XCTAssertNotNil(leftArrow.legend.symbol)

        let commandS = try info(for: 1, flags: .maskCommand)
        XCTAssertEqual(commandS.legend.text, "S", "快捷键组合按 macOS 惯例大写")
        XCTAssertFalse(commandS.isSpecialKey)

        // 单独输入字母：不是特殊键，因此不会上台面
        let plainS = try info(for: 1)
        XCTAssertFalse(plainS.isSpecialKey)
    }

    // MARK: - 吸附点

    func testAnchorGridHasEightPointsAndNoCenter() {
        XCTAssertEqual(DisplayAnchor.allCases.count, 8, "3×3 去掉中心 = 8 个吸附点")

        let cells = DisplayAnchor.grid.flatMap { $0 }
        XCTAssertEqual(cells.count, 9, "九宫格共 9 格")
        XCTAssertEqual(cells.compactMap { $0 }.count, 8, "其中 8 格可点")
        XCTAssertNil(cells[4], "正中心必须留空")

        let combos = Set(DisplayAnchor.allCases.map { "\($0.row.rawValue)-\($0.column.rawValue)" })
        XCTAssertEqual(combos.count, 8)

        let titles = DisplayAnchor.allCases.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count)
    }

    // MARK: - 配置

    func testDefaultsAreCoherent() {
        let settings = AppSettings.shared
        XCTAssertEqual(settings.shape, .classic)
        XCTAssertEqual(settings.anchor, .bottomCenter)
        XCTAssertEqual(settings.sizeScale, 1.0)
        XCTAssertEqual(settings.displayDuration, 1.2, accuracy: 0.001)
        XCTAssertEqual(settings.edgeInset, 56, accuracy: 0.001)
        XCTAssertEqual(settings.metrics.height, 62, accuracy: 0.001, "1x 档键帽高度应为 62pt")
    }

    func testSettingsClampOutOfRangeValues() {
        let settings = AppSettings.shared

        settings.sizeScale = 99
        XCTAssertEqual(settings.sizeScale, 2.2, "尺寸上限 2.2x")

        settings.sizeScale = 0.1
        XCTAssertEqual(settings.sizeScale, 0.7, "尺寸下限 0.7x")

        settings.displayDuration = 0.0
        XCTAssertEqual(settings.displayDuration, 0.2, accuracy: 0.001, "停留时长下限 200ms")

        settings.displayDuration = 30
        XCTAssertEqual(settings.displayDuration, 5.0, accuracy: 0.001, "停留时长上限 5s")

        settings.edgeInset = 9999
        XCTAssertEqual(settings.edgeInset, 240, accuracy: 0.001)
    }

    func testResetToDefaultsRestoresEverything() {
        let settings = AppSettings.shared
        settings.shape = .pill
        settings.anchor = .topLeading
        settings.sizeScale = 2.0
        settings.displayDuration = 4.0
        settings.edgeInset = 200
        settings.showRepeatCount = false
        settings.colorSlots = KeycapColorSlots(escape: "red", modifier: "mint", key: "space", border: "chalk")

        settings.resetToDefaults()

        XCTAssertEqual(settings.shape, AppSettings.Defaults.shape)
        XCTAssertEqual(settings.anchor, AppSettings.Defaults.anchor)
        XCTAssertEqual(settings.sizeScale, AppSettings.Defaults.sizeScale)
        XCTAssertEqual(settings.displayDuration, AppSettings.Defaults.displayDuration, accuracy: 0.001)
        XCTAssertEqual(settings.edgeInset, AppSettings.Defaults.edgeInset, accuracy: 0.001)
        XCTAssertEqual(settings.showRepeatCount, AppSettings.Defaults.showRepeatCount)
        XCTAssertEqual(settings.colorSlots, AppSettings.Defaults.colorSlots)
    }

    func testDisplayDurationTextFormatsMillisecondsAndSeconds() {
        let settings = AppSettings.shared
        settings.displayDuration = 0.4
        XCTAssertTrue(settings.displayDurationText.contains("毫秒"))
        settings.displayDuration = 1.5
        XCTAssertTrue(settings.displayDurationText.contains("秒"))
    }

    // MARK: - 上台时序（长按驻留 / 松开才计时）

    func testPlainLetterNeverReachesOverlay() {
        let letter = KeyStroke(legend: KeyLegend(text: "a"), rawIdentifier: "a")
        KeyMonitor.shared.handlePress(KeyPress(stroke: letter, keyCode: 0))
        XCTAssertTrue(KeyMonitor.shared.activeStrokes.isEmpty, "字母不应上台")
    }

    func testHoldKeepsKeycapBeyondDisplayDuration() async throws {
        AppSettings.shared.displayDuration = 0.15

        let stroke = KeyStroke(legend: KeyLegend(text: "f5"), rawIdentifier: "f5", isSpecialKey: true)
        let monitor = KeyMonitor.shared
        monitor.handlePress(KeyPress(stroke: stroke, keyCode: 96))

        XCTAssertEqual(monitor.activeStrokes.count, 1)
        XCTAssertTrue(monitor.isHolding(strokeID: stroke.id), "按下后应处于长按驻留状态")

        // 远超停留时长仍不消失——因为按键还没松
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertTrue(
            monitor.activeStrokes.contains(where: { $0.id == stroke.id }),
            "按住不放时键帽必须持续驻留"
        )

        monitor.handleRelease(keyCode: 96)
        XCTAssertFalse(monitor.isHolding(strokeID: stroke.id))

        try await Task.sleep(nanoseconds: 450_000_000)
        XCTAssertFalse(
            monitor.activeStrokes.contains(where: { $0.id == stroke.id }),
            "松开后经过停留时长应淡出"
        )
    }

    func testFadeOccursOnlyAfterRelease() async throws {
        AppSettings.shared.displayDuration = 0.3

        let stroke = KeyStroke(legend: KeyLegend(text: "return"), rawIdentifier: "return", isSpecialKey: true)
        let monitor = KeyMonitor.shared
        monitor.handlePress(KeyPress(stroke: stroke, keyCode: 36))
        monitor.handleRelease(keyCode: 36)

        // 释放后的一半时长：仍应在场
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertTrue(monitor.activeStrokes.contains(where: { $0.id == stroke.id }))

        // 超过时长：淡出
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertFalse(monitor.activeStrokes.contains(where: { $0.id == stroke.id }))
    }

    func testModifierUpgradeHappensInPlace() throws {
        let monitor = KeyMonitor.shared

        let command = KeyStroke(
            legend: KeyModifier.command.legend,
            rawIdentifier: "command",
            isSpecialKey: true,
            isModifierOnly: true
        )
        monitor.handlePress(KeyPress(stroke: command, keyCode: 55))
        XCTAssertEqual(monitor.activeStrokes.count, 1)

        let originalID = try XCTUnwrap(monitor.activeStrokes.first?.id)

        let combo = KeyStroke(
            modifiers: [.command],
            legend: KeyLegend(text: "S"),
            rawIdentifier: "command+s"
        )
        monitor.handlePress(KeyPress(stroke: combo, keyCode: 1))

        // 就地生长：不新增卡片，且复用原 id
        XCTAssertEqual(monitor.activeStrokes.count, 1)
        XCTAssertEqual(monitor.activeStrokes.first?.id, originalID)
        XCTAssertEqual(monitor.activeStrokes.first?.legend.text, "S")
        XCTAssertEqual(monitor.activeStrokes.first?.modifiers, [.command])
    }

    func testRepeatCountMergesSameIdentifier() {
        AppSettings.shared.showRepeatCount = true
        let monitor = KeyMonitor.shared

        for _ in 0..<3 {
            let stroke = KeyStroke(
                modifiers: [.command],
                legend: KeyLegend(text: "C"),
                rawIdentifier: "command+c"
            )
            monitor.handlePress(KeyPress(stroke: stroke, keyCode: 8))
        }

        XCTAssertEqual(monitor.activeStrokes.count, 1, "连按应原地计数而不是堆卡片")
        XCTAssertEqual(monitor.activeStrokes.first?.repeatCount, 3)
    }

    func testRepeatCountDisabledKeepsSeparateGroups() {
        AppSettings.shared.showRepeatCount = false
        let monitor = KeyMonitor.shared

        for _ in 0..<2 {
            let stroke = KeyStroke(
                modifiers: [.command],
                legend: KeyLegend(text: "C"),
                rawIdentifier: "command+c"
            )
            monitor.handlePress(KeyPress(stroke: stroke, keyCode: 8))
        }

        XCTAssertEqual(monitor.activeStrokes.count, 2)
    }

    func testQueueRespectsCapacityLimit() {
        let monitor = KeyMonitor.shared
        for index in 0..<10 {
            let stroke = KeyStroke(
                legend: KeyLegend(text: "f\(index + 1)"),
                rawIdentifier: "f\(index + 1)",
                isSpecialKey: true
            )
            monitor.handlePress(KeyPress(stroke: stroke, keyCode: CGKeyCode(100 + index)))
        }
        XCTAssertLessThanOrEqual(monitor.activeStrokes.count, AppSettings.Defaults.maxVisibleGroups)
    }

    // MARK: - 视图冒烟

    func testKeycapGroupRendersInBothShapes() {
        let stroke = KeyStroke(
            modifiers: [.command, .shift],
            legend: KeyLegend(text: "S"),
            rawIdentifier: "command+shift+s"
        )

        for shape in KeycapShape.allCases {
            let view = KeycapGroupView(
                stroke: stroke,
                slots: AppSettings.Defaults.colorSlots,
                metrics: KeycapMetrics(height: 62),
                shape: shape,
                repeatCount: 2
            )
            let hosting = NSHostingView(rootView: view)
            hosting.layoutSubtreeIfNeeded()
            let size = hosting.fittingSize
            XCTAssertGreaterThan(size.width, 0, "\(shape.title) 应有非零宽度")
            XCTAssertGreaterThan(size.height, 0, "\(shape.title) 应有非零高度")
        }
    }

    func testPillIsShorterThanClassic() {
        let stroke = KeyStroke(modifiers: [.command], legend: KeyLegend(text: "S"), rawIdentifier: "command+s")
        let metrics = KeycapMetrics(height: 62)

        let classic = NSHostingView(rootView: KeycapGroupView(
            stroke: stroke, slots: AppSettings.Defaults.colorSlots, metrics: metrics, shape: .classic
        ))
        let pill = NSHostingView(rootView: KeycapGroupView(
            stroke: stroke, slots: AppSettings.Defaults.colorSlots, metrics: metrics, shape: .pill
        ))
        classic.layoutSubtreeIfNeeded()
        pill.layoutSubtreeIfNeeded()

        // 胶囊没有底板内边距与前唇，整体更矮
        XCTAssertLessThan(pill.fittingSize.height, classic.fittingSize.height)
    }

    func testPreferencesViewBuilds() {
        let hosting = NSHostingView(rootView: PreferencesView())
        hosting.frame = NSRect(x: 0, y: 0, width: 620, height: 720)
        hosting.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(hosting.fittingSize.width, 0)
    }
}
