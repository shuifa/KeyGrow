//
//  MenuBarManager.swift
//  KeyGlow
//

import AppKit
import Combine

/// 菜单栏常驻图标与交互菜单管理器
@MainActor
public final class MenuBarManager: NSObject, NSMenuDelegate {
    public static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
    }

    public func setup() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyGlow")?.withSymbolConfiguration(config)
            button.imagePosition = .imageOnly
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        self.statusItem = statusItem

        rebuildMenu()

        // 监听设置变化时更新菜单状态
        AppSettings.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
    }

    // MARK: - 构建菜单结构

    public func rebuildMenu() {
        guard let menu = statusItem?.menu else { return }
        menu.removeAllItems()

        let settings = AppSettings.shared

        // 1. 标题与状态
        let titleItem = NSMenuItem(title: "KeyGlow 键盘可视化", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // 2. 启用/暂停监听
        let toggleTitle = settings.isEnabled ? "监听状态：开启中" : "监听状态：已暂停"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = settings.isEnabled ? .on : .off
        toggleItem.image = NSImage(systemSymbolName: settings.isEnabled ? "bolt.fill" : "bolt.slash.fill", accessibilityDescription: nil)
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // 3. 显示模式切换
        let modeMenu = NSMenu()
        for mode in DisplayMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectDisplayMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            item.state = settings.displayMode == mode ? .on : .off
            modeMenu.addItem(item)
        }
        let modeSubmenuItem = NSMenuItem(title: "显示模式", action: nil, keyEquivalent: "")
        modeSubmenuItem.submenu = modeMenu
        modeSubmenuItem.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: nil)
        menu.addItem(modeSubmenuItem)

        // 4. 特殊按键强调配色切换（Keystroke Pro 经典体验）
        let colorMenu = NSMenu()
        for color in SpecialKeyColor.allCases {
            let item = NSMenuItem(title: color.title, action: #selector(selectSpecialKeyColor(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = color
            item.state = settings.specialKeyColor == color ? .on : .off
            colorMenu.addItem(item)
        }
        let colorSubmenuItem = NSMenuItem(title: "按键配色", action: nil, keyEquivalent: "")
        colorSubmenuItem.submenu = colorMenu
        colorSubmenuItem.image = NSImage(systemSymbolName: "circle.circle", accessibilityDescription: nil)
        menu.addItem(colorSubmenuItem)

        // 5. 视觉主题风格切换
        let styleMenu = NSMenu()
        for style in KeycapStyle.allCases {
            let item = NSMenuItem(title: style.title, action: #selector(selectKeycapStyle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style
            item.state = settings.keycapStyle == style ? .on : .off
            styleMenu.addItem(item)
        }
        let styleSubmenuItem = NSMenuItem(title: "键帽质感", action: nil, keyEquivalent: "")
        styleSubmenuItem.submenu = styleMenu
        styleSubmenuItem.image = NSImage(systemSymbolName: "paintpalette", accessibilityDescription: nil)
        menu.addItem(styleSubmenuItem)

        // 6. 显示位置切换（含左下角、右下角）
        let anchorMenu = NSMenu()
        for anchor in DisplayAnchor.allCases {
            let item = NSMenuItem(title: anchor.title, action: #selector(selectAnchor(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = anchor
            item.state = settings.anchor == anchor ? .on : .off
            anchorMenu.addItem(item)
        }
        let anchorSubmenuItem = NSMenuItem(title: "屏幕位置", action: nil, keyEquivalent: "")
        anchorSubmenuItem.submenu = anchorMenu
        anchorSubmenuItem.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: nil)
        menu.addItem(anchorSubmenuItem)

        menu.addItem(NSMenuItem.separator())

        // 7. 偏好设置
        let prefsItem = NSMenuItem(title: "偏好设置...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        prefsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(prefsItem)

        // 8. 权限引导
        let permTitle = settings.isAccessibilityGranted ? "辅助功能权限 (已授权)" : "检查辅助功能权限..."
        let permItem = NSMenuItem(title: permTitle, action: #selector(checkPermission), keyEquivalent: "")
        permItem.target = self
        permItem.image = NSImage(systemSymbolName: settings.isAccessibilityGranted ? "checkmark.circle" : "exclamationmark.triangle", accessibilityDescription: nil)
        menu.addItem(permItem)

        menu.addItem(NSMenuItem.separator())

        // 9. 退出
        let quitItem = NSMenuItem(title: "退出 KeyGlow", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        AppSettings.shared.isEnabled.toggle()
        rebuildMenu()
    }

    @objc private func selectDisplayMode(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? DisplayMode {
            AppSettings.shared.displayMode = mode
            rebuildMenu()
        }
    }

    @objc private func selectSpecialKeyColor(_ sender: NSMenuItem) {
        if let color = sender.representedObject as? SpecialKeyColor {
            AppSettings.shared.specialKeyColor = color
            rebuildMenu()
        }
    }

    @objc private func selectKeycapStyle(_ sender: NSMenuItem) {
        if let style = sender.representedObject as? KeycapStyle {
            AppSettings.shared.keycapStyle = style
            rebuildMenu()
        }
    }

    @objc private func selectAnchor(_ sender: NSMenuItem) {
        if let anchor = sender.representedObject as? DisplayAnchor {
            AppSettings.shared.anchor = anchor
            rebuildMenu()
        }
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.showWindow()
    }

    @objc private func checkPermission() {
        if !AppSettings.shared.isAccessibilityGranted {
            AppSettings.shared.openAccessibilitySettings()
        } else {
            PreferencesWindowController.shared.showWindow()
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    public func menuWillOpen(_ menu: NSMenu) {
        AppSettings.shared.checkAccessibility()
        rebuildMenu()
    }
}
