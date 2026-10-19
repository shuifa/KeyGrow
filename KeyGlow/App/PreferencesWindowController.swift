//
//  PreferencesWindowController.swift
//  KeyGlow
//

import AppKit
import SwiftUI

/// 偏好设置窗口控制器
@MainActor
public final class PreferencesWindowController {
    public static let shared = PreferencesWindowController()

    private var window: NSWindow?

    private init() {}

    public func showWindow() {
        if let window = self.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let preferencesView = PreferencesView()
        let hostingController = NSHostingController(rootView: preferencesView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "KeyGlow 偏好设置"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 480, height: 500)
        window.isReleasedWhenClosed = false
        window.center()

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
