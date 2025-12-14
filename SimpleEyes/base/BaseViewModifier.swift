import SwiftUI

// MARK: - 基础视图样式 Modifier
struct BaseViewModifier: ViewModifier {
    let title: String
    let displayMode: NavigationBarItem.TitleDisplayMode
    let backgroundColor: UIColor
    let titleColor: UIColor
    let tintColor: UIColor

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

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
            .onAppear {
                configureNavigationBar()
            }
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
    /// 应用基础视图样式
    /// - Parameters:
    ///   - title: 导航栏标题
    ///   - displayMode: 标题显示模式，默认 .inline
    ///   - backgroundColor: 导航栏背景色，默认蓝色
    ///   - titleColor: 标题文字颜色，默认白色
    ///   - tintColor: 按钮颜色，默认白色
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
