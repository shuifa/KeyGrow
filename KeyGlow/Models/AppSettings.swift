//
//  AppSettings.swift
//  KeyGlow
//

import SwiftUI
import Combine

/// 全局应用配置与状态管理
///
/// 0.2 起配置面收窄：材质与显示模式两项设置已移除——
/// 材质收敛为唯一实现，显示模式固定为「全按键」，两者都不再是用户可调项。
@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    // MARK: - Keys for UserDefaults
    private enum Keys {
        static let isEnabled = "keyglow.isEnabled"
        static let anchor = "keyglow.anchor"
        static let displayDuration = "keyglow.displayDuration"
        static let sizeScale = "keyglow.sizeScale"
        static let showRepeatCount = "keyglow.showRepeatCount"
        static let keyOpacity = "keyglow.keyOpacity"
        static let verticalOffset = "keyglow.verticalOffset"
        static let themeID = "keyglow.themeID"
        static let appearanceMode = "keyglow.appearanceMode"
        static let maxVisibleKeys = "keyglow.maxVisibleKeys"
        static let showKeycapTray = "keyglow.showKeycapTray"
        static let schemaVersion = "keyglow.schemaVersion"

        /// 已下线配置项的 key，升级时一次性清除
        static let retiredKeys = [
            // 0.11 及以前的逐类配色
            "keyglow.specialKeyColor",
            "keyglow.keyColor",
            "keyglow.modifierColor",
            "keyglow.escapeColor",
            "keyglow.borderColor",
            // 0.2 移除的材质与显示模式
            "keyglow.keycapStyle",
            "keyglow.displayMode"
        ]
    }

    /// 当前配置结构版本，用于后续增量迁移
    private static let currentSchemaVersion = 3

    // MARK: - Published Properties

    @Published public var isEnabled: Bool {
        didSet { schedulePersist() }
    }

    @Published public var anchor: DisplayAnchor {
        didSet { schedulePersist() }
    }

    /// 当前主题 id
    @Published public var themeID: String {
        didSet { schedulePersist() }
    }

    /// 外观模式：跟随系统 / 固定浅色 / 固定深色
    @Published public var appearanceMode: ThemeAppearanceMode {
        didSet { schedulePersist() }
    }

    /// 键帽不透明度（0.5 ~ 1.0）
    @Published public var keyOpacity: Double {
        didSet { schedulePersist() }
    }

    @Published public var verticalOffset: Double {
        didSet { schedulePersist() }
    }

    @Published public var displayDuration: Double {
        didSet { schedulePersist() }
    }

    @Published public var sizeScale: Double {
        didSet { schedulePersist() }
    }

    @Published public var showRepeatCount: Bool {
        didSet { schedulePersist() }
    }

    /// 同屏最多保留的键帽数量（1 ~ 4）
    @Published public var maxVisibleKeys: Int {
        didSet {
            let range = Self.Defaults.maxVisibleKeysRange
            let clamped = min(max(maxVisibleKeys, range.lowerBound), range.upperBound)
            if clamped != maxVisibleKeys {
                maxVisibleKeys = clamped
            }
        }
    }

    /// 是否为键帽加一层半透明托盘，提升浅色桌面下的对比度
    @Published public var showKeycapTray: Bool {
        didSet { schedulePersist() }
    }

    /// 辅助功能权限状态（不持久化）
    @Published public var isAccessibilityGranted: Bool = false

    // MARK: - 派生属性

    /// 当前主题对象（id 无效时自动回退默认主题）
    public var theme: KeycapTheme {
        KeycapTheme.theme(id: themeID)
    }

    /// 出厂默认配置（集中定义，避免初始化分支散落魔法值，也便于测试校验）
    public enum Defaults {
        public static let isEnabled = true
        public static let anchor: DisplayAnchor = .bottomCenter
        public static let themeID = KeycapTheme.defaultTheme.id
        public static let appearanceMode: ThemeAppearanceMode = .system
        public static let keyOpacity: Double = 1.0
        public static let displayDuration: Double = 1.5
        public static let verticalOffset: Double = 70.0
        public static let sizeScale: Double = 1.0
        public static let showRepeatCount = true
        public static let maxVisibleKeys = 3
        public static let maxVisibleKeysRange = 1...4
        public static let showKeycapTray = false
    }

    // MARK: - Initialization

    private init() {
        let defaults = UserDefaults.standard
        Self.migrateIfNeeded(defaults)

        self.isEnabled = defaults.object(forKey: Keys.isEnabled) != nil ? defaults.bool(forKey: Keys.isEnabled) : Defaults.isEnabled

        if let anchorRaw = defaults.string(forKey: Keys.anchor),
           let anchor = DisplayAnchor(rawValue: anchorRaw) {
            self.anchor = anchor
        } else {
            self.anchor = Defaults.anchor
        }

        // 主题 id：旧版本没有该 key、或存的是已下线的主题，统一交给 `resolvedID` 解析，
        // 解析不了才回退默认主题
        if let storedTheme = defaults.string(forKey: Keys.themeID) {
            self.themeID = KeycapTheme.resolvedID(storedTheme)
        } else {
            self.themeID = Defaults.themeID
        }

        if let appearanceRaw = defaults.string(forKey: Keys.appearanceMode),
           let mode = ThemeAppearanceMode(rawValue: appearanceRaw) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = Defaults.appearanceMode
        }

        let opacityVal = defaults.double(forKey: Keys.keyOpacity)
        self.keyOpacity = opacityVal > 0 ? min(max(opacityVal, 0.5), 1.0) : Defaults.keyOpacity

        let duration = defaults.double(forKey: Keys.displayDuration)
        self.displayDuration = duration > 0 ? duration : Defaults.displayDuration

        let vOffset = defaults.double(forKey: Keys.verticalOffset)
        self.verticalOffset = vOffset > 0 ? vOffset : Defaults.verticalOffset

        let scale = defaults.double(forKey: Keys.sizeScale)
        self.sizeScale = scale > 0 ? scale : Defaults.sizeScale

        self.showRepeatCount = defaults.object(forKey: Keys.showRepeatCount) != nil
            ? defaults.bool(forKey: Keys.showRepeatCount)
            : Defaults.showRepeatCount

        let visible = defaults.integer(forKey: Keys.maxVisibleKeys)
        self.maxVisibleKeys = Defaults.maxVisibleKeysRange.contains(visible) ? visible : Defaults.maxVisibleKeys

        self.showKeycapTray = defaults.object(forKey: Keys.showKeycapTray) != nil
            ? defaults.bool(forKey: Keys.showKeycapTray)
            : Defaults.showKeycapTray

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

    /// 立即写盘（测试、导入、恢复默认等需要确定性落盘的场景调用）
    public func persistNow() {
        persistTask?.cancel()
        persistTask = nil

        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: Keys.isEnabled)
        defaults.set(anchor.rawValue, forKey: Keys.anchor)
        defaults.set(themeID, forKey: Keys.themeID)
        defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode)
        defaults.set(keyOpacity, forKey: Keys.keyOpacity)
        defaults.set(verticalOffset, forKey: Keys.verticalOffset)
        defaults.set(displayDuration, forKey: Keys.displayDuration)
        defaults.set(sizeScale, forKey: Keys.sizeScale)
        defaults.set(showRepeatCount, forKey: Keys.showRepeatCount)
        defaults.set(maxVisibleKeys, forKey: Keys.maxVisibleKeys)
        defaults.set(showKeycapTray, forKey: Keys.showKeycapTray)
        defaults.set(Self.currentSchemaVersion, forKey: Keys.schemaVersion)
    }

    // MARK: - 迁移

    private static func migrateIfNeeded(_ defaults: UserDefaults) {
        let schema = defaults.integer(forKey: Keys.schemaVersion)
        guard schema < currentSchemaVersion else { return }

        // 0.11 → 0.12：逐类配色废弃，改由主题统一管理
        // 0.2  → 追加：材质与显示模式下线
        for key in Keys.retiredKeys {
            defaults.removeObject(forKey: key)
        }
        defaults.set(currentSchemaVersion, forKey: Keys.schemaVersion)
    }

    // MARK: - 恢复默认 / 配置快照

    /// 恢复全部出厂设置
    public func resetToDefaults() {
        isEnabled = Defaults.isEnabled
        anchor = Defaults.anchor
        themeID = Defaults.themeID
        appearanceMode = Defaults.appearanceMode
        keyOpacity = Defaults.keyOpacity
        verticalOffset = Defaults.verticalOffset
        displayDuration = Defaults.displayDuration
        sizeScale = Defaults.sizeScale
        showRepeatCount = Defaults.showRepeatCount
        maxVisibleKeys = Defaults.maxVisibleKeys
        showKeycapTray = Defaults.showKeycapTray
        persistNow()
    }

    /// 导出当前配置（JSON 可分享给他人）
    public func makeSnapshot() -> SettingsSnapshot {
        SettingsSnapshot(
            themeID: themeID,
            appearanceMode: appearanceMode,
            anchor: anchor,
            displayDuration: displayDuration,
            sizeScale: sizeScale,
            showRepeatCount: showRepeatCount,
            keyOpacity: keyOpacity,
            verticalOffset: verticalOffset,
            maxVisibleKeys: maxVisibleKeys,
            showKeycapTray: showKeycapTray,
            isEnabled: isEnabled
        )
    }

    /// 应用外部导入的配置（字段缺失时保留当前值）
    public func apply(_ snapshot: SettingsSnapshot) {
        if let id = snapshot.themeID { themeID = KeycapTheme.resolvedID(id) }
        if let mode = snapshot.appearanceMode { appearanceMode = mode }
        if let anchor = snapshot.anchor { self.anchor = anchor }
        if let duration = snapshot.displayDuration { displayDuration = min(max(duration, 0.5), 3.0) }
        if let scale = snapshot.sizeScale { sizeScale = min(max(scale, 0.6), 1.8) }
        if let showRepeat = snapshot.showRepeatCount { showRepeatCount = showRepeat }
        if let opacity = snapshot.keyOpacity { keyOpacity = min(max(opacity, 0.5), 1.0) }
        if let offset = snapshot.verticalOffset { verticalOffset = min(max(offset, 20), 220) }
        if let visible = snapshot.maxVisibleKeys, Defaults.maxVisibleKeysRange.contains(visible) {
            maxVisibleKeys = visible
        }
        if let tray = snapshot.showKeycapTray { showKeycapTray = tray }
        if let enabled = snapshot.isEnabled { isEnabled = enabled }
        persistNow()
    }

    // MARK: - Accessibility Permission

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
}

