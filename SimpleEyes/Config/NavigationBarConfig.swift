//
//  NavigationBarConfig.swift
//  SimpleEyes
//
//  导航栏全局配置
//  提供统一的导航栏主题管理和全局样式设置
//

import SwiftUI
import UIKit

// MARK: - 导航栏配置

/// 导航栏全局配置枚举
///
/// 提供应用级别的导航栏主题配置和管理
/// 主要功能：
/// - 预定义多个主题（默认、浅色、深色、透明）
/// - 全局导航栏样式设置
/// - 支持自定义主题
///
/// 使用示例：
/// ```swift
/// // 在 App 启动时设置全局主题
/// NavigationBarConfig.setupGlobalAppearance(theme: .defaultTheme)
///
/// // 使用自定义主题
/// let customTheme = NavigationBarTheme(
///     backgroundColor: .systemTeal,
///     titleColor: .white,
///     tintColor: .white
/// )
/// NavigationBarConfig.setupGlobalAppearance(theme: customTheme)
/// ```
enum NavigationBarConfig {

    // MARK: - 预定义主题

    /// 默认主题（蓝色）
    ///
    /// 蓝色背景，白色文字和按钮
    static let defaultTheme = NavigationBarTheme(
        backgroundColor: .systemBlue,
        titleColor: .white,
        tintColor: .white
    )

    /// 浅色主题（白色背景）
    ///
    /// 白色背景，系统标签色文字，蓝色按钮
    /// 适合浅色界面风格
    static let lightTheme = NavigationBarTheme(
        backgroundColor: .systemBackground,
        titleColor: .label,
        tintColor: .systemBlue
    )

    /// 深色主题（深色背景）
    ///
    /// 深灰背景，系统标签色文字，蓝色按钮
    /// 适合深色界面风格
    static let darkTheme = NavigationBarTheme(
        backgroundColor: .systemGray6,
        titleColor: .label,
        tintColor: .systemBlue
    )

    /// 透明主题
    ///
    /// 透明背景，系统标签色文字，蓝色按钮
    /// 适合需要透明导航栏的场景
    static let transparentTheme = NavigationBarTheme(
        backgroundColor: .clear,
        titleColor: .label,
        tintColor: .systemBlue,
        isTransparent: true
    )

    // MARK: - 全局设置方法

    /// 应用全局导航栏主题
    ///
    /// 在 App 启动时调用（通常在 AppDelegate 或 App.init() 中）
    /// 设置全局导航栏外观，所有页面默认使用该主题
    ///
    /// - Parameter theme: 要应用的主题，默认使用 defaultTheme
    ///
    /// - Note: 此方法会影响整个应用的导航栏样式
    ///         如果需要在特定页面使用不同样式，可以使用 NavigationBarModifier
    static func setupGlobalAppearance(theme: NavigationBarTheme = .defaultTheme) {
        let appearance = UINavigationBarAppearance()

        if theme.isTransparent {
            appearance.configureWithTransparentBackground()
        } else {
            appearance.configureWithOpaqueBackground()
        }

        appearance.backgroundColor = theme.backgroundColor
        appearance.titleTextAttributes = [.foregroundColor: theme.titleColor]
        appearance.largeTitleTextAttributes = [.foregroundColor: theme.titleColor]

        // 设置按钮颜色
        UINavigationBar.appearance().tintColor = theme.tintColor

        // 应用到所有状态
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance

        // iOS 15+ 可选：避免大标题下的分隔线
        if #available(iOS 15.0, *) {
            UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
        }
    }
}

// MARK: - 导航栏主题结构体

/// 导航栏主题配置
///
/// 定义导航栏的颜色和样式
/// 可以创建自定义主题或使用预定义主题
struct NavigationBarTheme {

    // MARK: - 属性

    /// 导航栏背景颜色
    let backgroundColor: UIColor

    /// 标题文字颜色
    let titleColor: UIColor

    /// 按钮颜色（返回按钮、工具栏按钮等）
    let tintColor: UIColor

    /// 是否为透明样式
    ///
    /// true: 使用透明背景
    /// false: 使用不透明背景
    let isTransparent: Bool

    // MARK: - 初始化

    /// 创建导航栏主题
    ///
    /// - Parameters:
    ///   - backgroundColor: 导航栏背景颜色
    ///   - titleColor: 标题文字颜色
    ///   - tintColor: 按钮颜色
    ///   - isTransparent: 是否为透明样式，默认 false
    init(
        backgroundColor: UIColor,
        titleColor: UIColor,
        tintColor: UIColor,
        isTransparent: Bool = false
    ) {
        self.backgroundColor = backgroundColor
        self.titleColor = titleColor
        self.tintColor = tintColor
        self.isTransparent = isTransparent
    }

    // MARK: - 预设主题快捷访问

    /// 默认蓝色主题
    static let defaultTheme = NavigationBarConfig.defaultTheme

    /// 浅色主题
    static let lightTheme = NavigationBarConfig.lightTheme

    /// 深色主题
    static let darkTheme = NavigationBarConfig.darkTheme

    /// 透明主题
    static let transparentTheme = NavigationBarConfig.transparentTheme
}

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
