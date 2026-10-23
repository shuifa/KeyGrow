//
//  PreferencesWindowController.swift
//  KeyGlow
//

import AppKit
import Combine
import SwiftUI

/// 偏好设置窗口控制器
@MainActor
public final class PreferencesWindowController {
    public static let shared = PreferencesWindowController()

    private var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    /// 与 PreferencesView 内部布局保持一致的内容最小尺寸
    private let contentSize = NSSize(width: 580, height: 700)

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
        // 最小尺寸与内容一致（旧版本最小尺寸小于内容，导致缩小时被裁切）
        window.contentMinSize = contentSize
        window.setContentSize(contentSize)
        window.isReleasedWhenClosed = false
        window.center()
        window.appearance = AppSettings.shared.appearanceMode.nsAppearance

        self.window = window

        // 外观模式变化时，设置窗口本身也同步切换，预览才与悬浮层一致
        AppSettings.shared.$appearanceMode
            .receive(on: DispatchQueue.main)
            .sink { [weak window] mode in
                window?.appearance = mode.nsAppearance
            }
            .store(in: &cancellables)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