// MARK: - 配置快照

/// 可序列化的配置快照：支持导出 / 导入，用于分享主题与整套参数。
/// 旧版本导出的 JSON 里多出的 `keycapStyle` / `displayMode` 字段会被解码器自动忽略，导入不会失败。
public struct SettingsSnapshot: Codable, Equatable, Sendable {
    public var themeID: String?
    public var appearanceMode: ThemeAppearanceMode?
    public var anchor: DisplayAnchor?
    public var displayDuration: Double?
    public var sizeScale: Double?
    public var showRepeatCount: Bool?
    public var keyOpacity: Double?
    public var verticalOffset: Double?
    public var maxVisibleKeys: Int?
    public var showKeycapTray: Bool?
    public var isEnabled: Bool?

    public init(
        themeID: String? = nil,
        appearanceMode: ThemeAppearanceMode? = nil,
        anchor: DisplayAnchor? = nil,
        displayDuration: Double? = nil,
        sizeScale: Double? = nil,
        showRepeatCount: Bool? = nil,
        keyOpacity: Double? = nil,
        verticalOffset: Double? = nil,
        maxVisibleKeys: Int? = nil,
        showKeycapTray: Bool? = nil,
        isEnabled: Bool? = nil
    ) {
        self.themeID = themeID
        self.appearanceMode = appearanceMode
        self.anchor = anchor
        self.displayDuration = displayDuration
        self.sizeScale = sizeScale
        self.showRepeatCount = showRepeatCount
        self.keyOpacity = keyOpacity
        self.verticalOffset = verticalOffset
        self.maxVisibleKeys = maxVisibleKeys
        self.showKeycapTray = showKeycapTray
        self.isEnabled = isEnabled
    }

    public func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> SettingsSnapshot {
        try JSONDecoder().decode(SettingsSnapshot.self, from: data)
    }
}
