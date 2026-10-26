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

        updateIcon()
        rebuildMenu()

        // 仅在「启用状态」变化时刷新图标；其余设置变化不再引起菜单重建，
        // 避免拖动滑块时每帧重建整个 NSMenu（此前的性能与闪烁问题）。
        AppSettings.shared.$isEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateIcon()
            }
            .store(in: &cancellables)
    }

    /// 菜单栏图标反映监听状态：暂停时整体变灰，一眼可辨
    private func updateIcon() {
        statusItem?.button?.appearsDisabled = !AppSettings.shared.isEnabled
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

        // 3. 主题（一整套七档配色，含白天 / 夜晚两档）
        let themeMenu = NSMenu()
        for theme in KeycapTheme.all {
            let item = NSMenuItem(title: theme.name, action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme.id
            item.state = settings.themeID == theme.id ? .on : .off
            themeMenu.addItem(item)
        }
        let themeSubmenuItem = NSMenuItem(title: "配色主题", action: nil, keyEquivalent: "")
        themeSubmenuItem.submenu = themeMenu
        themeSubmenuItem.image = NSImage(systemSymbolName: "paintpalette", accessibilityDescription: nil)
        menu.addItem(themeSubmenuItem)

        // 4. 外观模式（跟随系统 / 浅色 / 深色）
        let appearanceMenu = NSMenu()
        for mode in ThemeAppearanceMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectAppearanceMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            item.state = settings.appearanceMode == mode ? .on : .off
            item.image = NSImage(systemSymbolName: mode.iconName, accessibilityDescription: nil)
            appearanceMenu.addItem(item)
        }
        let appearanceSubmenuItem = NSMenuItem(title: "外观模式", action: nil, keyEquivalent: "")
        appearanceSubmenuItem.submenu = appearanceMenu
        appearanceSubmenuItem.image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: nil)
        menu.addItem(appearanceSubmenuItem)

        // 5. 显示位置切换
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

        // 8. 偏好设置
        let prefsItem = NSMenuItem(title: "偏好设置...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        prefsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(prefsItem)

        // 9. 权限引导
        let permTitle = settings.isAccessibilityGranted ? "辅助功能权限 (已授权)" : "检查辅助功能权限..."
        let permItem = NSMenuItem(title: permTitle, action: #selector(checkPermission), keyEquivalent: "")
        permItem.target = self
        permItem.image = NSImage(systemSymbolName: settings.isAccessibilityGranted ? "checkmark.circle" : "exclamationmark.triangle", accessibilityDescription: nil)
        menu.addItem(permItem)

        menu.addItem(NSMenuItem.separator())

        // 10. 退出
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

    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let themeID = sender.representedObject as? String else { return }
        AppSettings.shared.themeID = themeID
        rebuildMenu()
    }

    @objc private func selectAppearanceMode(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? ThemeAppearanceMode {
            AppSettings.shared.appearanceMode = mode
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
