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



// MARK: - 统一导航栏 Modifier
/// 统一的导航栏配置 Modifier，支持页面追踪
struct NavigationBarModifier: ViewModifier {
    let title: String
    let displayMode: NavigationBarItem.TitleDisplayMode
    let theme: NavigationBarTheme?
    let enableTracking: Bool
    let trackingParameters: [String: Any]

    init(
        title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .inline,
        theme: NavigationBarTheme? = nil,
        enableTracking: Bool = true,
        trackingParameters: [String: Any] = [:]
    ) {
        self.title = title
        self.displayMode = displayMode
        self.theme = theme
        self.enableTracking = enableTracking
        self.trackingParameters = trackingParameters
    }

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
            // 注意：不在这里修改全局导航栏样式
            // 全局样式应该在 App 初始化时统一设置
            // 如果需要特定页面的样式，应该使用 toolbar 等 SwiftUI 原生方式
            // 页面追踪（可选）
            .modifier(
                enableTracking
                    ? PageTrackingModifier(pageName: title, parameters: trackingParameters)
                    : PageTrackingModifier(pageName: "", parameters: [:])
            )
    }

    /// 配置当前导航栏外观
    ///
    /// 注意：此方法已废弃，不应在页面级别修改全局导航栏样式
    /// 所有导航栏样式应该在 App 初始化时通过 NavigationBarConfig.setupGlobalAppearance() 统一设置
    ///
    /// 如果需要在特定页面使用不同样式，建议使用 SwiftUI 的 toolbar 相关 modifier
    /// 或者为每个 Tab 创建独立的 NavigationView
    @available(*, deprecated, message: "请在 App 初始化时统一设置全局导航栏样式，不要在页面级别修改")
    private func configureNavigationBar(with theme: NavigationBarTheme) {
        // 此方法已废弃，不再执行任何操作
        // 避免在页面切换时修改全局 UINavigationBar.appearance()
    }
}



// MARK: - View 扩展
extension View {
    /// 配置导航栏（推荐使用）
    /// - Parameters:
    ///   - title: 导航栏标题
    ///   - displayMode: 标题显示模式，默认 .inline
    ///   - theme: 导航栏主题，nil 表示使用全局主题
    ///   - enableTracking: 是否启用页面追踪，默认 true
    ///   - trackingParameters: 页面追踪参数
    /// - Returns: 配置后的视图
    func navigationBar(
        title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .inline,
        theme: NavigationBarTheme? = nil,
        enableTracking: Bool = true,
        trackingParameters: [String: Any] = [:]
    ) -> some View {
        modifier(NavigationBarModifier(
            title: title,
            displayMode: displayMode,
            theme: theme,
            enableTracking: enableTracking,
            trackingParameters: trackingParameters
        ))
    }

    /// 简化版：只设置标题
    func navigationBar(title: String) -> some View {
        modifier(NavigationBarModifier(
            title: title,
            displayMode: .inline,
            theme: nil,
            enableTracking: true,
            trackingParameters: [:]
        ))
    }

    /// 带主题版本：设置标题和主题
    func navigationBar(title: String, theme: NavigationBarTheme) -> some View {
        modifier(NavigationBarModifier(
            title: title,
            displayMode: .inline,
            theme: theme,
            enableTracking: true,
            trackingParameters: [:]
        ))
    }
}
