//
//  SimpleEyesApp.swift
//  SimpleEyes
//
//  Created by 姜淼 on 2025/12/10.
//
//  SimpleEyes 应用程序主入口
//  该文件定义了应用的生命周期和全局配置
//

import SwiftUI

/// SimpleEyes 应用程序主结构体
///
/// 这是应用的入口点，使用 @main 属性标记。负责：
/// - 初始化应用全局配置（如导航栏主题）
/// - 定义应用的根视图场景
/// - 管理应用级别的状态和生命周期
@main
struct SimpleEyesApp: App {

    // MARK: - 初始化

    /// 应用初始化方法
    ///
    /// 在应用启动时自动调用，用于执行全局配置
    /// 当前配置包括：
    /// - 导航栏全局主题设置
    init() {
        // 配置全局导航栏主题
        setupNavigationBar()
    }

    // MARK: - 场景配置

    /// 应用场景定义
    ///
    /// 定义应用的窗口场景，包含应用的根视图
    /// - Returns: 返回 WindowGroup 场景，其中包含 ContentView 作为根视图
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    // MARK: - 全局配置

    /// 配置全局导航栏外观
    ///
    /// 使用 NavigationBarConfig 设置应用统一的导航栏主题
    /// 包括背景色、标题颜色、按钮颜色等
    ///
    /// 支持的主题类型：
    /// - defaultTheme: 默认蓝色主题
    /// - lightTheme: 浅色主题
    /// - 自定义主题：可通过 NavigationBarTheme 创建
    ///
    /// - Note: 此方法在应用启动时仅调用一次
    private func setupNavigationBar() {
        // 使用默认蓝色主题
        NavigationBarConfig.setupGlobalAppearance(theme: .defaultTheme)

        // 如果需要使用浅色主题，取消注释下面这行
        // NavigationBarConfig.setupGlobalAppearance(theme: .lightTheme)

        // 如果需要使用自定义主题，可以这样：
        // let customTheme = NavigationBarTheme(
        //     backgroundColor: .systemTeal,
        //     titleColor: .white,
        //     tintColor: .white
        // )
        // NavigationBarConfig.setupGlobalAppearance(theme: customTheme)
    }
}
