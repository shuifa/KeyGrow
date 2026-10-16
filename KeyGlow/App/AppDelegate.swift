//
//  AppDelegate.swift
//  KeyGlow
//

import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. 初始化菜单栏驻留
        MenuBarManager.shared.setup()

        // 2. 初始化悬浮窗控制器
        _ = OverlayPanelController.shared

        // 3. 启动键盘监听引擎
        KeyMonitor.shared.start()

        // 4. 首次启动若未获得辅助功能权限，自动引导展示偏好设置
        AppSettings.shared.checkAccessibility()
        if !AppSettings.shared.isAccessibilityGranted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                PreferencesWindowController.shared.showWindow()
                AppSettings.shared.requestAccessibilityPermission()
            }
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        KeyMonitor.shared.stop()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        PreferencesWindowController.shared.showWindow()
        return true
    }
}
