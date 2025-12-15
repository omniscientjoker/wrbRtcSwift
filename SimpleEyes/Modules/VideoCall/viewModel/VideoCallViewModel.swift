//
//  VideoCallViewModel.swift
//  SimpleEyes
//
//  视频通话视图模型 - MVVM 架构
//  负责视频通话功能的完整业务逻辑和状态管理
//

import Foundation
import Combine
import AVFoundation
import WebRTC

/// 视频通话视图模型
///
/// 使用 MVVM 架构管理视频通话功能
/// 主要功能：
/// - WebRTC 信令连接管理
/// - 设备ID配置和管理
/// - 在线设备列表加载
/// - 呼叫发起和接听
/// - 视频轨道管理（本地和远程）
/// - 音视频控制（静音、关闭摄像头）
/// - 画中画模式支持
/// - 权限管理（摄像头和麦克风）
///
/// 使用 @MainActor 确保所有 UI 更新在主线程执行
@MainActor
class VideoCallViewModel: ObservableObject {

    // MARK: - 发布属性

    /// 通话状态
    ///
    /// 表示当前通话的连接状态（空闲/连接中/振铃/已连接/断开/错误）
    @Published var callState: VideoCallState = .idle

    /// 选中的设备
    @Published var selectedDevice: OnlineDevice?

    /// 在线设备列表
    @Published var onlineDevices: [OnlineDevice] = []

    /// 设备列表加载状态
    @Published var isLoadingDevices: Bool = false

    /// 错误消息
    @Published var errorMessage: String?

    /// 本地视频轨道
    ///
    /// 来自本地摄像头的视频流
    @Published var localVideoTrack: RTCVideoTrack?

    /// 远程视频轨道
    ///
    /// 来自对方的视频流
    @Published var remoteVideoTrack: RTCVideoTrack?

    /// 来电设备ID
    @Published var incomingCallFrom: String?

    /// 是否显示来电提示框
    @Published var showIncomingCallAlert: Bool = false

    /// 信令服务器连接状态
    @Published var signalingConnected: Bool = false

    /// 本地设备ID
    @Published var localDeviceId: String = ""

    /// 音频是否启用
    @Published var isAudioEnabled: Bool = true

    /// 视频是否启用
    @Published var isVideoEnabled: Bool = true

    /// 本地视频是否为大屏
    ///
    /// true: 本地视频大屏，false: 远程视频大屏
    @Published var isLocalVideoLarge: Bool = false

    /// 是否处于画中画模式
    @Published var isPiPMode: Bool = false

    /// 是否应该最小化到画中画
    @Published var shouldMinimizeToPiP: Bool = false

    // MARK: - 私有属性

    /// 视频通话管理器
    ///
    /// 负责 WebRTC 连接、信令处理和媒体流管理
    private var videoCallManager: VideoCallManager?

    /// Combine 订阅集合
    private var cancellables = Set<AnyCancellable>()

    /// 画中画管理器
    private var pipManager: PictureInPictureManager?

    // MARK: - 计算属性

    /// 是否可以发起通话
    ///
    /// 条件：已选择设备且当前状态为空闲
    var canStartCall: Bool {
        selectedDevice != nil && callState == .idle
    }

    /// 是否正在通话中
    ///
    /// 包括连接中、振铃中和已连接状态
    var isInCall: Bool {
        switch callState {
        case .connecting, .ringing, .connected:
            return true
        default:
            return false
        }
    }

    /// 状态颜色标识
    ///
    /// 根据通话状态返回对应的颜色名称
    var statusColor: String {
        switch callState {
        case .idle, .disconnected:
            return "gray"
        case .connecting, .ringing:
            return "orange"
        case .connected:
            return "green"
        case .error:
            return "red"
        }
    }

    // MARK: - 初始化

    /// 初始化视频通话视图模型
    ///
    /// 执行初始化操作：
    /// - 加载本地设备ID
    /// - 初始化画中画管理器
    /// - 设置视频轨道监听
    init() {
        // 加载本地设备ID
        localDeviceId = getLocalDeviceId()

        // 初始化画中画管理器
        pipManager = PictureInPictureManager()

        // 监听远端视频轨道变化
        $remoteVideoTrack
            .sink { [weak self] track in
                self?.pipManager?.setupWithVideoTrack(track)
            }
            .store(in: &cancellables)
    }

