//
//  AppSettings.swift
//  KeyGlow
//

import SwiftUI
import Combine

/// 全局应用配置与状态管理
@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    // MARK: - Keys for UserDefaults
    private enum Keys {
        static let isEnabled = "keyglow.isEnabled"
        static let displayMode = "keyglow.displayMode"
        static let keycapStyle = "keyglow.keycapStyle"
        static let anchor = "keyglow.anchor"
        static let displayDuration = "keyglow.displayDuration"
        static let sizeScale = "keyglow.sizeScale"
        static let showRepeatCount = "keyglow.showRepeatCount"
        static let specialKeyColor = "keyglow.specialKeyColor"
        static let keyColor = "keyglow.keyColor"
        static let modifierColor = "keyglow.modifierColor"
        static let escapeColor = "keyglow.escapeColor"
        static let borderColor = "keyglow.borderColor"
        static let keyOpacity = "keyglow.keyOpacity"
        static let verticalOffset = "keyglow.verticalOffset"
    }

    // MARK: - Published Properties

    @Published public var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled) }
    }

    @Published public var displayMode: DisplayMode {
        didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: Keys.displayMode) }
    }

    @Published public var keycapStyle: KeycapStyle {
        didSet { UserDefaults.standard.set(keycapStyle.rawValue, forKey: Keys.keycapStyle) }
    }

    @Published public var anchor: DisplayAnchor {
        didSet { UserDefaults.standard.set(anchor.rawValue, forKey: Keys.anchor) }
    }

    @Published public var specialKeyColor: SpecialKeyColor {
        didSet {
            UserDefaults.standard.set(specialKeyColor.rawValue, forKey: Keys.specialKeyColor)
        }
    }

    /// 普通字符/字母按键颜色（Key Color，参考 Keystroke Pro，默认 1984s Beige 复古米白）
    @Published public var keyColor: KeyColorOption {
        didSet { UserDefaults.standard.set(keyColor.rawValue, forKey: Keys.keyColor) }
    }

    /// 修饰键颜色（Modifier Color，如 ⌘ ⌥ ⌃ ⇧，默认 Azure Blue 蔚蓝）
    @Published public var modifierColor: KeyColorOption {
        didSet { UserDefaults.standard.set(modifierColor.rawValue, forKey: Keys.modifierColor) }
    }

    /// Escape 与特殊功能键颜色（Escape Color，默认 Mamba Green 曼巴绿）
    @Published public var escapeColor: KeyColorOption {
        didSet { UserDefaults.standard.set(escapeColor.rawValue, forKey: Keys.escapeColor) }
    }

    /// 边框高光与倒角轮廓描边颜色（Border Color，默认 Space 深空黑曜）
    @Published public var borderColor: BorderColorOption {
        didSet { UserDefaults.standard.set(borderColor.rawValue, forKey: Keys.borderColor) }
    }

    /// 键帽不透明度（Opacity，范围 0.5 ~ 1.0，默认 1.0 实体拟物）
    @Published public var keyOpacity: Double {
        didSet { UserDefaults.standard.set(keyOpacity, forKey: Keys.keyOpacity) }
    }

    @Published public var verticalOffset: Double {
        didSet { UserDefaults.standard.set(verticalOffset, forKey: Keys.verticalOffset) }
    }

    @Published public var displayDuration: Double {
        didSet { UserDefaults.standard.set(displayDuration, forKey: Keys.displayDuration) }
    }

    @Published public var sizeScale: Double {
        didSet { UserDefaults.standard.set(sizeScale, forKey: Keys.sizeScale) }
    }

    @Published public var showRepeatCount: Bool {
        didSet { UserDefaults.standard.set(showRepeatCount, forKey: Keys.showRepeatCount) }
    }

    /// 辅助功能权限状态
    @Published public var isAccessibilityGranted: Bool = false

    // MARK: - Initialization

    private init() {
        let defaults = UserDefaults.standard

        self.isEnabled = defaults.object(forKey: Keys.isEnabled) != nil ? defaults.bool(forKey: Keys.isEnabled) : true

        if let modeRaw = defaults.string(forKey: Keys.displayMode),
           let mode = DisplayMode(rawValue: modeRaw) {
            self.displayMode = mode
        } else {
            // 默认采用全按键模式，确保打字及单字母输入直接可见且不漏键
            self.displayMode = .allKeys
        }

        if let styleRaw = defaults.string(forKey: Keys.keycapStyle),
           let style = KeycapStyle(rawValue: styleRaw) {
            self.keycapStyle = style
        } else {
            self.keycapStyle = .classicDark
        }

        if let anchorRaw = defaults.string(forKey: Keys.anchor),
           let anchor = DisplayAnchor(rawValue: anchorRaw) {
            self.anchor = anchor
        } else {
            self.anchor = .bottomCenter
        }

        if let colorRaw = defaults.string(forKey: Keys.specialKeyColor),
           let color = SpecialKeyColor(rawValue: colorRaw) {
            self.specialKeyColor = color
        } else {
            self.specialKeyColor = .blue
        }

        // 初始化 Key Color（默认 1984s Beige）
        if let keyColorRaw = defaults.string(forKey: Keys.keyColor),
           let opt = KeyColorOption(rawValue: keyColorRaw) {
            self.keyColor = opt
        } else {
            self.keyColor = .beige1984
        }

        // 初始化 Modifier Color（默认 Azure Blue）
        if let modColorRaw = defaults.string(forKey: Keys.modifierColor),
           let opt = KeyColorOption(rawValue: modColorRaw) {
            self.modifierColor = opt
        } else {
            self.modifierColor = .azureBlue
        }

        // 初始化 Escape Color（默认 Mamba Green）
        if let escColorRaw = defaults.string(forKey: Keys.escapeColor),
           let opt = KeyColorOption(rawValue: escColorRaw) {
            self.escapeColor = opt
        } else {
            self.escapeColor = .mambaGreen
        }

        // 初始化 Border Color（默认 Space）
        if let borderRaw = defaults.string(forKey: Keys.borderColor),
           let opt = BorderColorOption(rawValue: borderRaw) {
            self.borderColor = opt
        } else {
            self.borderColor = .space
        }

        // 初始化 Key Opacity（默认 1.0）
        let opacityVal = defaults.double(forKey: Keys.keyOpacity)
        self.keyOpacity = opacityVal > 0 ? opacityVal : 1.0

        let duration = defaults.double(forKey: Keys.displayDuration)
        self.displayDuration = duration > 0 ? duration : 1.5

        let vOffset = defaults.double(forKey: Keys.verticalOffset)
        self.verticalOffset = vOffset > 0 ? vOffset : 70.0

        let scale = defaults.double(forKey: Keys.sizeScale)
        self.sizeScale = scale > 0 ? scale : 1.0

        self.showRepeatCount = defaults.object(forKey: Keys.showRepeatCount) != nil ? defaults.bool(forKey: Keys.showRepeatCount) : true

        checkAccessibility()
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
