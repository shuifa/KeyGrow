//
//  OverlayContentView.swift
//  KeyGlow
//
//  悬浮层主内容：一排键帽组，右侧进入、左侧离场，整体按当前吸附点重新布局。
//
//  动效语言对齐 Keystroke Pro：
//    - 入场：轻微放大弹入（scale 0.88 → 1）+ 极短的位移，物理阻尼弹簧；
//    - 驻留：完全静止，不做呼吸、不做高亮，避免录屏里出现无意义晃动；
//    - 离场：平滑淡出并轻微缩小（scale 1 → 0.94），时长 0.30s。
//

import SwiftUI

/// 悬浮层主内容容器
public struct OverlayContentView: View {
    @ObservedObject private var monitor = KeyMonitor.shared
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let reducedMotionAnimation = Animation.easeOut(duration: 0.18)

    public init() {}

    /// 当前渲染外观，用于解析「跟随系统强调色」这一材质
    private var appearance: NSAppearance? {
        NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
    }

    private var enterAnimation: Animation {
        reduceMotion ? Self.reducedMotionAnimation : .spring(duration: 0.34, bounce: 0.26)
    }

    private var exitAnimation: Animation {
        reduceMotion ? Self.reducedMotionAnimation : .smooth(duration: 0.30)
    }

    public var body: some View {
        HStack(spacing: settings.metrics.groupSpacing) {
            ForEach(Array(monitor.activeStrokes.enumerated()), id: \.element.id) { index, stroke in
                KeycapGroupView(
                    stroke: stroke,
                    slots: settings.colorSlots,
                    metrics: settings.metrics,
                    shape: settings.shape,
                    repeatCount: settings.showRepeatCount ? stroke.repeatCount : 1,
                    appearance: appearance,
                    punchTrigger: monitor.punchCounters[stroke.id] ?? 0
                )
                .fixedSize()
                .transition(groupTransition)
                // 越靠右（越新）越靠上：离场卡片压在最下层
                .zIndex(Double(index))
            }
        }
        .fixedSize()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: overlayAlignment)
        .padding(.horizontal, settings.edgeInset)
        .padding(.vertical, max(8, settings.edgeInset * 0.5))
    }

    /// 入场放大弹入 / 出场淡出并轻微缩小
    private var groupTransition: AnyTransition {
        if reduceMotion {
            return .asymmetric(
                insertion: .opacity.animation(enterAnimation),
                removal: .opacity.animation(exitAnimation)
            )
        }
        return .asymmetric(
            insertion: .scale(scale: 0.88, anchor: .center)
                .combined(with: .offset(x: 10))
                .combined(with: .opacity)
                .animation(enterAnimation),
            removal: .scale(scale: 0.94, anchor: .center)
                .combined(with: .opacity)
                .animation(exitAnimation)
        )
    }

    /// 吸附点 → SwiftUI 对齐方式
    private var overlayAlignment: Alignment {
        switch (settings.anchor.row, settings.anchor.column) {
        case (.top, .leading): return .topLeading
        case (.top, .center): return .top
        case (.top, .trailing): return .topTrailing
        case (.middle, .leading): return .leading
        case (.middle, .trailing): return .trailing
        case (.bottom, .leading): return .bottomLeading
        case (.bottom, .center): return .bottom
        case (.bottom, .trailing): return .bottomTrailing
        // 中心不可选（3×3 网格留给显示器名称），兜底居中
        case (.middle, .center): return .center
        }
    }
}
