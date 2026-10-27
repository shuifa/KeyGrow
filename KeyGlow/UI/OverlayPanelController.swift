//
//  OverlayPanelController.swift
//  KeyGlow
//
//  悬浮窗管理。0.100 把「固定 720×140 画布 + 手算 5 个锚点坐标」换成了
//  **整屏可见区域 + SwiftUI 对齐**：窗口直接铺满 `screen.visibleFrame`，
//  8 个吸附点全部交给 SwiftUI 的 Alignment 完成，不再有任何魔法常量，
//  也不会出现「键帽变宽后被画布裁掉」的问题。
//

import AppKit
import Combine
import SwiftUI

/// 无边框、无焦点、完全穿透的悬浮层
public final class KeyGlowPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        // 与菜单栏同层，保证录屏时不被普通窗口遮挡
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // 鼠标手势 100% 穿透
        ignoresMouseEvents = true

        // 跨虚拟桌面、全屏应用常驻
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        isMovable = false
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}

/// 悬浮层控制器
@MainActor
public final class OverlayPanelController: ObservableObject {
    public static let shared = OverlayPanelController()

    private var panel: KeyGlowPanel?
    private var cancellables = Set<AnyCancellable>()
    private var hideTask: Task<Void, Never>?

    private init() {
        setupPanel()
        bindEvents()
    }

    // MARK: - 初始化

    private func setupPanel() {
        let initialRect = NSRect(origin: .zero, size: CGSize(width: 800, height: 200))
        let panel = KeyGlowPanel(contentRect: initialRect)

        let hostingController = NSHostingController(rootView: OverlayContentView())
        // 关键防护：禁止 NSHostingController 向 NSWindow 反向推送尺寸约束，
        // 否则「内容尺寸 → 窗口约束 → 内容尺寸」会形成 Auto Layout 递归死锁。
        hostingController.sizingOptions = []
        hostingController.view.frame = initialRect
        hostingController.view.autoresizingMask = [.width, .height]

        panel.contentViewController = hostingController
        self.panel = panel

        updateFrame()
    }

    // MARK: - 事件绑定

    private func bindEvents() {
        // 有按键上台：先定位（可能换了显示器）再显示
        KeyMonitor.shared.$activeStrokes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] strokes in
                guard let self, let panel = self.panel else { return }
                if strokes.isEmpty {
                    self.scheduleHide()
                } else {
                    self.hideTask?.cancel()
                    self.updateFrame()
                    panel.orderFrontRegardless()
                }
            }
            .store(in: &cancellables)

        // 位置 / 边距 / 尺寸变化即时重算（画布跟随可见区域，尺寸变化不影响窗口）
        Publishers.Merge(
            AppSettings.shared.$anchor.map { _ in () },
            AppSettings.shared.$edgeInset.map { _ in () }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in
            self?.updateFrame()
        }
        .store(in: &cancellables)

        // 显示器增删 / 分辨率切换
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateFrame()
            }
            .store(in: &cancellables)
    }

    // MARK: - 定位

    /// 以鼠标所在显示器为目标屏（多屏环境自适应），铺满其可见区域
    private func updateFrame() {
        guard let panel, let screen = targetScreen() else { return }
        let frame = screen.visibleFrame
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
        }
    }

    private func targetScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    /// 等离场动效播完（面板还要再显示 ~0.35s）再收起窗口
    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            self?.panel?.orderOut(nil)
        }
    }

    public func hide() {
        hideTask?.cancel()
        panel?.orderOut(nil)
    }
}
