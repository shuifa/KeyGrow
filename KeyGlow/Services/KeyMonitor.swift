//
//  KeyMonitor.swift
//  KeyGlow
//
//  全局键盘监听与上台调度。
//
//  0.100 的三处关键变化：
//   1. **显示过滤**：只有非字符键与含修饰键的组合才上台面，逐字回显打字内容被彻底关掉；
//   2. **长按驻留**：事件掩码加入 keyUp，键帽在按键松开之前不会超时消失（Key Hold）；
//   3. **释放才计时**：停留时长从「按下时刻」起算改为「松开时刻」起算，与 Keystroke Pro 一致。
//

import AppKit
import Carbon
import Combine
import CoreGraphics
import SwiftUI

/// 一次上台的按键请求（长按跟踪需要知道是哪个物理键码）
public struct KeyPress: Sendable {
    public let stroke: KeyStroke
    /// 用于长按跟踪的物理键码（组合键取主键，纯修饰键取该修饰键）
    public let keyCode: CGKeyCode

    public init(stroke: KeyStroke, keyCode: CGKeyCode) {
        self.stroke = stroke
        self.keyCode = keyCode
    }
}

/// 后台全局键盘事件监听与派发引擎
@MainActor
public final class KeyMonitor: ObservableObject {
    public static let shared = KeyMonitor()

    /// 当前处于展示生命周期内的键帽组（组数上限固定，超出时挤掉最左侧最早的一组）
    @Published public private(set) var activeStrokes: [KeyStroke] = []

    /// 最新按下的按键（兼容性快捷访问）
    public var currentStroke: KeyStroke? { activeStrokes.last }

    /// 每组键帽独立的冲击计数（只有「刚要按下 / 就地升级」的那一组会弹入）
    @Published public private(set) var punchCounters: [UUID: Int] = [:]

    /// 每组键帽仍在物理按下的键码（决定它是否处于长按驻留状态）
    private var heldKeyCodes: [UUID: CGKeyCode] = [:]

    /// 每组键帽专属的超时移除任务
    private var removalTasks: [UUID: Task<Void, Never>] = [:]

    /// 最新一组是否仍是「尚未松开的纯修饰键」（就地升级的判定依据）
    private var lastStrokeIsUnreleasedModifier = false

    @Published public private(set) var isMonitoring: Bool = false

    private var worker: KeyMonitorWorker?

    /// 入场：细腻的轻微放大弹入（原版 Pop-in 的物理阻尼感）
    private var enterAnimation: Animation {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? .easeOut(duration: 0.16)
            : .spring(duration: 0.34, bounce: 0.28)
    }

    /// 离场：平滑淡出，位移交给视图的 transition
    private var exitAnimation: Animation {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? .easeInOut(duration: 0.20)
            : .smooth(duration: 0.30)
    }

    private init() {}

    // MARK: - 生命周期

    public func start() {
        guard !isMonitoring else { return }

        let trusted = AXIsProcessTrusted()
        AppSettings.shared.checkAccessibility()
        if !trusted {
            print("[KeyMonitor] Accessibility permission not yet granted.")
        }

        let worker = KeyMonitorWorker(
            onPress: { [weak self] press, isAutoRepeat in
                self?.handlePress(press, isAutoRepeat: isAutoRepeat)
            },
            onRelease: { [weak self] keyCode in
                self?.handleRelease(keyCode: keyCode)
            }
        )
        self.worker = worker
        worker.start()
        self.isMonitoring = true
    }

    public func stop() {
        worker?.stop()
        worker = nil
        isMonitoring = false
        clearStroke()
    }

    /// 清空当前展示
    public func clearStroke() {
        removalTasks.values.forEach { $0.cancel() }
        removalTasks.removeAll()
        punchCounters.removeAll()
        heldKeyCodes.removeAll()
        lastStrokeIsUnreleasedModifier = false
        withAnimation(exitAnimation) {
            activeStrokes.removeAll()
        }
    }

    // MARK: - 上台调度

    private var capacity: Int { AppSettings.Defaults.maxVisibleGroups }

