//
//  WebRTCVideoView.swift
//  SimpleEyes
//
//  WebRTC 视频渲染视图组件
//  提供将 WebRTC 视频轨道渲染到 SwiftUI 视图的桥接功能
//

import SwiftUI
import WebRTC

/// WebRTC 视频渲染视图
///
/// 使用 UIViewRepresentable 协议将 UIKit 的 RTCMTLVideoView 封装为 SwiftUI 视图
/// 主要功能：
/// - 渲染 WebRTC 视频轨道（RTCVideoTrack）
/// - 支持硬件加速的 Metal 渲染
/// - 自动适配视频比例（ScaleAspectFill）
/// - 生命周期管理和资源清理
///
/// 使用示例：
/// ```swift
/// if let videoTrack = webRTCClient.localVideoTrack {
///     WebRTCVideoView(videoTrack: videoTrack)
///         .frame(width: 200, height: 300)
/// }
/// ```
struct WebRTCVideoView: UIViewRepresentable {

    // MARK: - 属性

    /// WebRTC 视频轨道
    ///
    /// 可选类型，允许在视频轨道未就绪时显示空视图
    /// 当视频轨道可用时，会自动添加到渲染视图中
    let videoTrack: RTCVideoTrack?

    // MARK: - UIViewRepresentable 协议实现

    /// 创建并配置 RTCMTLVideoView
    ///
    /// 在视图首次显示时调用，创建底层的 UIKit 视图
    /// 配置项包括：
    /// - 内容模式设置为填充并保持宽高比
    /// - Metal 加速渲染支持
    ///
    /// - Parameter context: SwiftUI 提供的上下文信息
    /// - Returns: 配置好的 RTCMTLVideoView 实例
    func makeUIView(context: Context) -> RTCMTLVideoView {
        let videoView = RTCMTLVideoView()
        // 设置视图内容模式为等比填充
        videoView.contentMode = .scaleAspectFill
        // 设置视频内容渲染模式为等比填充
        videoView.videoContentMode = .scaleAspectFill

        #if arch(arm64)
        // ARM64 架构特定配置（确保在 iOS 设备上正确渲染）
        videoView.videoContentMode = .scaleAspectFill
        #endif

        return videoView
    }

    /// 更新视频渲染视图
    ///
    /// 当 videoTrack 属性变化时调用
    /// 将新的视频轨道添加到渲染视图中，开始显示视频画面
    ///
    /// - Parameters:
    ///   - uiView: 需要更新的 RTCMTLVideoView 实例
    ///   - context: SwiftUI 提供的上下文信息
    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        if let videoTrack = videoTrack {
            // 将视频轨道添加到渲染视图
            videoTrack.add(uiView)
        }
    }

    /// 清理视频渲染视图
    ///
    /// 在视图销毁时调用，释放渲染资源
    /// 清除当前帧缓存，避免内存泄漏
    ///
    /// - Parameters:
    ///   - uiView: 要清理的 RTCMTLVideoView 实例
    ///   - coordinator: 协调器（本视图未使用）
    static func dismantleUIView(_ uiView: RTCMTLVideoView, coordinator: ()) {
        // 清除渲染帧，释放资源
        uiView.renderFrame(nil)
    }
}
