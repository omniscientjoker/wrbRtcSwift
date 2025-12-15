//
//  BaseViewModifier.swift
//  SimpleEyes
//
//  基础视图样式修饰器
//  提供统一的导航栏样式配置
//

import SwiftUI

// MARK: - 基础视图样式修饰器

/// 基础视图样式修饰器
///
/// 为 SwiftUI 视图提供统一的导航栏样式
/// 主要功能：
/// - 设置导航栏标题和显示模式
/// - 自定义导航栏背景色
/// - 自定义标题文字颜色
/// - 自定义按钮颜色
///
/// 使用示例：
/// ```swift
/// NavigationView {
///     MyView()
///         .baseViewStyle(
///             title: "设置",
///             backgroundColor: .systemBlue,
///             titleColor: .white
///         )
/// }
/// ```
struct BaseViewModifier: ViewModifier {

    // MARK: - 属性

    /// 导航栏标题
    let title: String

    /// 标题显示模式
    ///
    /// .inline: 小标题（默认）
    /// .large: 大标题
    /// .automatic: 自动选择
    let displayMode: NavigationBarItem.TitleDisplayMode

    /// 导航栏背景色
    let backgroundColor: UIColor

    /// 标题文字颜色
    let titleColor: UIColor

    /// 按钮颜色（返回按钮、工具栏按钮等）
    let tintColor: UIColor

    // MARK: - 初始化

    /// 初始化基础视图修饰器
    ///
    /// - Parameters:
    ///   - title: 导航栏标题
    ///   - displayMode: 标题显示模式，默认 .inline
    ///   - backgroundColor: 导航栏背景色，默认系统蓝色
    ///   - titleColor: 标题文字颜色，默认白色
    ///   - tintColor: 按钮颜色，默认白色
    init(
        title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .inline,
        backgroundColor: UIColor = .systemBlue,
        titleColor: UIColor = .white,
        tintColor: UIColor = .white
    ) {
        self.title = title
        self.displayMode = displayMode
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
            .onAppear {
                configureNavigationBar()
            }
    }

    // MARK: - 私有方法

    /// 配置导航栏外观
    ///
    /// 使用 UINavigationBarAppearance 设置导航栏样式
    /// 支持 iOS 13 及以上系统
    private func configureNavigationBar() {
        // 使用 UINavigationBarAppearance 配置导航栏（支持 iOS 13+）
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
/// 提供便捷的基础样式应用方法
extension View {
    /// 应用基础视图样式
    ///
    /// 快捷方法，用于应用 BaseViewModifier
    ///
    /// - Parameters:
    ///   - title: 导航栏标题
    ///   - displayMode: 标题显示模式，默认 .inline
    ///   - backgroundColor: 导航栏背景色，默认系统蓝色
    ///   - titleColor: 标题文字颜色，默认白色
    ///   - tintColor: 按钮颜色，默认白色
    /// - Returns: 应用样式后的视图
    func baseViewStyle(
        title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .inline,
        backgroundColor: UIColor = .systemBlue,
        titleColor: UIColor = .white,
        tintColor: UIColor = .white
    ) -> some View {
        modifier(BaseViewModifier(
            title: title,
            displayMode: displayMode,
            backgroundColor: backgroundColor,
            titleColor: titleColor,
            tintColor: tintColor
        ))
    }
}