    /// 按下：过滤 → 就地升级 / 连按合并 → 追加 → 进入长按驻留
    public func handlePress(_ press: KeyPress, isAutoRepeat: Bool = false) {
        guard AppSettings.shared.isEnabled, press.stroke.isDisplayable else { return }

        let stroke = press.stroke

        // 1. 键盘自动重复：只累加次数，不新增卡片、不重置驻留
        if isAutoRepeat,
           let last = activeStrokes.last,
           last.rawIdentifier == stroke.rawIdentifier {
            bumpRepeat(on: last.id)
            return
        }

        // 2. 就地升级：⌘ → ⌘S 时复用原卡片 id，让它原地生长而不是交叉淡换
        if lastStrokeIsUnreleasedModifier,
           let last = activeStrokes.last,
           last.isModifierOnly,
           !stroke.isModifierOnly || !stroke.modifiers.isEmpty {
            let upgraded = KeyStroke(
                id: last.id,
                modifiers: stroke.modifiers,
                legend: stroke.legend,
                rawIdentifier: stroke.rawIdentifier,
                isSpecialKey: stroke.isSpecialKey,
                isModifierOnly: stroke.isModifierOnly,
                timestamp: stroke.timestamp,
                repeatCount: 1
            )
            replacementInPlace(upgraded)
            heldKeyCodes[upgraded.id] = press.keyCode
            cancelRemoval(for: upgraded.id)
            punchCounters[upgraded.id, default: 0] &+= 1
            lastStrokeIsUnreleasedModifier = stroke.isModifierOnly
            return
        }

        // 3. 连按合并：同一标识的连续按下原地计数（可在设置里关闭）
        if AppSettings.shared.showRepeatCount,
           let last = activeStrokes.last,
           last.rawIdentifier == stroke.rawIdentifier {
            bumpRepeat(on: last.id)
            heldKeyCodes[last.id] = press.keyCode
            cancelRemoval(for: last.id)
            punchCounters[last.id, default: 0] &+= 1
            lastStrokeIsUnreleasedModifier = stroke.isModifierOnly
            return
        }

        // 4. 普通追加：超出容量时挤掉最左侧最早的一组
        withAnimation(enterAnimation) {
            while activeStrokes.count >= capacity, let removed = activeStrokes.first {
                activeStrokes.removeFirst()
                heldKeyCodes.removeValue(forKey: removed.id)
                removalTasks[removed.id]?.cancel()
                removalTasks.removeValue(forKey: removed.id)
                punchCounters.removeValue(forKey: removed.id)
            }
            activeStrokes.append(stroke)
        }

        heldKeyCodes[stroke.id] = press.keyCode
        cancelRemoval(for: stroke.id)
        punchCounters[stroke.id, default: 0] &+= 1
        lastStrokeIsUnreleasedModifier = stroke.isModifierOnly
    }

    /// 松开：解除长按驻留，并从此刻开始计时淡出
    public func handleRelease(keyCode: CGKeyCode) {
        if let entry = heldKeyCodes.first(where: { $0.value == keyCode }) {
            heldKeyCodes.removeValue(forKey: entry.key)
            scheduleRemoval(for: entry.key, after: AppSettings.shared.displayDuration)
        }

        // 纯修饰键卡片已不再被按住 → 后续按键必须新开一组，而不是继续就地升级
        if let last = activeStrokes.last, last.isModifierOnly, heldKeyCodes[last.id] == nil {
            lastStrokeIsUnreleasedModifier = false
        }
    }

    // MARK: - 内部工具

