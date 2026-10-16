//
//  KeyMonitor.swift
//  KeyGlow
//

import AppKit
import Carbon
import Combine
import CoreGraphics
import SwiftUI

/// 后台全局键盘事件监听与派发引擎
@MainActor
public final class KeyMonitor: ObservableObject {
    public static let shared = KeyMonitor()

    /// 当前处于展示生命周期内的连续按键队列（最多 3 个）
    @Published public private(set) var activeStrokes: [KeyStroke] = []

    /// 最新按下的按键（兼容性快捷访问）
    public var currentStroke: KeyStroke? { activeStrokes.last }

    /// 动效触发计数器（每次按键递增，用于驱动 Spring 冲击振颤）
    @Published public private(set) var punchTrigger: Int = 0

    /// 是否正在监听中
    @Published public private(set) var isMonitoring: Bool = false

    private var worker: KeyMonitorWorker?

    private init() {}

    /// 启动全局监听
    public func start() {
        guard !isMonitoring else { return }

        // 检查辅助功能权限
        let trusted = AXIsProcessTrusted()
        AppSettings.shared.checkAccessibility()

        if !trusted {
            // 未授权时静默等待，不阻碍主界面
            print("[KeyMonitor] Accessibility permission not yet granted.")
        }

        let worker = KeyMonitorWorker(
            onKeyStroke: { [weak self] stroke in
                self?.didReceiveKeyStroke(stroke)
            },
            onModifiersReleased: { [weak self] in
                self?.didReleaseModifiers()
            }
        )
        self.worker = worker
        worker.start()
        self.isMonitoring = true
    }

    /// 停止全局监听
    public func stop() {
        worker?.stop()
        worker = nil
        isMonitoring = false
        activeStrokes.removeAll()
        isCurrentStrokeActiveModifier = false
    }

    /// 清空当前按键展示
    public func clearStroke() {
        activeStrokes.removeAll()
        isCurrentStrokeActiveModifier = false
    }

    /// 模拟按键（用于偏好设置预览及测试）
    public func simulateKeyStroke(_ stroke: KeyStroke) {
        didReceiveKeyStroke(stroke)
    }

    /// 模拟修饰键松开（用于测试）
    public func simulateModifierRelease() {
        didReleaseModifiers()
    }

    // MARK: - 按键派发（队列最大 3 个，先进先出）

    /// 标记当前最新展示的按键是否是“尚未松开的纯修饰键”
    private var isCurrentStrokeActiveModifier: Bool = false

    private func didReleaseModifiers() {
        self.isCurrentStrokeActiveModifier = false
    }

    private func didReceiveKeyStroke(_ newStroke: KeyStroke) {
        guard AppSettings.shared.isEnabled else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            if self.isCurrentStrokeActiveModifier,
               let last = self.activeStrokes.last,
               last.isModifierOnly,
               (newStroke.isModifierOnly || !newStroke.modifiers.isEmpty) {
                // 就地升级替换最后一个未松开的修饰键（避免修饰键组合或紧随的快捷键出现多余卡片）
                self.activeStrokes[self.activeStrokes.count - 1] = newStroke
            } else {
                // 连续按键队列最多保留 3 个，若已满 3 个则移除最左侧最早按下的一个
                if self.activeStrokes.count >= 3 {
                    self.activeStrokes.removeFirst()
                }
                self.activeStrokes.append(newStroke)
            }
        }
        self.punchTrigger &+= 1
        self.isCurrentStrokeActiveModifier = newStroke.isModifierOnly

        // 为该按键调度专属的超时自动移除
        let strokeId = newStroke.id
        let duration = AppSettings.shared.displayDuration
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            withAnimation(.easeInOut(duration: 0.24)) {
                self?.activeStrokes.removeAll(where: { $0.id == strokeId })
            }
        }
    }
}

// MARK: - 后台工作线程实现

private final class KeyMonitorWorker: @unchecked Sendable {
    private let onKeyStroke: @MainActor @Sendable (KeyStroke) -> Void
    private let onModifiersReleased: @MainActor @Sendable () -> Void
    private var thread: Thread?
    private var runLoop: CFRunLoop?
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning: Bool = false
    private var pressedModifierKeyCodes = Set<CGKeyCode>()

