//
//  OverlayContentView.swift
//  KeyGlow
//

import SwiftUI

/// 悬浮层主内容容器：负责多按键队列（最多 3 个）、从右边进左边出的 Spring 动效与自适应排版
public struct OverlayContentView: View {
    @ObservedObject private var monitor = KeyMonitor.shared
    @ObservedObject private var settings = AppSettings.shared

    public init() {}

    public var body: some View {
        ZStack(alignment: overlayAlignment) {
            HStack(spacing: 8) {
                ForEach(monitor.activeStrokes) { stroke in
                    KeycapView(
                        stroke: stroke,
                        style: settings.keycapStyle,
                        accentColor: settings.specialKeyColor,
                        punchTrigger: monitor.punchTrigger
                    )
                    .transition(
                        .asymmetric(
                            // 从右边进：带轻微缩放与弹簧初速度
                            insertion: .offset(x: 36)
                                .combined(with: .scale(scale: 0.82))
                                .combined(with: .opacity),
                            // 从左边出：平滑向左滑出并渐隐
                            removal: .offset(x: -36)
                                .combined(with: .scale(scale: 0.82))
                                .combined(with: .opacity)
                        )
                    )
                }
            }
            .scaleEffect(settings.sizeScale)
            .animation(.spring(response: 0.28, dampingFraction: 0.72, blendDuration: 0), value: monitor.activeStrokes.map { $0.id })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: overlayAlignment)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
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
