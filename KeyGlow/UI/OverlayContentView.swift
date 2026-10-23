//
//  OverlayContentView.swift
//  KeyGlow
//

import SwiftUI

/// 悬浮层主内容容器：负责按键队列（数量由设置控制，同时按多个算一个）、
/// 从右边进左边出的 Spring 动效与自适应排版，并可选地为键帽加一层托盘背板提升对比度。
public struct OverlayContentView: View {
    @ObservedObject private var monitor = KeyMonitor.shared
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 动效曲线常量（集中定义，保证进出场与队列重排共用同一节奏）
    // spring(duration:bounce:) 与 spring(response:dampingFraction:) 等价: bounce = 1 - dampingFraction
    private static let standardEnterAnimation = Animation.spring(duration: 0.32, bounce: 0.30)  // == response 0.32 / damping 0.70
    private static let standardExitAnimation  = Animation.smooth(duration: 0.22)                // == response 0.22 / damping 1.0
    private static let reducedMotionAnimation = Animation.easeOut(duration: 0.18)

    /// 组合之间的间距：必须显著大于组合内部（4pt）的键间距，
    /// 否则连续按下的多个组合会被读成一长串键帽。
    private static let groupSpacing: CGFloat = 18

    private var enterAnimation: Animation {
        reduceMotion ? Self.reducedMotionAnimation : Self.standardEnterAnimation
    }

    private var exitAnimation: Animation {
        reduceMotion ? Self.reducedMotionAnimation : Self.standardExitAnimation
    }

    public init() {}

    public var body: some View {
        ZStack(alignment: overlayAlignment) {
            HStack(spacing: Self.groupSpacing) {
                ForEach(Array(monitor.activeStrokes.enumerated()), id: \.element.id) { index, stroke in
                    KeycapView(
                        stroke: stroke,
                        theme: settings.theme,
                        style: settings.keycapStyle,
                        colorScheme: colorScheme,
                        opacity: settings.keyOpacity,
                        punchTrigger: monitor.punchCounters[stroke.id] ?? 0,
                        repeatCount: settings.showRepeatCount ? stroke.repeatCount : 1
                    )
                    .transition(strokeTransition)
                    .zIndex(Double(index))   // 越靠右（越新）越靠上；离场卡在最左侧、压在最下层
                }
            }
            .padding(.horizontal, settings.showKeycapTray ? 14 : 0)
            .padding(.vertical, settings.showKeycapTray ? 8 : 0)
            .background {
                if settings.showKeycapTray {
                    trayBackground
                }
            }
            .scaleEffect(settings.sizeScale)
            .animation(.smooth(duration: 0.22), value: settings.sizeScale)   // 只保留尺寸缩放自身的过渡
            .animation(.smooth(duration: 0.25), value: settings.showKeycapTray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: overlayAlignment)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    /// 键帽托盘：浅色桌面下的对比度兜底方案
    private var trayBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(colorScheme == .dark ? Color.black.opacity(0.42) : Color.white.opacity(0.62))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.55), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 4)
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
