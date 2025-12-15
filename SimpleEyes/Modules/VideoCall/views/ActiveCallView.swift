//
//  ActiveCallView.swift
//  SimpleEyes
//
//  活动视频通话页面 - MVVM 架构
//  提供视频通话过程中的视频显示和通话控制功能
//

import SwiftUI
import WebRTC
import AVKit

/// 活动视频通话主视图
///
/// 显示正在进行的视频通话，提供实时视频流和通话控制
/// 功能包括：
/// - 本地和远程视频流显示
/// - 大小屏切换（画中画效果）
/// - 通话状态实时展示
/// - 音视频控制（静音、关闭摄像头）
/// - 通话挂断功能
/// - 画中画模式支持
struct ActiveCallView: View {

    // MARK: - 属性

    /// 视频通话视图模型（观察者模式）
    ///
    /// 管理通话状态、视频轨道和控制逻辑
    @ObservedObject var viewModel: VideoCallViewModel

    /// 关闭视图的环境变量
    @Environment(\.dismiss) private var dismiss

    // MARK: - 视图布局

    /// 构建活动通话视图层级
    ///
    /// 包含视频显示区域、状态栏和控制栏
    /// - Returns: 返回全屏通话视图
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // 正常模式：显示双方视频
            NormalModeView(viewModel: viewModel)
            // 顶部状态栏
            VStack {
                TopStatusBar(viewModel: viewModel, dismiss: dismiss)
                Spacer()
            }
            // 底部控制栏
            VStack {
                Spacer()
                ControlBar(viewModel: viewModel, onHangup: {
                    viewModel.endCall()
                    dismiss()
                })
                .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .onDisappear {}
        .navigationBar(
            title: "视频通话中",
            displayMode: .inline,
            trackingParameters: [
                "callState": viewModel.callState.displayText,
                "isAudioEnabled": viewModel.isAudioEnabled,
                "isVideoEnabled": viewModel.isVideoEnabled,
                "from": "video_call"
            ]
        )
    }
}

// MARK: - 视频显示模式

/// 正常模式视图（显示双方视频）
///
/// 提供大屏+小屏的画中画布局
/// - 大屏显示主视频（可切换为本地或远程）
/// - 小屏显示次视频（右上角浮动）
/// - 点击小屏可切换大小屏视频源
struct NormalModeView: View {

    // MARK: - 属性

    /// 视频通话视图模型（观察者模式）
    @ObservedObject var viewModel: VideoCallViewModel

    // MARK: - 视图布局

    /// 构建视频显示布局
    ///
    /// - Returns: 返回大小屏视频组合视图
    var body: some View {
        ZStack {
            // 大屏视频（背景）
            if viewModel.isLocalVideoLarge {
                // 本地视频大屏
                if let localTrack = viewModel.localVideoTrack {
                    WebRTCVideoView(videoTrack: localTrack)
                        .ignoresSafeArea()
                } else {
                    PlaceholderView(text: "本地视频加载中...")
                }
            } else {
                // 远程视频大屏
                if let remoteTrack = viewModel.remoteVideoTrack {
                    WebRTCVideoView(videoTrack: remoteTrack)
                        .ignoresSafeArea()
                } else {
                    PlaceholderView(text: viewModel.callState.displayText)
                }
            }

            // 小屏视频（画中画位置）
            VStack {
                HStack {
                    Spacer()
                    SmallVideoView(
                        viewModel: viewModel,
                        isLocal: !viewModel.isLocalVideoLarge
                    )
                    .padding()
                }
                Spacer()
            }
        }
    }
}

// MARK: - 小屏视频视图

/// 小屏视频视图
///
/// 显示画中画模式下的次要视频流
/// 特性：
/// - 固定尺寸（120x160）
/// - 圆角边框
/// - 阴影效果
/// - 点击切换大小屏
struct SmallVideoView: View {

    // MARK: - 属性

    /// 视频通话视图模型（观察者模式）
    @ObservedObject var viewModel: VideoCallViewModel

    /// 是否显示本地视频
    ///
    /// true: 显示本地摄像头视频
    /// false: 显示远程对方视频
    let isLocal: Bool

    // MARK: - 视图布局

    /// 构建小屏视频视图
    ///
    /// - Returns: 返回带边框和交互的小视频视图
    var body: some View {
        Group {
            if isLocal {
                // 显示本地视频
                if let localTrack = viewModel.localVideoTrack {
                    WebRTCVideoView(videoTrack: localTrack)
                } else {
                    PlaceholderView(text: "本地视频", small: true)
                }
            } else {
                // 显示远程视频
                if let remoteTrack = viewModel.remoteVideoTrack {
                    WebRTCVideoView(videoTrack: remoteTrack)
                } else {
                    PlaceholderView(text: "远程视频", small: true)
                }
            }
        }
        .frame(width: 120, height: 160)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 2)
        )
        .shadow(radius: 10)
        .onTapGesture {
            // 点击切换大小屏
            viewModel.toggleVideoSize()
        }
    }
}

// MARK: - 顶部状态栏

/// 顶部状态栏视图
///
/// 显示通话状态和返回按钮
/// 包含：
/// - 返回按钮（带确认挂断）
/// - 通话状态指示器（连接中/已连接/错误等）
/// - 状态颜色标识
struct TopStatusBar: View {

    // MARK: - 属性

    /// 视频通话视图模型（观察者模式）
    @ObservedObject var viewModel: VideoCallViewModel

