//
//  OverlayPanelController.swift
//  KeyGlow
//

import AppKit
import Combine
import SwiftUI

/// 自定义无边框、无焦点、穿透悬浮层 NSPanel
public final class KeyGlowPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // 窗口浮层配置
        self.isFloatingPanel = true
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false

        // 鼠标穿透配置：保证完全不阻断用户在屏幕上的任何鼠标点击与手势操作
        self.ignoresMouseEvents = true

        // 多桌面 Spaces 与全屏应用驻留配置
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.hidesOnDeactivate = false
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}

/// 悬浮层控制器：负责管理窗口生命周期、屏幕锚点定位及显示
@MainActor
public final class OverlayPanelController: ObservableObject {
    public static let shared = OverlayPanelController()

    private var panel: KeyGlowPanel?
    private var cancellables = Set<AnyCancellable>()

    // 预留足够容纳最多 3 个键帽及阴影的固定画布尺寸，避免 Auto Layout 循环更新
    private let panelSize = CGSize(width: 720, height: 140)

    private init() {
        setupPanel()
        bindEvents()
    }

    // MARK: - 初始化 Panel

    private func setupPanel() {
        let initialRect = NSRect(origin: .zero, size: panelSize)
        let panel = KeyGlowPanel(contentRect: initialRect)

        let hostingController = NSHostingController(rootView: OverlayContentView())
        // 关键防护：禁用 NSHostingController 向 NSWindow 反向推送尺寸约束，防止 Update Constraints 死循环崩溃
        hostingController.sizingOptions = []
        hostingController.view.frame = initialRect
        hostingController.view.autoresizingMask = [.width, .height]

        panel.contentViewController = hostingController
        self.panel = panel
    }

    // MARK: - 监听按键事件并更新定位

    private func bindEvents() {
        KeyMonitor.shared.$activeStrokes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] strokes in
                guard let self = self else { return }
                if !strokes.isEmpty {
                    self.updatePosition()
                    self.panel?.orderFrontRegardless()
                }
            }
            .store(in: &cancellables)

        // 监听位置与偏移量设置变化，即时重算定位
        Publishers.CombineLatest(AppSettings.shared.$anchor, AppSettings.shared.$verticalOffset)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                guard let self = self else { return }
                self.updatePosition()
            }
            .store(in: &cancellables)
    }

    /// 根据当前配置的 Anchor 与当前屏幕/鼠标动态计算坐标
    public func updatePosition() {
        guard let panel = panel else { return }

        // 获取鼠标当前所在的显示器（多显示器环境自适应）
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first

        guard let screen = targetScreen else { return }

        let screenFrame = screen.visibleFrame
        let settings = AppSettings.shared
        let anchor = settings.anchor
        let vOffset = settings.verticalOffset
        var origin = CGPoint.zero

        switch anchor {
        case .bottomCenter:
            // 屏幕底部居中（自适应可调节上下距离）
            origin.x = screenFrame.midX - (panelSize.width / 2)
            origin.y = screenFrame.minY + vOffset

        case .bottomLeft:
            // 屏幕左下角（自适应可调节上下距离）
            origin.x = screenFrame.minX + 40
            origin.y = screenFrame.minY + vOffset

        case .bottomRight:
            // 屏幕右下角（自适应可调节上下距离）
            origin.x = screenFrame.maxX - panelSize.width - 40
            origin.y = screenFrame.minY + vOffset

        case .topCenter:
            // 屏幕顶部居中（自适应可调节上下距离）
            origin.x = screenFrame.midX - (panelSize.width / 2)
            origin.y = screenFrame.maxY - panelSize.height - vOffset

        case .mouseFollow:
            // 靠近鼠标光标动态跟随，并防止溢出当前屏幕
            var x = mouseLocation.x + 24
            var y = mouseLocation.y - (panelSize.height / 2)

            // 边缘保护校验
            if x + panelSize.width > screenFrame.maxX {
                x = mouseLocation.x - panelSize.width - 24
            }
            if y < screenFrame.minY {
                y = screenFrame.minY + 20
            } else if y + panelSize.height > screenFrame.maxY {
                y = screenFrame.maxY - panelSize.height - 20
            }

            origin = CGPoint(x: x, y: y)
        }

        let targetRect = NSRect(origin: origin, size: panelSize)
        // 仅在坐标或尺寸发生实质变化时调用 setFrame，避免触发不必要的重排
        if panel.frame != targetRect {
            panel.setFrame(targetRect, display: true)
        }
    }

    /// 隐藏悬浮窗
    public func hide() {
        panel?.orderOut(nil)
    }
}