    init(
        onKeyStroke: @escaping @MainActor @Sendable (KeyStroke) -> Void,
        onModifiersReleased: @escaping @MainActor @Sendable () -> Void
    ) {
        self.onKeyStroke = onKeyStroke
        self.onModifiersReleased = onModifiersReleased
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let thread = Thread { [weak self] in
            self?.runThread()
        }
        thread.name = "com.keyglow.eventtap.thread"
        thread.qualityOfService = .userInteractive
        self.thread = thread
        thread.start()
    }

    func stop() {
        isRunning = false
        if let runLoop = runLoop {
            CFRunLoopStop(runLoop)
        }
        if let machPort = machPort {
            CGEvent.tapEnable(tap: machPort, enable: false)
            CFMachPortInvalidate(machPort)
        }
        if let source = runLoopSource, let runLoop = runLoop {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
        }
        machPort = nil
        runLoopSource = nil
        runLoop = nil
        thread = nil
        pressedModifierKeyCodes.removeAll()
    }

    private func runThread() {
        self.runLoop = CFRunLoopGetCurrent()

        // 监听 keyDown 与 flagsChanged 事件
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // 优先使用 sessionEventTap，若失败则尝试 hidEventTap
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: selfPtr
        ) ?? CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: selfPtr
        ) else {
            print("[KeyMonitorWorker] Failed to create CGEventTap. Please ensure Accessibility permissions are granted.")
            return
        }

        self.machPort = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        while isRunning {
            CFRunLoopRunInMode(.defaultMode, 1.0, false)
        }
    }

    fileprivate func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) {
        // 1. 处理超时与意外禁用自动恢复机制
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = machPort {
                CGEvent.tapEnable(tap: tap, enable: true)
                print("[KeyMonitorWorker] CGEventTap re-enabled after timeout/disable event.")
            }
            return
        }

        // 2. 检查密码框安全输入静默降级（绝不崩溃）
        if IsSecureEventInputEnabled() {
            // 系统正在进行密码/安全凭据录入，静默跳过保护用户隐私
            return
        }

        // 3. 处理按键按下与修饰键变更
        if type == .keyDown {
            processKeyDown(event: event)
        } else if type == .flagsChanged {
            processFlagsChanged(event: event)
        }
    }

    private func processFlagsChanged(event: CGEvent) {
        let flags = event.flags
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        // 判定该修饰键本次是按下还是释放
        let isDown: Bool
        switch keyCode {
        case 54, 55: // Command (RightCommand, Command)
            isDown = flags.contains(.maskCommand)
        case 58, 61: // Option (Option, RightOption)
            isDown = flags.contains(.maskAlternate)
        case 59, 62: // Control (Control, RightControl)
            isDown = flags.contains(.maskControl)
        case 56, 60: // Shift (Shift, RightShift)
            isDown = flags.contains(.maskShift)
        case 57: // CapsLock
            // CapsLock 每次按下触发切换，均视为一次有效单按
            isDown = true
        case 63, 179: // Fn / Globe
            if flags.contains(.maskSecondaryFn) {
                isDown = true
            } else if pressedModifierKeyCodes.contains(keyCode) {
                isDown = false
            } else {
                isDown = true
            }
        default:
            isDown = false
        }

        if isDown {
            pressedModifierKeyCodes.insert(keyCode)
        } else {
            pressedModifierKeyCodes.remove(keyCode)
        }

        if !isDown {
            // 当修饰键释放，若已无按下的修饰键，通知主线程释放状态
            if pressedModifierKeyCodes.isEmpty {
                let releaseCallback = self.onModifiersReleased
                Task { @MainActor in
                    releaseCallback()
                }
            }
            return
        }

        // 解析当前所有处于激活状态的修饰键
        var activeModifiers: [KeyModifier] = []
        if flags.contains(.maskControl) {
            activeModifiers.append(.control)
        }
        if flags.contains(.maskAlternate) {
            activeModifiers.append(.option)
        }
        if flags.contains(.maskShift) {
            activeModifiers.append(.shift)
        }
        if flags.contains(.maskCommand) {
            activeModifiers.append(.command)
        }

        let stroke: KeyStroke

        if keyCode == 57 {
            // CapsLock 单独按下
            stroke = KeyStroke(
                modifiers: activeModifiers,
                content: .symbol(name: "capslock", fallbackText: "⇪"),
                rawIdentifier: "caps_lock",
                isShortcut: true,
                isSpecialFunctionKey: true,
                isModifierOnly: true,
                timestamp: Date()
            )
        } else if keyCode == 63 || keyCode == 179 {
            // FN / 地球仪键
            stroke = KeyStroke(
                modifiers: activeModifiers,
                content: .symbol(name: "globe", fallbackText: "Fn"),
                rawIdentifier: "fn",
                isShortcut: true,
                isSpecialFunctionKey: true,
                isModifierOnly: true,
                timestamp: Date()
            )
        } else if !activeModifiers.isEmpty {
            // 标准修饰键 (Control, Option, Shift, Command)
            // 按照 macOS 官方标准顺序排序：⌃ ⌥ ⇧ ⌘
            let sorted = activeModifiers.sorted(by: { $0.sortOrder < $1.sortOrder })
            let lastMod = sorted.last!
            let prefixMods = Array(sorted.dropLast())
            let rawId = sorted.map { $0.rawValue }.joined(separator: "+")

            stroke = KeyStroke(
                modifiers: prefixMods,
                content: .symbol(name: lastMod.sfSymbol, fallbackText: lastMod.glyph),
                rawIdentifier: rawId,
                isShortcut: true,
                isSpecialFunctionKey: true,
                isModifierOnly: true,
                timestamp: Date()
            )
        } else {
            return
        }

        let callback = self.onKeyStroke
        Task { @MainActor in
            callback(stroke)
        }
    }

    private func processKeyDown(event: CGEvent) {
        let flags = event.flags
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        // 解析修饰键
        var modifiers: [KeyModifier] = []
        if flags.contains(.maskControl) {
            modifiers.append(.control)
        }
        if flags.contains(.maskAlternate) {
            modifiers.append(.option)
        }
        if flags.contains(.maskShift) {
            modifiers.append(.shift)
        }
        if flags.contains(.maskCommand) {
            modifiers.append(.command)
        }

        // 解析键位码内容
        let keyInfo = KeyCodeMapper.map(event: event, keyCode: keyCode)

        // 判断是否属于快捷键范畴：
        // 包含 Command/Option/Control，或单独的 Shift 组合，或独立功能键（Esc/Tab/F1~F12/方向键等）
        let hasControlOrAltOrCmd = flags.contains(.maskCommand) || flags.contains(.maskAlternate) || flags.contains(.maskControl)
        let isShortcut = hasControlOrAltOrCmd || (flags.contains(.maskShift) && keyInfo.isSpecialFunctionKey) || keyInfo.isSpecialFunctionKey

        // 构造唯一标示符用于连按判断（例如 "cmd+option+c" 或 "esc"）
        let modStr = modifiers.map { $0.rawValue }.joined(separator: "+")
        let rawIdentifier = modStr.isEmpty ? keyInfo.identifier : "\(modStr)+\(keyInfo.identifier)"

        let stroke = KeyStroke(
            modifiers: modifiers,
            content: keyInfo.content,
            rawIdentifier: rawIdentifier,
            isShortcut: isShortcut,
            isSpecialFunctionKey: keyInfo.isSpecialFunctionKey,
            isModifierOnly: false,
            timestamp: Date()
        )

        // 检查显示过滤模式
        let callback = self.onKeyStroke
        Task { @MainActor in
            let mode = AppSettings.shared.displayMode
            switch mode {
            case .shortcutsOnly:
                if isShortcut {
                    callback(stroke)
                }
            case .allKeys:
                callback(stroke)
            }
        }
    }
}

// MARK: - CGEventTap 回调函数

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passRetained(event)
    }

    let worker = Unmanaged<KeyMonitorWorker>.fromOpaque(refcon).takeUnretainedValue()
    worker.handleEvent(proxy: proxy, type: type, event: event)

    return Unmanaged.passRetained(event)
}
