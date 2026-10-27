//
//  PreferencesWindowController.swift
//  KeyGlow
//
//  偏好设置窗口控制器。
//
//  0.100 起窗口自身不再绑定外观模式：配色由材质字典决定，
//  没有任何「跟随系统 / 强制浅色 / 强制深色」的开关，
//  窗口外观完全交给系统，避免出现「窗口是深色但键帽是浅铝」的割裂感。
//

import AppKit
import SwiftUI

@MainActor
public final class PreferencesWindowController {
    public static let shared = PreferencesWindowController()

    private var window: NSWindow?

    /// 与 PreferencesView 内部布局保持一致的内容最小尺寸
    private let contentSize = NSSize(width: 620, height: 720)

    private init() {}

    public func showWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: PreferencesView())

        let window = NSWindow(contentViewController: hostingController)
        window.title = "KeyGlow 偏好设置"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.contentMinSize = contentSize
        window.setContentSize(contentSize)
        window.isReleasedWhenClosed = false
        window.center()

        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