    // MARK: - 公共方法 - 信令管理

    /// 连接到信令服务器
    ///
    /// 建立 WebSocket 信令连接，用于交换 SDP 和 ICE 信息
    /// 防止重复连接，支持断线重连
    func connectToSignalingServer() {
        // 如果已经有管理器且已连接，不重复连接
        if videoCallManager != nil && signalingConnected {
            print("[VideoCallViewModel] Already connected to signaling server")
            return
        }

        // 如果没有管理器，创建一个
        if videoCallManager == nil {
            let manager = VideoCallManager(deviceId: localDeviceId)
            videoCallManager = manager
            setupCallbacks(for: manager)
        }

        // 连接信令服务器
        let serverURL = APIConfig.wsURL
        videoCallManager?.connectSignaling(serverURL: serverURL)

        print("[VideoCallViewModel] Connecting to signaling server...")
    }

    /// 断开信令服务器连接
    ///
    /// 关闭 WebSocket 连接并清理管理器
    /// 注意：通话中不允许断开
    func disconnectFromSignalingServer() {
        // 如果正在通话中，不允许断开
        if isInCall {
            errorMessage = "通话中无法断开信令连接"
            return
        }

        videoCallManager?.disconnectSignaling()
        videoCallManager = nil
        signalingConnected = false
        print("[VideoCallViewModel] Disconnected from signaling server")
    }

    /// 更新设备ID
    ///
    /// 修改本地设备的标识符
    /// 注意：需要在断开连接后才能修改
    /// - Parameter newId: 新的设备ID
    func updateDeviceId(_ newId: String) {
        guard !newId.isEmpty else { return }

        // 如果正在通话或已连接，需要先断开
        if signalingConnected || isInCall {
            errorMessage = "请先断开连接后再修改设备ID"
            return
        }

        localDeviceId = newId
        UserDefaults.standard.set(newId, forKey: "localDeviceId")
        print("[VideoCallViewModel] Updated device ID to: \(newId)")
    }

    // MARK: - 公共方法 - 设备管理

    /// 加载在线设备列表
    ///
    /// 从服务器获取当前在线的设备列表
    /// 支持保持已选设备的选中状态
    func loadOnlineDevices() {
        guard !isLoadingDevices else { return }

        isLoadingDevices = true
        errorMessage = nil

        APIClient.shared.getOnlineDevices { [weak self] result in
            guard let self = self else { return }

            Task { @MainActor in
                self.isLoadingDevices = false

                switch result {
                case .success(let response):
                    self.onlineDevices = response.devices
                    print("[VideoCallViewModel] Loaded \(response.devices.count) online devices")

                    // 如果之前有选中的设备，尝试保持选中状态
                    if let selectedDeviceId = self.selectedDevice?.deviceId {
                        self.selectedDevice = response.devices.first { $0.deviceId == selectedDeviceId }
                    }

                case .failure(let error):
                    let errorMsg: String
                    switch error {
                    case .networkError:
                        errorMsg = "无法连接到服务器，请检查服务器配置"
                    case .decodingError:
                        errorMsg = "服务器响应格式错误"
                    case .serverError(let message):
                        errorMsg = "服务器错误: \(message)"
                    case .invalidResponse:
                        errorMsg = "无效的服务器响应"
                    }
                    self.errorMessage = errorMsg
                    print("[VideoCallViewModel] Failed to load online devices: \(error)")
                }
            }
        }
    }

    // MARK: - 公共方法 - 通话控制

    /// 开始视频通话
    ///
    /// 发起呼叫流程：
    /// 1. 检查设备选择和状态
    /// 2. 请求摄像头和麦克风权限
    /// 3. 创建通话管理器并连接信令
    /// 4. 向目标设备发起呼叫
    func startCall() {
        guard canStartCall, let device = selectedDevice else { return }

        errorMessage = nil

        // 请求摄像头和麦克风权限
        requestCameraAndMicrophonePermission { [weak self] granted in
            guard let self = self else { return }

            Task { @MainActor in
                if !granted {
                    self.errorMessage = "需要摄像头和麦克风权限才能使用视频通话"
                    self.callState = .error("权限被拒绝")
                    return
                }

                // 如果还没有管理器，创建并连接
                if self.videoCallManager == nil {
                    let manager = VideoCallManager(deviceId: self.getLocalDeviceId())
                    self.videoCallManager = manager
                    self.setupCallbacks(for: manager)

                    // 连接信令服务器
                    let serverURL = APIConfig.wsURL
                    manager.connectSignaling(serverURL: serverURL)
                }

                // 开始通话
                self.videoCallManager?.startCall(to: device.deviceId)
            }
        }
    }

