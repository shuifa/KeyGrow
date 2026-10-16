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
        didSet { UserDefaults.standard.set(specialKeyColor.rawValue, forKey: Keys.specialKeyColor) }
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
            self.displayMode = .shortcutsOnly
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

        let duration = defaults.double(forKey: Keys.displayDuration)
        self.displayDuration = duration > 0 ? duration : 1.5

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
