//
//  OverlayContentView.swift
//  KeyGlow
//

import SwiftUI

/// 悬浮层主内容容器：负责多按键队列（最多 3 个）、从右边进左边出的 Spring 动效与自适应排版
public struct OverlayContentView: View {
    @ObservedObject private var monitor = KeyMonitor.shared
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 动效曲线常量（集中定义，保证进出场与队列重排共用同一节奏）
    // spring(duration:bounce:) 与 spring(response:dampingFraction:) 等价: bounce = 1 - dampingFraction
    private static let standardEnterAnimation = Animation.spring(duration: 0.32, bounce: 0.30)  // == response 0.32 / damping 0.70
    private static let standardExitAnimation  = Animation.smooth(duration: 0.22)                // == response 0.22 / damping 1.0
    private static let reducedMotionAnimation = Animation.easeOut(duration: 0.18)

    private var enterAnimation: Animation {
        reduceMotion ? Self.reducedMotionAnimation : Self.standardEnterAnimation
    }

    private var exitAnimation: Animation {
        reduceMotion ? Self.reducedMotionAnimation : Self.standardExitAnimation
    }

    public init() {}

    public var body: some View {
        ZStack(alignment: overlayAlignment) {
            HStack(spacing: 8) {
                ForEach(Array(monitor.activeStrokes.enumerated()), id: \.element.id) { index, stroke in
                    KeycapView(
                        stroke: stroke,
                        style: settings.keycapStyle,
                        accentColor: settings.specialKeyColor,
                        punchTrigger: monitor.punchCounters[stroke.id] ?? 0,
                        repeatCount: settings.showRepeatCount ? stroke.repeatCount : 1
                    )
                    .transition(strokeTransition)
                    .zIndex(Double(index))   // 越靠右（越新）越靠上；离场卡在最左侧、压在最下层
                }
            }
            .scaleEffect(settings.sizeScale)
            .animation(.smooth(duration: 0.22), value: settings.sizeScale)   // 只保留尺寸缩放自身的过渡
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: overlayAlignment)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var strokeTransition: AnyTransition {
        if reduceMotion {
            return .asymmetric(
                insertion: .opacity.animation(enterAnimation),
                removal: .opacity.animation(exitAnimation)
            )
        } else {
            return .asymmetric(
                // 从右边进：带轻微缩放与弹簧初速度（入场自带回弹）
                insertion: .offset(x: 40)
                    .combined(with: .scale(scale: 0.82))
                    .combined(with: .opacity)
                    .animation(enterAnimation),
                // 从左边出：平滑向左滑出并快速渐隐（出场短促、不回弹、快速淡出）
                removal: .offset(x: -24)
                    .combined(with: .scale(scale: 0.86))
                    .combined(with: .opacity)
                    .animation(exitAnimation)
            )
        }
    }

    private var overlayAlignment: Alignment {
        switch settings.anchor {
        case .bottomLeft:
            return .leading
        case .bottomRight:
            return .trailing
        case .topCenter, .bottomCenter, .mouseFollow:
            return .center
        }
    }
}
