//
//  KeycapStyle.swift
//  KeyGlow
//

import SwiftUI

/// 键帽材质风格（只描述「光照与表面处理」，不含任何颜色信息）
public enum KeycapStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case matte
    case frosted
    case aurora

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .matte: return "哑光实体"
        case .frosted: return "磨砂玻璃"
        case .aurora: return "极光染色"
        }
    }

    public var subtitle: String {
        switch self {
        case .matte: return "实体注塑键帽，立体微高光与柔和阴影"
        case .frosted: return "通透毛玻璃，现代轻盈"
        case .aurora: return "深色底 + 强调色霓虹染色"
        }
    }

    /// 历史 rawValue 迁移：0.11 及以前写作 classicDark / frostedGlass / auroraGlow
    public static func migrate(fromLegacy raw: String) -> KeycapStyle? {
        switch raw {
        case "classicDark": return .matte
        case "frostedGlass": return .frosted
        case "auroraGlow": return .aurora
        default: return KeycapStyle(rawValue: raw)
        }
    }
}