    /// 接受来电
    ///
    /// 响应对方的呼叫请求
    /// 需要先请求权限，然后建立 WebRTC 连接
    func acceptCall() {
        guard incomingCallFrom != nil else { return }

        errorMessage = nil
        showIncomingCallAlert = false

        // 请求权限
        requestCameraAndMicrophonePermission { [weak self] granted in
            guard let self = self else { return }

            Task { @MainActor in
                if !granted {
                    self.errorMessage = "需要摄像头和麦克风权限才能使用视频通话"
                    self.callState = .error("权限被拒绝")
                    return
                }

                // 如果还没有管理器，创建并连接（通常不应该发生，因为已经自动连接了）
                if self.videoCallManager == nil {
                    let manager = VideoCallManager(deviceId: self.getLocalDeviceId())
                    self.videoCallManager = manager
                    self.setupCallbacks(for: manager)

                    // 连接信令服务器
                    let serverURL = APIConfig.wsURL
                    manager.connectSignaling(serverURL: serverURL)
                }

                // 接受通话
                self.videoCallManager?.acceptCall()
                self.incomingCallFrom = nil
            }
        }
    }

    /// 拒绝来电
    ///
    /// 拒绝对方的呼叫请求并清理状态
    func rejectCall() {
        videoCallManager?.rejectCall()
        showIncomingCallAlert = false
        incomingCallFrom = nil
        cleanup()
    }

    /// 结束通话
    ///
    /// 主动挂断当前通话并清理资源
    func endCall() {
        videoCallManager?.endCall()
        cleanup()
    }

    // MARK: - 公共方法 - 音视频控制

    /// 切换音频开关
    ///
    /// 启用或禁用麦克风（静音功能）
    func toggleAudio() {
        isAudioEnabled.toggle()
        videoCallManager?.setAudioEnabled(isAudioEnabled)
        print("[VideoCallViewModel] Audio \(isAudioEnabled ? "enabled" : "disabled")")
    }

    /// 切换视频开关
    ///
    /// 启用或禁用摄像头
    func toggleVideo() {
        isVideoEnabled.toggle()
        videoCallManager?.setVideoEnabled(isVideoEnabled)
        print("[VideoCallViewModel] Video \(isVideoEnabled ? "enabled" : "disabled")")
    }

    /// 切换大小屏
    ///
    /// 交换本地和远程视频的显示大小
    func toggleVideoSize() {
        isLocalVideoLarge.toggle()
        print("[VideoCallViewModel] Switched to \(isLocalVideoLarge ? "local" : "remote") video large")
    }

    // MARK: - 公共方法 - 画中画管理

    /// 切换画中画模式
    ///
    /// 启动或停止画中画显示
    func togglePiPMode() {
        guard let pipManager = pipManager else {
            print("[VideoCallViewModel] PiP manager not available")
            return
        }

        if pipManager.isPiPActive {
            // 停止画中画
            pipManager.stopPictureInPicture()
        } else {
            // 开始画中画
            pipManager.startPictureInPicture()
        }
    }

    /// 从画中画恢复到全屏
    ///
    /// 关闭画中画窗口并返回正常显示模式
    func restoreFromPiP() {
        pipManager?.stopPictureInPicture()
        isPiPMode = false
        shouldMinimizeToPiP = false
        print("[VideoCallViewModel] Restored from PiP mode")
    }

    // MARK: - 私有方法 - 回调设置

