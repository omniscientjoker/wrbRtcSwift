//
//  ContentView.swift
//  SimpleEyes
//
//  Created by 姜淼 on 2025/12/10.
//
//  应用主视图
//  定义了应用的主界面结构，包含底部标签栏导航
//

import SwiftUI

/// 应用主内容视图
///
/// 这是应用的根视图，包含底部标签栏（TabView）导航
/// 提供以下功能模块：
/// - 视频直播：实时查看监控设备视频流
/// - 视频回放：查看历史录像回放
/// - 语音对讲：与设备进行双向语音通话
/// - 视频通话：WebRTC 视频通话功能
/// - 设置：应用配置和服务器设置
struct ContentView: View {

    // MARK: - 状态属性

    /// 当前选中的标签页索引
    ///
    /// 用于跟踪和控制底部标签栏的当前选中项
    /// 默认值为 0，表示首页（直播页面）
    @State private var selectedTab = 0

    // MARK: - 视图布局

    /// 构建视图层级
    ///
    /// 使用 TabView 组织多个功能模块，每个模块对应一个标签页
    /// - Returns: 返回包含所有功能模块的标签视图
    var body: some View {
        TabView(selection: $selectedTab) {
            // 设备列表（已注释，暂未使用）
//            DeviceListView()
//                .tabItem {
//                    Label("设备", systemImage: "video.circle.fill")
//                }
//                .tag(0)

            // 视频直播模块
            // 提供快速访问监控设备实时视频流功能
            QuickLiveView()
                .tabItem {
                    Label("直播", systemImage: "play.circle.fill")
                }
                .tag(0)

            // 视频回放模块
            // 提供历史录像查看和回放功能
            QuickPlaybackView()
                .tabItem {
                    Label("回放", systemImage: "film.fill")
                }
                .tag(1)

            // 语音对讲模块
            // 提供与监控设备进行双向语音通话功能
            QuickIntercomView()
                .tabItem {
                    Label("对讲", systemImage: "mic.fill")
                }
                .tag(2)

            // 视频通话模块
            // 使用 WebRTC 技术实现视频通话功能
            // 使用 NavigationView 包装以支持导航功能
            NavigationView {
                VideoCallView()
            }
            .tabItem {
                Label("视频", systemImage: "video.fill")
            }
            .tag(3)

            // 设置模块
            // 提供应用配置、服务器设置等功能
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
    }
}

// MARK: - 预览

/// SwiftUI 预览提供者
///
/// 用于在 Xcode 中实时预览 ContentView 的显示效果
#Preview {
    ContentView()
}
