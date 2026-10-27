//
//  AppSettings.swift
//  KeyGlow
//
//  全局配置。0.100 的信息架构完全重排，对齐 Keystroke Pro 的配置面：
//   通用：监听开关、连按角标、权限
//   外观：形态、尺寸、停留时长、四色槽
//   显示：8 个屏幕吸附点、边距
//
//  被移除的配置（同步删除，不做兼容保留）：
//   - themeID / appearanceMode：配色改由材质字典决定，不再有「主题 + 昼夜双档」概念；
//   - keyOpacity：原版键帽不透明，半透明会让材质分层失效；
//   - verticalOffset：并入 edgeInset，8 个锚点共用一套边距；
//   - maxVisibleKeys / showKeycapTray：队列上限与底板改为固定行为；
//   - 配置快照导入导出：材质 id 本身就是可分享的最小单位。
//

import AppKit
import Combine
import SwiftUI

/// 全局应用配置与状态管理
@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let isEnabled = "keyglow.isEnabled"
        static let shape = "keyglow.shape"
        static let anchor = "keyglow.anchor"
        static let sizeScale = "keyglow.sizeScale"
        static let displayDuration = "keyglow.displayDuration"
        static let edgeInset = "keyglow.edgeInset"
        static let showRepeatCount = "keyglow.showRepeatCount"
        static let slotEscape = "keyglow.slot.escape"
        static let slotModifier = "keyglow.slot.modifier"
        static let slotKey = "keyglow.slot.key"
        static let slotBorder = "keyglow.slot.border"
        static let schemaVersion = "keyglow.schemaVersion"

        /// 已下线配置项的 key，升级时一次性清除
        static let retiredKeys = [
            // 0.11 及以前的逐类配色（改由主题统一管理）
            "keyglow.specialKeyColor",
            "keyglow.keyColor",
            "keyglow.modifierColor",
            "keyglow.escapeColor",
            "keyglow.borderColor",
            // 0.2 移除的材质与显示模式
            "keyglow.keycapStyle",
            "keyglow.displayMode",
            // 0.100 移除的主题体系与旧排版参数
            "keyglow.themeID",
            "keyglow.appearanceMode",
            "keyglow.keyOpacity",
            "keyglow.verticalOffset",
            "keyglow.maxVisibleKeys",
            "keyglow.showKeycapTray"
        ]
    }

    /// 当前配置结构版本
    private static let currentSchemaVersion = 4

    // MARK: - 出厂默认值

    public enum Defaults {
        public static let isEnabled = true
        public static let shape: KeycapShape = .classic
        public static let anchor: DisplayAnchor = .bottomCenter
        /// 键帽高度基准（1u 键帽 62pt，与原版 Medium 档观感接近）
        public static let baseKeycapHeight: CGFloat = 62
        public static let sizeScale: Double = 1.0
        public static let sizeScaleRange: ClosedRange<Double> = 0.7...2.2
        /// 停留时长：原版推荐 1~2 秒
        public static let displayDuration: Double = 1.2
        public static let displayDurationRange: ClosedRange<Double> = 0.2...5.0
        public static let edgeInset: Double = 56
        public static let edgeInsetRange: ClosedRange<Double> = 8...240
        public static let showRepeatCount = true
        public static let colorSlots = KeycapColorSlots.defaults
        /// 同屏最多保留的键帽组数（不再暴露给用户，仅作为极端情况下的内存兜底）
        public static let maxVisibleGroups = 4
    }

    // MARK: - Published

    @Published public var isEnabled: Bool {
        didSet { schedulePersist() }
    }

    @Published public var shape: KeycapShape {
        didSet { schedulePersist() }
    }

    @Published public var anchor: DisplayAnchor {
        didSet { schedulePersist() }
    }

    /// 键帽尺寸倍率（0.7x ~ 2.2x，对应 1080p 紧凑到 4K 录制的超大键帽）
    ///
    /// Swift 不会递归触发同一属性的 `didSet`，因此钳位后必须继续往下写盘，
    /// 否则「被钳位的那一次赋值」永远不会落盘。
    @Published public var sizeScale: Double {
        didSet {
            let clamped = Self.clamp(sizeScale, to: Defaults.sizeScaleRange)
            if clamped != sizeScale { sizeScale = clamped }
            schedulePersist()
        }
    }

    /// 停留时长（秒）
    @Published public var displayDuration: Double {
        didSet {
            let clamped = Self.clamp(displayDuration, to: Defaults.displayDurationRange)
            if clamped != displayDuration { displayDuration = clamped }
            schedulePersist()
        }
    }

    /// 键帽组距屏幕边缘的距离
    @Published public var edgeInset: Double {
        didSet {
            let clamped = Self.clamp(edgeInset, to: Defaults.edgeInsetRange)
            if clamped != edgeInset { edgeInset = clamped }
            schedulePersist()
        }
    }

    /// 是否显示连按次数角标
    @Published public var showRepeatCount: Bool {
        didSet { schedulePersist() }
    }

    /// 四色槽（按键 / 修饰键 / Esc / 底板）
    @Published public var colorSlots: KeycapColorSlots {
        didSet { schedulePersist() }
    }

    /// 辅助功能权限状态（不持久化）
    @Published public var isAccessibilityGranted: Bool = false

    // MARK: - 派生

    /// 当前键帽几何规范
    public var metrics: KeycapMetrics {
        KeycapMetrics(height: Defaults.baseKeycapHeight * sizeScale)
    }

    /// 停留时长的人类可读描述（毫秒 / 秒自动切换）
    public var displayDurationText: String {
        displayDuration < 1
            ? String(format: "%.0f 毫秒", displayDuration * 1000)
            : String(format: "%.2f 秒", displayDuration)
    }

    // MARK: - 初始化

    private init() {
        let defaults = UserDefaults.standard
        Self.migrateIfNeeded(defaults)

        self.isEnabled = defaults.object(forKey: Keys.isEnabled) != nil
            ? defaults.bool(forKey: Keys.isEnabled)
            : Defaults.isEnabled

        self.shape = defaults.string(forKey: Keys.shape).flatMap(KeycapShape.init(rawValue:)) ?? Defaults.shape

        self.anchor = defaults.string(forKey: Keys.anchor).flatMap(DisplayAnchor.init(rawValue:)) ?? Defaults.anchor

        let scale = defaults.double(forKey: Keys.sizeScale)
        self.sizeScale = scale > 0 ? Self.clamp(scale, to: Defaults.sizeScaleRange) : Defaults.sizeScale

        let duration = defaults.double(forKey: Keys.displayDuration)
        self.displayDuration = duration > 0 ? Self.clamp(duration, to: Defaults.displayDurationRange) : Defaults.displayDuration

        let inset = defaults.double(forKey: Keys.edgeInset)
        self.edgeInset = inset > 0 ? Self.clamp(inset, to: Defaults.edgeInsetRange) : Defaults.edgeInset

        self.showRepeatCount = defaults.object(forKey: Keys.showRepeatCount) != nil
            ? defaults.bool(forKey: Keys.showRepeatCount)
            : Defaults.showRepeatCount

        let storedSlots = KeycapColorSlots(
            escape: defaults.string(forKey: Keys.slotEscape) ?? Defaults.colorSlots.escape,
            modifier: defaults.string(forKey: Keys.slotModifier) ?? Defaults.colorSlots.modifier,
            key: defaults.string(forKey: Keys.slotKey) ?? Defaults.colorSlots.key,
            border: defaults.string(forKey: Keys.slotBorder) ?? Defaults.colorSlots.border
        )
        // 旧配置里可能出现已下线的材质 id，这里统一归位到合法材质
        self.colorSlots = storedSlots.normalized()

        checkAccessibility()
    }

    // MARK: - 持久化（合并写盘，避免拖动滑块时逐帧写 UserDefaults）

    private var persistTask: Task<Void, Never>?

    private func schedulePersist() {
        persistTask?.cancel()
        persistTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.persistNow()
        }
    }

    /// 立即写盘（测试、恢复默认等需要确定性落盘的场景调用）
    public func persistNow() {
        persistTask?.cancel()
        persistTask = nil

        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: Keys.isEnabled)
        defaults.set(shape.rawValue, forKey: Keys.shape)
        defaults.set(anchor.rawValue, forKey: Keys.anchor)
        defaults.set(sizeScale, forKey: Keys.sizeScale)
        defaults.set(displayDuration, forKey: Keys.displayDuration)
        defaults.set(edgeInset, forKey: Keys.edgeInset)
        defaults.set(showRepeatCount, forKey: Keys.showRepeatCount)
        defaults.set(colorSlots.escape, forKey: Keys.slotEscape)
        defaults.set(colorSlots.modifier, forKey: Keys.slotModifier)
        defaults.set(colorSlots.key, forKey: Keys.slotKey)
        defaults.set(colorSlots.border, forKey: Keys.slotBorder)
        defaults.set(Self.currentSchemaVersion, forKey: Keys.schemaVersion)
    }

    // MARK: - 迁移

    private static func migrateIfNeeded(_ defaults: UserDefaults) {
        let schema = defaults.integer(forKey: Keys.schemaVersion)
        guard schema < currentSchemaVersion else { return }

        // 0.100：主题 / 外观模式 / 不透明度 / 垂直偏移 / 队列上限 / 托盘全部下线，
        // 配色改由四色槽 + 材质字典承载
        for key in Keys.retiredKeys {
            defaults.removeObject(forKey: key)
        }
        defaults.set(currentSchemaVersion, forKey: Keys.schemaVersion)
    }

    // MARK: - 恢复默认

    public func resetToDefaults() {
        isEnabled = Defaults.isEnabled
        shape = Defaults.shape
        anchor = Defaults.anchor
        sizeScale = Defaults.sizeScale
        displayDuration = Defaults.displayDuration
        edgeInset = Defaults.edgeInset
        showRepeatCount = Defaults.showRepeatCount
        colorSlots = Defaults.colorSlots
        persistNow()
    }

    // MARK: - 权限

    public func checkAccessibility() {
        self.isAccessibilityGranted = AXIsProcessTrusted()
    }

    public func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        checkAccessibility()
    }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 工具

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
