import SwiftUI

// MARK: - 组合基础样式 Modifier
/// 组合了导航栏样式 + 页面追踪的统一 Modifier
struct CombinedBaseModifier: ViewModifier {
    let title: String
    let displayMode: NavigationBarItem.TitleDisplayMode
    let parameters: [String: Any]
    let enableTracking: Bool
    let backgroundColor: UIColor
    let titleColor: UIColor
    let tintColor: UIColor

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
extension View {
    /// 应用组合的基础样式（导航栏 + 页面追踪）
    /// - Parameters:
    ///   - title: 导航栏标题（也作为页面名称）
    ///   - displayMode: 标题显示模式，默认 .inline
    ///   - parameters: 页面参数，用于追踪
    ///   - enableTracking: 是否启用页面追踪，默认 true
    ///   - backgroundColor: 导航栏背景色，默认蓝色
    ///   - titleColor: 标题文字颜色，默认白色
    ///   - tintColor: 按钮颜色，默认白色
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