    private func bumpRepeat(on id: UUID) {
        guard let index = activeStrokes.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(duration: 0.24, bounce: 0.22)) {
            activeStrokes[index].repeatCount &+= 1
        }
    }

    /// 原位替换（保持队列位置不变，卡片内容原地变形）
    private func replacementInPlace(_ stroke: KeyStroke) {
        guard let index = activeStrokes.firstIndex(where: { $0.id == stroke.id }) else { return }
        withAnimation(enterAnimation) {
            activeStrokes[index] = stroke
        }
    }

    private func cancelRemoval(for id: UUID) {
        removalTasks[id]?.cancel()
        removalTasks[id] = nil
    }

    private func scheduleRemoval(for id: UUID, after duration: Double) {
        cancelRemoval(for: id)

        removalTasks[id] = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(max(0.05, duration) * 1_000_000_000))
            } catch {
                return
            }

            guard !Task.isCancelled, let self else { return }

            guard self.activeStrokes.contains(where: { $0.id == id }) else {
                self.removalTasks.removeValue(forKey: id)
                self.punchCounters.removeValue(forKey: id)
                return
            }

            withAnimation(self.exitAnimation) {
                self.activeStrokes.removeAll(where: { $0.id == id })
            }
            self.removalTasks.removeValue(forKey: id)
            self.punchCounters.removeValue(forKey: id)
        }
    }

    // MARK: - 预览与测试

    /// 立即展示一次按键并在停留时长后自动淡出（偏好设置预览用，不涉及长按）
    public func simulateKeyStroke(_ stroke: KeyStroke) {
        guard stroke.isDisplayable else { return }
        withAnimation(enterAnimation) {
            while activeStrokes.count >= capacity {
                activeStrokes.removeFirst()
            }
            activeStrokes.append(stroke)
        }
        punchCounters[stroke.id, default: 0] &+= 1
        scheduleRemoval(for: stroke.id, after: AppSettings.shared.displayDuration)
    }

    /// 当前是否有卡片仍被物理按住（测试用）
    public func isHolding(strokeID: UUID) -> Bool {
        heldKeyCodes[strokeID] != nil
    }
}

// MARK: - 后台工作线程

private final class KeyMonitorWorker: @unchecked Sendable {
    private let onPress: @MainActor @Sendable (KeyPress, Bool) -> Void
    private let onRelease: @MainActor @Sendable (CGKeyCode) -> Void

    private var thread: Thread?
    private var runLoop: CFRunLoop?
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false
    private var pressedModifierKeyCodes = Set<CGKeyCode>()

    init(
        onPress: @escaping @MainActor @Sendable (KeyPress, Bool) -> Void,
        onRelease: @escaping @MainActor @Sendable (CGKeyCode) -> Void
    ) {
        self.onPress = onPress
        self.onRelease = onRelease
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
        if let runLoop { CFRunLoopStop(runLoop) }
        if let machPort {
            CGEvent.tapEnable(tap: machPort, enable: false)
            CFMachPortInvalidate(machPort)
        }
        if let source = runLoopSource, let runLoop {
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

        // keyDown 用于「按下」，keyUp 用于「松开」（长按驻留的结束信号），
        // flagsChanged 覆盖修饰键的按下与松开
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

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
            print("[KeyMonitorWorker] Failed to create CGEventTap. Please grant Accessibility permission.")
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
        // 1. 高负载超时 / 被用户输入禁用后的自愈
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = machPort {
                CGEvent.tapEnable(tap: tap, enable: true)
                print("[KeyMonitorWorker] CGEventTap re-enabled after disable event.")
            }
            return
        }

        // 2. 密码框 / 安全输入：静默跳过，绝不记录也不展示
        if IsSecureEventInputEnabled() { return }

        switch type {
        case .keyDown:
            processKeyDown(event: event)
        case .keyUp:
            processKeyUp(event: event)
        case .flagsChanged:
            processFlagsChanged(event: event)
        default:
            break
        }
    }

    // MARK: 修饰键（flagsChanged）

    private func processFlagsChanged(event: CGEvent) {
        let flags = event.flags
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        let isDown: Bool
        switch keyCode {
        case 54, 55:  // Command / RightCommand
            isDown = flags.contains(.maskCommand)
        case 58, 61:  // Option / RightOption
            isDown = flags.contains(.maskAlternate)
        case 59, 62:  // Control / RightControl
            isDown = flags.contains(.maskControl)
        case 56, 60:  // Shift / RightShift
            isDown = flags.contains(.maskShift)
        case 57:      // CapsLock：每次按下都切换一次状态，视为一次有效按键
            isDown = !pressedModifierKeyCodes.contains(57)
        case 63, 179: // Fn / Globe
            if flags.contains(.maskSecondaryFn) {
                isDown = true
            } else {
                isDown = false
            }
        default:
            return
        }

        if isDown {
            pressedModifierKeyCodes.insert(keyCode)
        } else {
            let wasPressed = pressedModifierKeyCodes.remove(keyCode) != nil
            // 只有确实处于按下状态时才派发松开，避免噪声事件打断驻留状态
            if wasPressed {
                let release = onRelease
                Task { @MainActor in release(keyCode) }
            }
            return
        }

        let stroke = makeModifierStroke(keyCode: keyCode, flags: flags)
        let press = KeyPress(stroke: stroke, keyCode: keyCode)
        let callback = onPress
        Task { @MainActor in callback(press, false) }
    }

