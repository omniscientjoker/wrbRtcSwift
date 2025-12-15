//
//  ColorUtils.swift
//  SimpleEyes
//
//  Created by 姜淼 on 2025/12/15.
//

import UIKit

// MARK: - UIColor 扩展

/// UIColor 扩展
///
/// 提供从十六进制字符串创建颜色的便捷方法
extension UIColor {
    /// 从十六进制字符串创建颜色
    ///
    /// 支持格式：
    /// - 6 位：RRGGBB（例如："FF5733"）
    /// - 8 位：RRGGBBAA（例如："FF5733FF"）
    /// - 支持 # 前缀（例如："#FF5733"）
    ///
    /// - Parameter hex: 十六进制颜色字符串
    /// - Returns: UIColor 实例，如果格式无效则返回 nil
    ///
    /// 使用示例：
    /// ```swift
    /// let color1 = UIColor(hex: "FF5733")
    /// let color2 = UIColor(hex: "#FF5733FF")
    /// ```
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        let r, g, b, a: CGFloat

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
