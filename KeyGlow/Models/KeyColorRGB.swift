//
//  KeyColorRGB.swift
//  KeyGlow
//
//  sRGB 色彩基元：整个配色体系唯一的颜色载体。
//
//  0.100 起与「键帽材质」解耦：本文件只负责「颜色数学」（混合、亮度、对比度、动态系统色），
//  不再关心任何主题、色相或光照语义，材质字典与色板派生交给 `KeycapMaterial`。
//

import AppKit
import SwiftUI

/// sRGB 色彩分量封装
///
/// 同时提供 WCAG 相对亮度与对比度计算，用于保证「亮键帽配深字符 / 深键帽配浅字符」始终可读。
public struct KeyColorRGB: Sendable, Equatable, Hashable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// 0xRRGGBB 十六进制初始化（材质字典里逐色号核对时使用）
    public init(hex: UInt32) {
        self.init(
            Double((hex >> 16) & 0xFF) / 255.0,
            Double((hex >> 8) & 0xFF) / 255.0,
            Double(hex & 0xFF) / 255.0
        )
    }

    public static let white = KeyColorRGB(1.0, 1.0, 1.0)
    public static let black = KeyColorRGB(0.0, 0.0, 0.0)

    /// 深墨色字符（浅色键帽专用，比纯黑柔和，接近丝印油墨）
    public static let ink = KeyColorRGB(0.10, 0.11, 0.13)

    // MARK: - 输出

    public var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    public func color(opacity: Double) -> Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    public var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }

    // MARK: - 色彩数学

    /// WCAG 相对亮度（0 ~ 1）
    public var relativeLuminance: Double {
        func linearized(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearized(red) + 0.7152 * linearized(green) + 0.0722 * linearized(blue)
    }

    /// WCAG 对比度（1 ~ 21）
    public func contrastRatio(with other: KeyColorRGB) -> Double {
        let lhs = relativeLuminance
        let rhs = other.relativeLuminance
        return (max(lhs, rhs) + 0.05) / (min(lhs, rhs) + 0.05)
    }

    /// 线性混合（ratio 为 other 的占比，0...1）
    public func mixed(with other: KeyColorRGB, ratio: Double) -> KeyColorRGB {
        let t = min(max(ratio, 0), 1)
        return KeyColorRGB(
            red + (other.red - red) * t,
            green + (other.green - green) * t,
            blue + (other.blue - blue) * t
        )
    }

    /// 提亮（向白色混合）
    public func lightened(_ ratio: Double) -> KeyColorRGB {
        mixed(with: .white, ratio: ratio)
    }

    /// 压暗（向黑色混合）
    public func darkened(_ ratio: Double) -> KeyColorRGB {
        mixed(with: .black, ratio: ratio)
    }

    /// 色度（最大通道与最小通道之差），用于校验彩色材质是否足够饱和
    public var chroma: Double {
        max(red, max(green, blue)) - min(red, min(green, blue))
    }

    /// 两色在 sRGB 空间的欧氏距离（0 ~ 441），用于校验色槽之间是否真的区分得开
    public func distance(to other: KeyColorRGB) -> Double {
        let dr = (red - other.red) * 255
        let dg = (green - other.green) * 255
        let db = (blue - other.blue) * 255
        return (dr * dr + dg * dg + db * db).squareRoot()
    }

    // MARK: - 系统动态色

    /// 解析 macOS 的强调色（随用户在「系统设置 → 外观」里更换）
    ///
    /// 强调色是动态色，必须在具体外观下解析才能拿到真实分量，
    /// 因此这里显式按当前 `NSApp.effectiveAppearance` 求值，避免解出色域外的灰值。
    public static func systemAccent(for appearance: NSAppearance? = nil) -> KeyColorRGB {
        let resolved = appearance ?? NSApp?.effectiveAppearance
        var rgb = KeyColorRGB(0.0, 0.48, 1.0)
        resolved?.performAsCurrentDrawingAppearance {
            if let srgb = NSColor.controlAccentColor.usingColorSpace(.sRGB) {
                rgb = KeyColorRGB(
                    Double(srgb.redComponent),
                    Double(srgb.greenComponent),
                    Double(srgb.blueComponent)
                )
            }
        }
        return rgb
    }
}