    /// 设置通话管理器的回调
    ///
    /// 配置所有事件回调，包括信令状态、通话状态、视频轨道和来电
    /// - Parameter manager: 视频通话管理器实例
    private func setupCallbacks(for manager: VideoCallManager) {
        // 信令连接状态回调
        manager.onSignalingConnected = { [weak self] in
            Task { @MainActor in
                self?.signalingConnected = true
                print("[VideoCallViewModel] Signaling connected")
            }
        }

        manager.onSignalingDisconnected = { [weak self] in
            Task { @MainActor in
                self?.signalingConnected = false
                print("[VideoCallViewModel] Signaling disconnected")
            }
        }

        manager.onStateChanged = { [weak self] (state: VideoCallState) in
            Task { @MainActor in
                self?.callState = state
                if case .error(let message) = state {
                    self?.errorMessage = message
                }

                // 当通话断开或出错时，自动清理资源
                if case .disconnected = state {
                    // 延迟清理，让用户看到"已断开"状态
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
                        await MainActor.run {
                            self?.cleanup()
                        }
                    }
                } else if case .error = state {
                    // 错误时也延迟清理
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                        await MainActor.run {
                            self?.cleanup()
                        }
                    }
                }
            }
        }

        manager.onLocalVideoTrack = { [weak self] (track: RTCVideoTrack) in
            Task { @MainActor in
                self?.localVideoTrack = track
            }
        }

        manager.onRemoteVideoTrack = { [weak self] (track: RTCVideoTrack) in
            Task { @MainActor in
                self?.remoteVideoTrack = track
            }
        }

        manager.onIncomingCall = { [weak self] (fromDeviceId: String) in
            Task { @MainActor in
                self?.incomingCallFrom = fromDeviceId
                self?.showIncomingCallAlert = true
            }
        }
    }

    // MARK: - 私有方法 - 权限管理

    /// 请求摄像头和麦克风权限
    ///
    /// 按顺序请求视频和音频权限
    /// - Parameter completion: 权限结果回调，true 表示全部授权
    nonisolated private func requestCameraAndMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        _ = AVCaptureDevice.authorizationStatus(for: .audio)

        // 检查摄像头权限
        switch cameraStatus {
        case .authorized:
            // 摄像头已授权，检查麦克风
            checkMicrophonePermission(completion: completion)

        case .notDetermined:
            // 请求摄像头权限
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.checkMicrophonePermission(completion: completion)
                } else {
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }

        case .denied, .restricted:
            DispatchQueue.main.async {
                completion(false)
            }

        @unknown default:
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }

    /// 检查麦克风权限
    ///
    /// 验证或请求音频录制权限
    /// - Parameter completion: 权限结果回调
    nonisolated private func checkMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        switch audioStatus {
        case .authorized:
            DispatchQueue.main.async {
                completion(true)
            }

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }

        case .denied, .restricted:
            DispatchQueue.main.async {
                completion(false)
            }

        @unknown default:
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }

    // MARK: - 私有方法 - 工具方法

    /// 获取或生成本地设备ID
    ///
    /// 从 UserDefaults 读取已保存的ID，如果不存在则生成新ID
    /// - Returns: 设备ID字符串
    private func getLocalDeviceId() -> String {
        // 生成或获取本地设备ID
        // 这里使用 UUID，实际应用中可以使用设备唯一标识
        if let savedId = UserDefaults.standard.string(forKey: "localDeviceId") {
            return savedId
        } else {
            let newId = "app-\(UUID().uuidString.prefix(8))"
            UserDefaults.standard.set(newId, forKey: "localDeviceId")
            return newId
        }
    }

    /// 清理通话资源
    ///
    /// 在通话结束时清理所有状态和资源
    /// 注意：不清理 videoCallManager，以保持信令连接接收新来电
    private func cleanup() {
        // 清理画中画
        pipManager?.cleanup()

        // 清理视频轨道
        localVideoTrack = nil
        remoteVideoTrack = nil

        // 重置状态
        callState = VideoCallState.idle
        errorMessage = nil

        // 重置通话控制状态
        isAudioEnabled = true
        isVideoEnabled = true
        isLocalVideoLarge = false
        isPiPMode = false
        shouldMinimizeToPiP = false

        // 不清空 videoCallManager，保持信令连接以接收新的来电
        // videoCallManager 只在用户主动断开连接时清理
    }

    // MARK: - 资源清理

    /// 析构时清理资源
    ///
    /// 在对象销毁前异步清理所有通话资源
    nonisolated private func cleanupOnDeinit() {
        Task { @MainActor in
            cleanup()
        }
    }

    /// 析构函数
    ///
    /// 自动清理通话资源
    deinit {
        cleanupOnDeinit()
    }
}
