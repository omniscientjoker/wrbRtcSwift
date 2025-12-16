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
///

enum NavigationBarConfig {
    private static var hasSetupAppearance = false
    // MARK: - 主题定义
    static func adaptiveDefaultTheme(for interfaceStyle: UIUserInterfaceStyle) -> NavigationBarTheme {
        switch interfaceStyle {
        case .dark:
            return NavigationBarTheme(
                backgroundColor: .systemGray6,
                titleColor: .label,
                tintColor: .systemBlue
            )
        case .light, .unspecified:
            return NavigationBarTheme(
                backgroundColor: .systemBackground,
                titleColor: .label,
                tintColor: .systemBlue
            )
        @unknown default:
            return lightTheme
        }
    }

    static var lightTheme: NavigationBarTheme {
        NavigationBarTheme(
            backgroundColor: .systemBackground,
            titleColor: .label,
            tintColor: .systemBlue
        )
    }

    static var darkTheme: NavigationBarTheme {
        NavigationBarTheme(
            backgroundColor: .systemGray6,
            titleColor: .label,
            tintColor: .systemBlue
        )
    }

    static var transparentTheme: NavigationBarTheme {
        NavigationBarTheme(
            backgroundColor: .clear,
            titleColor: .label,
            tintColor: .systemBlue,
            isTransparent: true
        )
    }

    // MARK: - 设置方法
    static func setupIfNeeded() {
        guard !hasSetupAppearance else { return }

        let style = UIApplication.shared.currentInterfaceStyle
        setupGlobalAppearance(theme: adaptiveDefaultTheme(for: style))
        hasSetupAppearance = true

        NotificationCenter.default.addObserver(
            forName: UIScene.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            let newStyle = UIApplication.shared.currentInterfaceStyle
            NavigationBarConfig.setupGlobalAppearance(theme: NavigationBarConfig.adaptiveDefaultTheme(for: newStyle))
        }
    }

    static func setupGlobalAppearance(theme: NavigationBarTheme = .init(backgroundColor: .systemBlue, titleColor: .white, tintColor: .white)) {
        let appearance = UINavigationBarAppearance()

        if theme.isTransparent {
            appearance.configureWithTransparentBackground()
        } else {
            appearance.configureWithOpaqueBackground()
        }

        appearance.backgroundColor = theme.backgroundColor
        appearance.titleTextAttributes = [.foregroundColor: theme.titleColor]
        appearance.largeTitleTextAttributes = [.foregroundColor: theme.titleColor]

        UINavigationBar.appearance().tintColor = theme.tintColor
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance

        if #available(iOS 15.0, *) {
            UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
        }
    }
}

// MARK: - UIApplication 扩展（安全获取当前界面风格）
extension UIApplication {
    var currentInterfaceStyle: UIUserInterfaceStyle {
        if #available(iOS 15.0, *) {
            // 遍历所有 connected window scenes
            for scene in connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        if !window.isHidden && window.rootViewController != nil {
                            return window.traitCollection.userInterfaceStyle
                        }
                    }
                }
            }
        } else {
            // Fallback for iOS 13-14
            for window in windows {
                if !window.isHidden && window.rootViewController != nil {
                    return window.traitCollection.userInterfaceStyle
                }
            }
        }
        return .unspecified
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
