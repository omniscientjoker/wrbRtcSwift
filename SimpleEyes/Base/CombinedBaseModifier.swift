//
//  CombinedBaseModifier.swift
//  SimpleEyes
//
//  组合基础样式修饰器
//  整合导航栏样式和页面追踪功能的统一修饰器
//

import SwiftUI

// MARK: - 组合基础样式修饰器

/// 组合基础样式修饰器
///
/// 整合了导航栏样式配置和页面追踪功能
/// 主要功能：
/// - 导航栏样式配置（继承自 BaseViewModifier）
/// - 页面浏览追踪（可选）
/// - 统一的页面基础设置
///
/// 使用示例：
/// ```swift
/// NavigationView {
///     MyView()
///         .basePage(
///             title: "设置",
///             parameters: ["from": "main_tab"],
///             enableTracking: true
///         )
/// }
/// ```
struct CombinedBaseModifier: ViewModifier {

    // MARK: - 属性

    /// 导航栏标题（同时用作页面追踪名称）
    let title: String

    /// 标题显示模式
    let displayMode: NavigationBarItem.TitleDisplayMode

    /// 页面追踪参数
    ///
    /// 用于记录页面访问的额外信息
    /// 例如：来源页面、设备ID等
    let parameters: [String: Any]

    /// 是否启用页面追踪
    let enableTracking: Bool

    /// 导航栏背景色
    let backgroundColor: UIColor

    /// 标题文字颜色
    let titleColor: UIColor

    /// 按钮颜色
    let tintColor: UIColor

    // MARK: - 初始化

    /// 初始化组合基础修饰器
    ///
    /// - Parameters:
    ///   - title: 导航栏标题（也用作页面名称）
    ///   - displayMode: 标题显示模式，默认 .inline
    ///   - parameters: 页面追踪参数，默认为空
    ///   - enableTracking: 是否启用页面追踪，默认 true
    ///   - backgroundColor: 导航栏背景色，默认系统蓝色
    ///   - titleColor: 标题文字颜色，默认白色
    ///   - tintColor: 按钮颜色，默认白色
    init(
        title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .inline,
        parameters: [String: Any] = [:],
        enableTracking: Bool = true,
        backgroundColor: UIColor = .systemBlue,
        titleColor: UIColor = .white,
        tintColor: UIColor = .white
    ) {
        self.title = title
        self.displayMode = displayMode
        self.parameters = parameters
        self.enableTracking = enableTracking
        self.backgroundColor = backgroundColor
        self.titleColor = titleColor
        self.tintColor = tintColor
    }

    // MARK: - ViewModifier 协议实现

    /// 应用修饰器到视图
    ///
    /// 组合应用导航栏样式和页面追踪
    /// - Parameter content: 被修饰的原始视图
    /// - Returns: 应用样式后的视图
    func body(content: Content) -> some View {
        content
            // 1. 导航栏样式
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
            .onAppear {
                configureNavigationBar()
            }
            // 2. 页面追踪（可选）
            .modifier(
                enableTracking
                    ? PageTrackingModifier(pageName: title, parameters: parameters)
                    : PageTrackingModifier(pageName: "", parameters: [:])
            )
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
/// 提供便捷的组合基础样式应用方法
extension View {
    /// 应用组合的基础样式（导航栏 + 页面追踪）
    ///
    /// 快捷方法，用于应用 CombinedBaseModifier
    /// 适合需要页面追踪的场景
    ///
    /// - Parameters:
    ///   - title: 导航栏标题（也作为页面名称）
    ///   - displayMode: 标题显示模式，默认 .inline
    ///   - parameters: 页面追踪参数，默认为空
    ///   - enableTracking: 是否启用页面追踪，默认 true
    ///   - backgroundColor: 导航栏背景色，默认系统蓝色
    ///   - titleColor: 标题文字颜色，默认白色
    ///   - tintColor: 按钮颜色，默认白色
    /// - Returns: 应用样式后的视图
    func basePage(
        title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .inline,
        parameters: [String: Any] = [:],
        enableTracking: Bool = true,
        backgroundColor: UIColor = .systemBlue,
        titleColor: UIColor = .white,
        tintColor: UIColor = .white
    ) -> some View {
        modifier(CombinedBaseModifier(
            title: title,
            displayMode: displayMode,
            parameters: parameters,
            enableTracking: enableTracking,
            backgroundColor: backgroundColor,
            titleColor: titleColor,
            tintColor: tintColor
        ))
    }
}
