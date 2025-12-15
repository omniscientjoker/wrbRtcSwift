import SwiftUI

// MARK: - 统一导航栏 Modifier
/// 统一的导航栏配置 Modifier，支持页面追踪
struct UnifiedNavigationBarModifier: ViewModifier {
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
        modifier(UnifiedNavigationBarModifier(
            title: title,
            displayMode: displayMode,
            theme: theme,
            enableTracking: enableTracking,
            trackingParameters: trackingParameters
        ))
    }

    /// 简化版：只设置标题
    func navigationBar(title: String) -> some View {
        modifier(UnifiedNavigationBarModifier(
            title: title,
            displayMode: .inline,
            theme: nil,
            enableTracking: true,
            trackingParameters: [:]
        ))
    }

    /// 带主题版本：设置标题和主题
    func navigationBar(title: String, theme: NavigationBarTheme) -> some View {
        modifier(UnifiedNavigationBarModifier(
            title: title,
            displayMode: .inline,
            theme: theme,
            enableTracking: true,
            trackingParameters: [:]
        ))
    }
}


