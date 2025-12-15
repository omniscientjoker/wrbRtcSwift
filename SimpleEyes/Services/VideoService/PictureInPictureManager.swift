//
//  PictureInPictureManager.swift
//  SimpleEyes
//
//  画中画管理器 - 实现 WebRTC 视频的画中画功能
//  结合 AVPictureInPictureController 和自定义视频渲染器
//

import Foundation
import AVKit
import WebRTC
import Combine

/// 画中画管理器
///
/// 管理 WebRTC 视频流的画中画（PiP）功能
///
/// ## 功能特性
/// - WebRTC 视频流的画中画支持
/// - 自动视频帧转换（RTCVideoFrame -> CMSampleBuffer）
/// - PiP 状态管理
/// - 后台播放支持
///
/// ## 技术实现
/// - 使用 AVSampleBufferDisplayLayer 渲染视频
/// - 自定义 WebRTCPiPVideoRenderer 转换视频帧
/// - AVPictureInPictureController 管理 PiP 窗口
///
/// ## 使用示例
/// ```swift
/// let pipManager = PictureInPictureManager()
/// pipManager.setupWithVideoTrack(remoteVideoTrack)
/// pipManager.startPictureInPicture()
/// ```
///
/// - Note: 需要在 Info.plist 中启用 "Audio, AirPlay, and Picture in Picture" 后台模式
@MainActor
class PictureInPictureManager: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var isPiPActive = false
    @Published var isPiPPossible = false

    // MARK: - Private Properties

    private var pipController: AVPictureInPictureController?
    private var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer?
    private var videoTrack: RTCVideoTrack?
    private var videoRenderer: WebRTCPiPVideoRenderer?
    private var pipPossibleObservation: NSKeyValueObservation?

    // MARK: - Initialization

    override init() {
        super.init()
        // 不需要配置音频会话，WebRTC 已经管理了音频会话
        // setupAudioSession()
    }

    deinit {
        pipPossibleObservation?.invalidate()
    }

    // MARK: - Public Methods

    /// 设置视频轨道
    func setupWithVideoTrack(_ track: RTCVideoTrack?) {
        // 移除旧的渲染器
        if let oldTrack = self.videoTrack, let oldRenderer = self.videoRenderer {
            oldTrack.remove(oldRenderer)
            self.videoRenderer = nil
        }

        self.videoTrack = track

        // 只有在有视频轨道时才设置 PiP
        guard let track = track else {
            print("[PiPManager] No video track, skipping PiP setup")
            return
        }

        // 设置 PiP（如果还没有设置）
        if pipController == nil {
            setupPictureInPicture()
        }

        // 添加新的渲染器
        if let layer = sampleBufferDisplayLayer {
            let renderer = WebRTCPiPVideoRenderer(sampleBufferDisplayLayer: layer)
            track.add(renderer)
            self.videoRenderer = renderer
            print("[PiPManager] Video renderer attached to track")
        }
    }

    /// 开始画中画
    func startPictureInPicture() {
        guard let pipController = pipController,
              pipController.isPictureInPicturePossible else {
            print("[PiPManager] PiP is not possible")
            return
        }

        pipController.startPictureInPicture()
        print("[PiPManager] Starting PiP")
    }

    /// 停止画中画
    func stopPictureInPicture() {
        pipController?.stopPictureInPicture()
        print("[PiPManager] Stopping PiP")
    }

    /// 清理资源
    func cleanup() {
        stopPictureInPicture()

        // 移除渲染器
        if let track = videoTrack, let renderer = videoRenderer {
            track.remove(renderer)
        }

        // 移除观察者
        pipPossibleObservation?.invalidate()
        pipPossibleObservation = nil

        pipController = nil
        sampleBufferDisplayLayer = nil
        videoTrack = nil
        videoRenderer = nil
        print("[PiPManager] Cleaned up")
    }

    // MARK: - Private Methods

    private func setupPictureInPicture() {
        // 创建 AVSampleBufferDisplayLayer
        let displayLayer = AVSampleBufferDisplayLayer()
        displayLayer.videoGravity = .resizeAspect

        // 设置 control time base（对于实时流很重要）
        var timebase: CMTimebase?
        let status = CMTimebaseCreateWithSourceClock(
            allocator: kCFAllocatorDefault,
            sourceClock: CMClockGetHostTimeClock(),
            timebaseOut: &timebase
        )

        if status == noErr, let timebase = timebase {
            displayLayer.controlTimebase = timebase
            CMTimebaseSetTime(timebase, time: .zero)
            CMTimebaseSetRate(timebase, rate: 1.0)
            print("[PiPManager] Control timebase configured")
        } else {
            print("[PiPManager] Failed to create control timebase: \(status)")
        }

        self.sampleBufferDisplayLayer = displayLayer

        // 检查 PiP 是否支持
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("[PiPManager] PiP is not supported on this device")
            return
        }

        // 创建 PiP 控制器
        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        )

        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = false

        self.pipController = controller
        self.isPiPPossible = controller.isPictureInPicturePossible

        // 观察 isPictureInPicturePossible 的变化
        pipPossibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.new]) { [weak self] controller, change in
            DispatchQueue.main.async {
                guard let self else { return }
                let newValue = change.newValue ?? false
                self.isPiPPossible = newValue
                print("[PiPManager] PiP possible changed to: \(newValue)")
            }
        }

        print("[PiPManager] PiP controller created, possible: \(controller.isPictureInPicturePossible)")
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension PictureInPictureManager: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            print("[PiPManager] Will start PiP")
        }
    }

    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            isPiPActive = true
            print("[PiPManager] Did start PiP")
        }
    }

    nonisolated func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            print("[PiPManager] Will stop PiP")
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            isPiPActive = false
            print("[PiPManager] Did stop PiP")
        }
    }

    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                                failedToStartPictureInPictureWithError error: Error) {
        Task { @MainActor in
            print("[PiPManager] Failed to start PiP: \(error.localizedDescription)")
        }
    }

    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                                restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        Task { @MainActor in
            // 用户点击 PiP 窗口恢复界面
            print("[PiPManager] Restore UI requested")
            completionHandler(true)
        }
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate

extension PictureInPictureManager: AVPictureInPictureSampleBufferPlaybackDelegate {
    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                                setPlaying playing: Bool) {
        Task { @MainActor in
            print("[PiPManager] Set playing: \(playing)")
            // WebRTC 视频流不需要播放/暂停控制
        }
    }

    nonisolated func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        // 返回无限时间范围（实时流）
        return CMTimeRange(start: .zero, duration: .positiveInfinity)
    }

    nonisolated func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        // WebRTC 实时流始终在播放
        return false
    }

    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                                didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        Task { @MainActor in
            print("[PiPManager] Did transition to render size: \(newRenderSize.width)x\(newRenderSize.height)")
        }
    }

    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                                skipByInterval skipInterval: CMTime,
                                                completion completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            print("[PiPManager] Skip by interval: \(skipInterval)")
            completionHandler()
        }
    }
}
