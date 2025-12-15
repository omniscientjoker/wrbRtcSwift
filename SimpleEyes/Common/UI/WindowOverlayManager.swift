//
//  WindowOverlayManager.swift
//  SimpleEyes
//
//  通用的 Window 层级覆盖管理器
//  用于在 window 上显示弹框、Toast、Loading 等
//

import SwiftUI
import UIKit
import Combine

// MARK: - 蒙层配置

/// 蒙层配置
struct MaskConfig {
    /// 是否显示蒙层，默认 true
    var showMask: Bool = true

    /// 蒙层颜色，默认半透明黑色
    var maskColor: Color = Color.black.opacity(0.5)

    /// 点击蒙层的回调，默认为关闭弹框
    var onMaskTap: (() -> Void)?

    /// 默认配置：有蒙层，点击关闭
    static let defaultWithDismiss = MaskConfig(
        showMask: true,
        maskColor: Color.black.opacity(0.5),
        onMaskTap: nil  // 将在使用时设置为关闭回调
    )

    /// 默认配置：有蒙层，点击无效
    static let defaultNoAction = MaskConfig(
        showMask: true,
        maskColor: Color.black.opacity(0.5),
        onMaskTap: nil
    )

    /// 无蒙层配置
    static let noMask = MaskConfig(
        showMask: false,
        maskColor: .clear,
        onMaskTap: nil
    )
}

/// Window 覆盖层管理器
///
/// 提供在 window 层级显示各种 UI 组件的能力
/// 支持：
/// - 居中弹框（Dialog）
/// - Toast 提示
/// - Loading 加载
/// - 自定义视图
///
/// ## 使用示例
/// ```swift
/// // 显示弹框（默认：有蒙层，点击关闭）
/// WindowOverlayManager.shared.showDialog {
///     MyDialogView()
/// }
///
/// // 显示弹框（自定义蒙层颜色）
/// WindowOverlayManager.shared.showDialog(
///     maskConfig: MaskConfig(
///         showMask: true,
///         maskColor: Color.blue.opacity(0.3),
///         onMaskTap: { WindowOverlayManager.shared.hide() }
///     )
/// ) {
///     MyDialogView()
/// }
///
/// // 显示弹框（无蒙层）
/// WindowOverlayManager.shared.showDialog(maskConfig: .noMask) {
///     MyDialogView()
/// }
///
/// // 显示弹框（点击蒙层无效）
/// WindowOverlayManager.shared.showDialog(
///     maskConfig: MaskConfig(onMaskTap: nil)
/// ) {
///     MyDialogView()
/// }
///
/// // 显示 Toast
/// WindowOverlayManager.shared.showToast(message: "保存成功")
///
/// // 显示 Loading
/// WindowOverlayManager.shared.showLoading(message: "加载中...")
///
/// // 隐藏
/// WindowOverlayManager.shared.hide()
/// ```
@MainActor
class WindowOverlayManager: ObservableObject {
    // MARK: - 单例

    static let shared = WindowOverlayManager()

    // MARK: - 私有属性

    private var overlayWindow: UIWindow?
    private var hostingController: UIHostingController<AnyView>?

    // MARK: - 初始化

    private init() {}

    // MARK: - 公共方法

    /// 显示居中弹框
    ///
    /// - Parameters:
    ///   - maskConfig: 蒙层配置，默认有蒙层且点击关闭
    ///   - content: 弹框内容视图
    func showDialog<Content: View>(
        maskConfig: MaskConfig? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        // 如果没有提供配置，使用默认配置（有蒙层，点击关闭）
        var config = maskConfig ?? MaskConfig.defaultNoAction

        // 如果配置的 onMaskTap 为 nil，设置默认关闭行为
        if config.onMaskTap == nil && maskConfig == nil {
            config.onMaskTap = { [weak self] in
                self?.hide()
            }
        }

        let dialogView = DialogOverlay(
            maskConfig: config,
            onDismiss: { [weak self] in
                self?.hide()
            },
            content: content
        )

        show(AnyView(dialogView))
    }

    /// 显示居中弹框（兼容旧版本 API）
    ///
    /// - Parameters:
    ///   - maskClosable: 点击蒙层是否关闭，默认 false
    ///   - content: 弹框内容视图
    @available(*, deprecated, message: "请使用 showDialog(maskConfig:content:) 方法")
    func showDialog<Content: View>(
        maskClosable: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        var config = MaskConfig()
        if maskClosable {
            config.onMaskTap = { [weak self] in
                self?.hide()
            }
        }
        showDialog(maskConfig: config, content: content)
    }

    /// 显示 Toast 提示
    ///
    /// - Parameters:
    ///   - message: 提示消息
    ///   - duration: 持续时间（秒），默认 2 秒
    func showToast(message: String, duration: TimeInterval = 2.0) {
        let toastView = ToastOverlay(message: message)
        show(AnyView(toastView))

        // 自动隐藏
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            hide()
        }
    }

    /// 显示 Loading 加载
    ///
    /// - Parameter message: 加载提示文字，默认 "加载中..."
    func showLoading(message: String = "加载中...") {
        let loadingView = LoadingOverlay(message: message)
        show(AnyView(loadingView))
    }

    /// 隐藏覆盖层
    func hide() {
        UIView.animate(withDuration: 0.25, animations: {
            self.overlayWindow?.alpha = 0
        }) { _ in
            self.overlayWindow?.isHidden = true
            self.overlayWindow = nil
            self.hostingController = nil
        }
    }

    // MARK: - 私有方法

    /// 显示自定义视图
    private func show(_ view: AnyView) {
        // 获取当前 window scene
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            print("[WindowOverlay] Failed to get window scene")
            return
        }

        // 创建新的 window
        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = .alert + 1  // 在最上层
        window.backgroundColor = .clear

        // 创建 hosting controller
        let controller = UIHostingController(rootView: view)
        controller.view.backgroundColor = .clear

        window.rootViewController = controller
        window.makeKeyAndVisible()

        // 淡入动画
        window.alpha = 0
        UIView.animate(withDuration: 0.25) {
            window.alpha = 1
        }

        self.overlayWindow = window
        self.hostingController = controller
    }
}

// MARK: - 弹框覆盖层

/// 居中弹框覆盖层
private struct DialogOverlay<Content: View>: View {
    let maskConfig: MaskConfig
    let onDismiss: () -> Void
    let content: () -> Content

    var body: some View {
        ZStack {
            // 蒙层（如果需要显示）
            if maskConfig.showMask {
                maskConfig.maskColor
                    .ignoresSafeArea()
                    .onTapGesture {
                        // 执行自定义回调
                        if let onMaskTap = maskConfig.onMaskTap {
                            onMaskTap()
                        }
                    }
            }

            // 居中内容
            content()
                .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Toast 覆盖层

/// Toast 提示覆盖层
private struct ToastOverlay: View {
    let message: String

    var body: some View {
        VStack {
            Spacer()

            Text(message)
                .font(.body)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.8))
                )
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

            Spacer()
                .frame(height: 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Loading 覆盖层

/// Loading 加载覆盖层
private struct LoadingOverlay: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))

            Text(message)
                .font(.body)
                .foregroundColor(.white)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}
