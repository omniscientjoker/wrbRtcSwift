//
//  LiveVideoView.swift
//  SimpleEyes
//
//  视频直播页面 - MVVM 架构
//  提供实时视频流播放功能，支持设备ID输入和视频流播放
//

import SwiftUI
import AVFoundation
import AVKit

/// 视频直播主视图
///
/// 使用 MVVM 架构模式，通过 LiveVideoViewModel 管理直播流
/// 功能包括：
/// - 设备ID输入和验证
/// - 实时视频流播放
/// - 视频流开始/停止控制
/// - 加载状态和错误处理
struct LiveVideoView: View {

    // MARK: - 视图模型

    /// 直播视图模型
    ///
    /// 使用 @StateObject 确保视图生命周期内的单一实例
    /// 负责设备ID管理、视频流URL获取和播放状态控制
    @StateObject private var viewModel: LiveVideoViewModel

    // MARK: - 初始化方法

    /// 初始化直播视图
    ///
    /// - Parameter deviceId: 设备ID，默认为空字符串
    init(deviceId: String = "") {
        _viewModel = StateObject(wrappedValue: LiveVideoViewModel(deviceId: deviceId))
    }

    // MARK: - 视图布局

    /// 构建直播视图层级
    ///
    /// 根据视频流状态显示不同内容：
    /// - 无流媒体URL：显示设备ID输入界面
    /// - 有流媒体URL：显示视频播放器
    /// - Returns: 返回直播视图
    var body: some View {
        VStack(spacing: 20) {
            if let url = viewModel.streamUrl {
                // 视频播放区域
                VideoPlayerPlaceholder(url: url, onStop: viewModel.stopStream)
            } else {
                // 输入区域
                LiveInputSection(viewModel: viewModel)
            }

            Spacer()
        }
        .navigationBar(
            title: "视频直播",
            displayMode: .inline,
            trackingParameters: [
                "deviceId": viewModel.deviceIdInput,
                "isStreaming": viewModel.streamUrl != nil,
                "from": "device_detail"
            ]
        )
    }
}

// MARK: - 输入区域组件

/// 直播输入区域视图
///
/// 提供设备ID输入和开始直播按钮
/// 包括：
/// - 设备ID输入框
/// - 输入验证和错误提示
/// - 开始直播按钮（带加载状态）
struct LiveInputSection: View {

    // MARK: - 属性

    /// 关联的直播视图模型
    @ObservedObject var viewModel: LiveVideoViewModel

    // MARK: - 视图布局

    /// 构建输入区域视图
    ///
    /// 垂直布局：图标、标题、输入框、错误提示、开始按钮
    /// - Returns: 返回输入区域视图
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("实时视频直播")
                .font(.title2)
                .fontWeight(.bold)

            // 设备ID输入框
            VStack(alignment: .leading, spacing: 8) {
                Text("设备ID")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("输入设备ID", text: $viewModel.deviceIdInput)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            // 开始直播按钮
            Button(action: viewModel.startLiveStream) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Label("开始直播", systemImage: "play.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canStartLive)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
        .padding()
    }
}

/// 视频播放器占位视图
///
/// 显示实际的视频播放器和停止按钮
/// 包括：
/// - 视频播放器区域（300pt高度，圆角）
/// - 停止播放按钮
struct VideoPlayerPlaceholder: View {

    // MARK: - 属性

    /// 视频流URL地址
    let url: String

    /// 停止播放回调闭包
    let onStop: () -> Void

    // MARK: - 视图布局

    /// 构建视频播放器视图
    ///
    /// 垂直布局：视频播放器、停止按钮
    /// - Returns: 返回视频播放器视图
    var body: some View {
        VStack(spacing: 0) {
            // 使用实际的视频播放器
            VideoPlayerView(url: url)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()

            // 停止按钮
            Button(action: onStop) {
                Label("停止播放", systemImage: "stop.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding(.horizontal)
        }
    }
}

// MARK: - 快速入口视图

/// 快速直播视图
///
/// 从主页快速入口进入的直播视图
/// 提供独立的导航容器和页面追踪
struct QuickLiveView: View {

    // MARK: - 视图布局

    /// 构建快速直播视图
    ///
    /// 包装在 NavigationView 中，提供独立的导航栈
    /// - Returns: 返回快速直播视图
    var body: some View {
        NavigationView {
            LiveInputNavigator()
                .navigationBar(
                    title: "视频直播",
                    trackingParameters: [
                        "from": "quick_launch"
                    ]
                )
        }
    }
}

/// 直播输入导航视图
///
/// 快速入口的设备ID输入和导航界面
/// 允许用户输入设备ID后导航到直播页面
struct LiveInputNavigator: View {

    // MARK: - 状态属性

    /// 设备ID输入框文本
    @State private var deviceIdInput: String = ""

    // MARK: - 视图布局

    /// 构建输入导航视图
    ///
    /// 提供设备ID输入和导航到直播页面的入口
    /// - Returns: 返回输入导航视图
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("快速直播")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                Text("设备ID")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("输入设备ID", text: $deviceIdInput)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal)

            NavigationLink(destination: LiveVideoView(deviceId: deviceIdInput)) {
                Label("开始观看", systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(deviceIdInput.isEmpty)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

// MARK: - 说明
// VideoPlayerView 已经在 Services/VideoService/VideoPlayerView.swift 中定义

// MARK: - 预览

/// SwiftUI 预览提供者
///
/// 用于在 Xcode 中实时预览 LiveVideoView 的显示效果
#Preview {
    LiveVideoView(deviceId: "device-001")
}