    /// 构造「仅按下了修饰键」这一中间态的卡片
    private func makeModifierStroke(keyCode: CGKeyCode, flags: CGEventFlags) -> KeyStroke {
        var activeModifiers: [KeyModifier] = []
        if flags.contains(.maskControl) { activeModifiers.append(.control) }
        if flags.contains(.maskAlternate) { activeModifiers.append(.option) }
        if flags.contains(.maskShift) { activeModifiers.append(.shift) }
        if flags.contains(.maskCommand) { activeModifiers.append(.command) }

        // CapsLock 自成一体，不参与组合前缀
        if keyCode == 57 {
            return KeyStroke(
                modifiers: [],
                legend: KeyLegend(symbol: "capslock", text: "caps lock", widthUnits: 1.75),
                rawIdentifier: "caps_lock",
                isSpecialKey: true,
                isModifierOnly: true
            )
        }

        // Fn / Globe
        if keyCode == 63 || keyCode == 179 {
            return KeyStroke(
                modifiers: [],
                legend: KeyLegend(symbol: "globe", text: "fn", widthUnits: 1.5),
                rawIdentifier: "fn",
                isSpecialKey: true,
                isModifierOnly: true
            )
        }

        // 标准修饰键：⌃⌥⇧⌘ 按标准顺序排列，最后一个是本次按下者
        let sorted = activeModifiers.sorted(by: { $0.sortOrder < $1.sortOrder })
        guard let main = sorted.last else {
            // 理论上不可达（已确认 isDown），兜底给一颗空命令键
            return KeyStroke(legend: KeyModifier.command.legend, rawIdentifier: "command", isSpecialKey: true, isModifierOnly: true)
        }
        return KeyStroke(
            modifiers: Array(sorted.dropLast()),
            legend: main.legend,
            rawIdentifier: sorted.map(\.rawValue).joined(separator: "+"),
            isSpecialKey: true,
            isModifierOnly: true
        )
    }

    // MARK: 普通按键

    private func processKeyDown(event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let isAutoRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let press = makeKeyPress(event: event, keyCode: keyCode)
        let callback = onPress
        Task { @MainActor in callback(press, isAutoRepeat) }
    }

    private func processKeyUp(event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let release = onRelease
        Task { @MainActor in release(keyCode) }
    }

    private func makeKeyPress(event: CGEvent, keyCode: CGKeyCode) -> KeyPress {
        let flags = event.flags
        var modifiers: [KeyModifier] = []
        if flags.contains(.maskControl) { modifiers.append(.control) }
        if flags.contains(.maskAlternate) { modifiers.append(.option) }
        if flags.contains(.maskShift) { modifiers.append(.shift) }
        if flags.contains(.maskCommand) { modifiers.append(.command) }

        let info = KeyCodeMapper.map(event: event, keyCode: keyCode)
        let modPrefix = modifiers.sorted(by: { $0.sortOrder < $1.sortOrder }).map(\.rawValue).joined(separator: "+")
        let identifier = modPrefix.isEmpty ? info.identifier : "\(modPrefix)+\(info.identifier)"

        let stroke = KeyStroke(
            modifiers: modifiers,
            legend: info.legend,
            rawIdentifier: identifier,
            isSpecialKey: info.isSpecialKey,
            isModifierOnly: false
        )
        return KeyPress(stroke: stroke, keyCode: keyCode)
    }
}

// MARK: - CGEventTap 回调

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }

    let worker = Unmanaged<KeyMonitorWorker>.fromOpaque(refcon).takeUnretainedValue()
    worker.handleEvent(proxy: proxy, type: type, event: event)

    // listenOnly 回调必须返回「未额外持有」的事件对象，
    // 早期版本用 passRetained 会让每个事件多一次 retain，长时间后台运行持续泄漏。
    return Unmanaged.passUnretained(event)
}
