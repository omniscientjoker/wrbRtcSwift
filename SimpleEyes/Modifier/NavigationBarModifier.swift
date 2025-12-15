//
//  NavigationBarModifier.swift
//  SimpleEyes
//
//  导航栏外观修饰器
//  提供单个页面级别的导航栏样式自定义
//

import SwiftUI

// MARK: - 导航栏外观修饰器

/// 导航栏外观修饰器
///
/// 允许在特定页面自定义导航栏样式
/// 不影响全局导航栏配置
///
/// 使用示例：
/// ```swift
/// MyView()
///     .navigationBarAppearance(
///         backgroundColor: .systemGreen,
///         titleColor: .white,
///         tintColor: .white
///     )
/// ```
struct NavigationBarAppearanceModifier: ViewModifier {

    // MARK: - 属性

    /// 导航栏背景颜色
    var backgroundColor: UIColor

    /// 标题文字颜色
    var titleColor: UIColor

    /// 按钮颜色
    var tintColor: UIColor

    // MARK: - 初始化

    /// 初始化导航栏外观修饰器
    ///
    /// - Parameters:
    ///   - backgroundColor: 背景颜色，默认系统背景色
    ///   - titleColor: 标题颜色，默认系统标签色
    ///   - tintColor: 按钮颜色，默认系统蓝色
    init(
        backgroundColor: UIColor = .systemBackground,
        titleColor: UIColor = .label,
        tintColor: UIColor = .systemBlue
    ) {
        self.backgroundColor = backgroundColor
        self.titleColor = titleColor
        self.tintColor = tintColor
    }

    // MARK: - ViewModifier 协议实现

    /// 应用修饰器到视图
    ///
    /// - Parameter content: 被修饰的原始视图
    /// - Returns: 应用样式后的视图
    func body(content: Content) -> some View {
        content
            .onAppear {
                configureNavigationBar()
            }
    }

    // MARK: - 私有方法

    /// 配置导航栏外观
    ///
    /// 使用 UINavigationBarAppearance 设置样式
    /// 支持 iOS 13 及以上系统
    private func configureNavigationBar() {
        // 配置导航栏外观（支持 iOS 13+）
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = backgroundColor

        // 设置标题颜色
        appearance.titleTextAttributes = [.foregroundColor: titleColor]
        appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]

        // 应用外观
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = tintColor
    }
}

// MARK: - View 扩展

/// SwiftUI View 扩展
///
/// 提供便捷的导航栏外观自定义方法
extension View {
    /// 自定义导航栏外观
    ///
    /// 在特定页面应用自定义导航栏样式
    /// 不会影响其他页面的导航栏
    ///
    /// - Parameters:
    ///   - backgroundColor: 背景颜色，默认系统背景色
    ///   - titleColor: 标题文字颜色，默认系统标签色
    ///   - tintColor: 按钮颜色，默认系统蓝色
    /// - Returns: 应用样式后的视图
    ///
    /// 使用示例：
    /// ```swift
    /// NavigationView {
    ///     SettingsView()
    ///         .navigationBarAppearance(
    ///             backgroundColor: .systemGray6,
    ///             titleColor: .black
    ///         )
    /// }
    /// ```
    func navigationBarAppearance(
        backgroundColor: UIColor = .systemBackground,
        titleColor: UIColor = .label,
        tintColor: UIColor = .systemBlue
    ) -> some View {
        self.modifier(
            NavigationBarAppearanceModifier(
                backgroundColor: backgroundColor,
                titleColor: titleColor,
                tintColor: tintColor
            )
        )
    }
}