    /// 关闭视图的动作
    let dismiss: DismissAction

    // MARK: - 视图布局

    /// 构建顶部状态栏
    ///
    /// - Returns: 返回状态栏视图
    var body: some View {
        HStack {
            // 返回按钮
            Button(action: {
                viewModel.endCall()
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }

            Spacer()

            // 状态指示器
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                Text(viewModel.callState.displayText)
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(20)

            Spacer()

            // 占位，保持居中
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal)
        .padding(.top, 50)
    }

    // MARK: - 辅助方法

    /// 根据通话状态返回对应颜色
    ///
    /// - 空闲/已断开：灰色
    /// - 连接中/振铃中：橙色
    /// - 已连接：绿色
    /// - 错误：红色
    private var statusColor: Color {
        switch viewModel.callState {
        case .idle, .disconnected:
            return .gray
        case .connecting, .ringing:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }
}

// MARK: - 底部控制栏

/// 底部控制栏视图
///
/// 提供通话过程中的各种控制功能
/// 包含：
/// - 静音/取消静音按钮
/// - 挂断按钮（红色醒目）
/// - 开关摄像头按钮
/// - 切换大小屏按钮
/// - 画中画模式按钮
struct ControlBar: View {

    // MARK: - 属性

    /// 视频通话视图模型（观察者模式）
    @ObservedObject var viewModel: VideoCallViewModel

    /// 挂断通话的回调闭包
    let onHangup: () -> Void

    // MARK: - 视图布局

    /// 构建控制栏视图
    ///
    /// - Returns: 返回带所有控制按钮的视图
    var body: some View {
        VStack(spacing: 24) {
            // 主要控制按钮
            HStack(spacing: 40) {
                // 静音按钮
                ControlButton(
                    icon: viewModel.isAudioEnabled ? "mic.fill" : "mic.slash.fill",
                    isActive: !viewModel.isAudioEnabled,
                    action: { viewModel.toggleAudio() }
                )

                // 挂断按钮
                Button(action: onHangup) {
                    Image(systemName: "phone.down.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(Color.red)
                        .clipShape(Circle())
                        .shadow(color: .red.opacity(0.5), radius: 10, x: 0, y: 5)
                }

                // 关闭视频按钮
                ControlButton(
                    icon: viewModel.isVideoEnabled ? "video.fill" : "video.slash.fill",
                    isActive: !viewModel.isVideoEnabled,
                    action: { viewModel.toggleVideo() }
                )
            }

            // 次要控制按钮
            HStack(spacing: 40) {
                // 切换大小屏按钮
                ControlButton(
                    icon: "arrow.up.left.and.arrow.down.right",
                    label: "切换",
                    size: .small,
                    action: { viewModel.toggleVideoSize() }
                )

                // 画中画按钮
                ControlButton(
                    icon: "pip.enter",
                    label: "画中画",
                    isActive: false,
                    size: .small,
                    action: { viewModel.togglePiPMode() }
                )
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
        .background(
            Color.black.opacity(0.6)
                .blur(radius: 10)
        )
        .cornerRadius(30)
    }
}

// MARK: - 控制按钮组件

/// 控制按钮视图
///
/// 可复用的圆形按钮组件，支持大小样式和激活状态
struct ControlButton: View {

    // MARK: - 属性

    /// 按钮图标名称（SF Symbol）
    let icon: String

    /// 按钮标签文本（可选）
    var label: String?

    /// 是否为激活状态
    ///
    /// 激活状态显示高亮背景
    var isActive: Bool = false

    /// 按钮尺寸
    var size: Size = .large

    /// 按钮点击回调
    let action: () -> Void

    // MARK: - 尺寸枚举

    /// 按钮尺寸定义
    enum Size {
        case large  // 大尺寸（主要控制）
        case small  // 小尺寸（次要控制）

        /// 按钮直径
        var dimension: CGFloat {
            switch self {
            case .large: return 60
            case .small: return 50
            }
        }

        /// 图标大小
        var iconSize: CGFloat {
            switch self {
            case .large: return 28
            case .small: return 22
            }
        }
    }

    // MARK: - 视图布局

    /// 构建控制按钮
    ///
    /// - Returns: 返回圆形图标按钮（可带标签）
    var body: some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: size.iconSize))
                    .foregroundColor(.white)
                    .frame(width: size.dimension, height: size.dimension)
                    .background(isActive ? Color.white.opacity(0.3) : Color.gray.opacity(0.3))
                    .clipShape(Circle())
            }

            if let label = label {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

// MARK: - 占位视图

/// 占位视图
///
/// 在视频未加载时显示的占位内容
/// 包含加载指示器和提示文本
struct PlaceholderView: View {

    // MARK: - 属性

    /// 占位提示文本
    let text: String

    /// 是否为小尺寸模式
    ///
    /// 小尺寸模式不显示进度指示器
    var small: Bool = false

    // MARK: - 视图布局

    /// 构建占位视图
    ///
    /// - Returns: 返回占位内容视图
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)

            VStack(spacing: 12) {
                if !small {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.5)
                }

                Text(text)
                    .foregroundColor(.white)
                    .font(small ? .caption : .body)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

// MARK: - 预览

/// SwiftUI 预览提供者
///
/// 用于在 Xcode 中实时预览 ActiveCallView 的显示效果
#Preview {
    NavigationView {
        ActiveCallView(viewModel: VideoCallViewModel())
    }
}
