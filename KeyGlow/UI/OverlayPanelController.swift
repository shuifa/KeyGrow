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

/// 悬浮层控制器：负责管理窗口生命周期、屏幕锚点定位、外观模式与显示
@MainActor
public final class OverlayPanelController: ObservableObject {
    public static let shared = OverlayPanelController()

    private var panel: KeyGlowPanel?
    private var cancellables = Set<AnyCancellable>()

    // 预留足够容纳最多 4 个键帽及阴影的固定画布尺寸，避免 Auto Layout 循环更新
    private let panelSize = CGSize(width: 720, height: 140)

    /// 跟随鼠标时，键帽内容中心相对光标的水平偏移量。
    /// 面板宽度固定为 720 且内容居中，因此这里用「中心偏移」而非「左上角偏移」，
    /// 才能保证无论当前有几个键帽，键帽都紧贴光标而不是偏到半屏之外。
    private let mouseFollowCenterOffset: CGFloat = 70

    private init() {
        setupPanel()
        bindEvents()
        applyAppearanceMode()
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
                self?.updatePosition()
            }
            .store(in: &cancellables)

        // 外观模式变化即时生效（跟随系统 / 固定浅色 / 固定深色）
        AppSettings.shared.$appearanceMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyAppearanceMode()
            }
            .store(in: &cancellables)
    }

    /// 把用户选择的外观模式作用到悬浮窗上。
    /// 关键点：设为 nil 时窗口会继承系统外观，SwiftUI 的 `colorScheme` 环境值随之变化，
    /// 主题的白天/夜晚配色即自动切换。
    private func applyAppearanceMode() {
        panel?.appearance = AppSettings.shared.appearanceMode.nsAppearance
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
            // 键帽中心贴住光标右侧（而非面板左上角对齐，避免 720pt 画布造成的整屏偏移）
            let halfWidth = panelSize.width / 2
            var centerX = mouseLocation.x + mouseFollowCenterOffset
            if centerX + halfWidth > screenFrame.maxX {
                // 右侧空间不足时翻转到光标左侧
                centerX = mouseLocation.x - mouseFollowCenterOffset
            }
            centerX = min(max(centerX, screenFrame.minX + halfWidth), screenFrame.maxX - halfWidth)

            var y = mouseLocation.y - (panelSize.height / 2)
            y = min(max(y, screenFrame.minY + 20), screenFrame.maxY - panelSize.height - 20)

            origin = CGPoint(x: centerX - halfWidth, y: y)
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
