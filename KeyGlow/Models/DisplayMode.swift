//
//  DisplayMode.swift
//  KeyGlow
//

import Foundation

/// 按键监听与展示过滤模式
public enum DisplayMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case shortcutsOnly = "shortcutsOnly"
    case allKeys = "allKeys"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .shortcutsOnly:
            return "仅快捷键模式"
        case .allKeys:
            return "全按键模式"
        }
    }

    public var description: String {
        switch self {
        case .shortcutsOnly:
            return "仅显示组合快捷键（如 ⌘C）及特殊功能键（Esc、Tab、F1~F12 等），日常打字不干扰"
        case .allKeys:
            return "显示所有按键输入，适用于录制打字教程或演示特定操作"
        }
    }
}
