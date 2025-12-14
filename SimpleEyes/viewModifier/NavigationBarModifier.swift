import SwiftUI

// MARK: - Navigation Bar Appearance Modifier
struct NavigationBarAppearanceModifier: ViewModifier {
    var backgroundColor: UIColor
    var titleColor: UIColor
    var tintColor: UIColor

    init(
        backgroundColor: UIColor = .systemBackground,
        titleColor: UIColor = .label,
        tintColor: UIColor = .systemBlue
    ) {
        self.backgroundColor = backgroundColor
        self.titleColor = titleColor
        self.tintColor = tintColor
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                configureNavigationBar()
            }
    }

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

// MARK: - View Extension
extension View {
    /// 自定义导航栏外观
    /// - Parameters:
    ///   - backgroundColor: 背景颜色
    ///   - titleColor: 标题文字颜色
    ///   - tintColor: 按钮颜色
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
