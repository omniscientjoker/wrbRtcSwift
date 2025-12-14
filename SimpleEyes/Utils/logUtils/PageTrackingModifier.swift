import SwiftUI

// MARK: - 页面追踪 Modifier
struct PageTrackingModifier: ViewModifier {
    let pageName: String
    let parameters: [String: Any]

    init(pageName: String, parameters: [String: Any] = [:]) {
        self.pageName = pageName
        self.parameters = parameters
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                PageLogger.shared.logPageEnter(
                    pageName: pageName,
                    parameters: parameters
                )
            }
            .onDisappear {
                PageLogger.shared.logPageExit(pageName: pageName)
            }
    }
}

// MARK: - View 扩展
extension View {
    /// 添加页面追踪
    /// - Parameters:
    ///   - pageName: 页面名称
    ///   - parameters: 页面参数（可选）
    func trackPage(_ pageName: String, parameters: [String: Any] = [:]) -> some View {
        modifier(PageTrackingModifier(pageName: pageName, parameters: parameters))
    }
}
