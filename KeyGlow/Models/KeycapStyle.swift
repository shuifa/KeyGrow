//
//  KeycapStyle.swift
//  KeyGlow
//

import SwiftUI

/// 键帽视觉主题风格
public enum KeycapStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case classicDark = "classicDark"
    case frostedGlass = "frostedGlass"
    case auroraGlow = "auroraGlow"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .classicDark:
            return "经典深黑"
        case .frostedGlass:
            return "磨砂亚克力"
        case .auroraGlow:
            return "极光微光"
        }
    }

    public var subtitle: String {
        switch self {
        case .classicDark:
            return "拟物键帽质感、立体微高光与柔和阴影"
        case .frostedGlass:
            return "通透磨砂毛玻璃，现代简约轻盈"
        case .auroraGlow:
            return "暗夜深邃底色配合极光霓虹微光"
        }
    }
}
