import Foundation
import Combine
import AVFoundation
import WebRTC

// VideoCallState 和 VideoCallManager 在同一模块中，应该可以直接访问

@MainActor
class VideoCallViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var callState: VideoCallState = .idle
    @Published var selectedDevice: OnlineDevice?
    @Published var onlineDevices: [OnlineDevice] = []
    @Published var isLoadingDevices: Bool = false
    @Published var errorMessage: String?

    // 视频轨道
    @Published var localVideoTrack: RTCVideoTrack?
    @Published var remoteVideoTrack: RTCVideoTrack?

    // 来电信息
    @Published var incomingCallFrom: String?
    @Published var showIncomingCallAlert: Bool = false

    // 信令连接状态
    @Published var signalingConnected: Bool = false
    @Published var localDeviceId: String = ""

    // 通话控制状态
    @Published var isAudioEnabled: Bool = true
    @Published var isVideoEnabled: Bool = true
    @Published var isLocalVideoLarge: Bool = false  // true: 本地视频大屏，false: 远程视频大屏
    @Published var isPiPMode: Bool = false  // 画中画模式
    @Published var shouldMinimizeToPiP: Bool = false  // 是否应该最小化到画中画

    // MARK: - Private Properties

    private var videoCallManager: VideoCallManager?
    private var cancellables = Set<AnyCancellable>()
    private var pipManager: PictureInPictureManager?

    // MARK: - Computed Properties

    var canStartCall: Bool {
        selectedDevice != nil && callState == .idle
    }

    var isInCall: Bool {
        switch callState {
        case .connecting, .ringing, .connected:
            return true
        default:
            return false
        }
    }

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

    // MARK: - Initialization

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

    // MARK: - Public Methods

    /// 连接到信令服务器
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

    /// 加载在线设备列表
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

    /// 开始视频通话
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
    func rejectCall() {
        videoCallManager?.rejectCall()
        showIncomingCallAlert = false
        incomingCallFrom = nil
        cleanup()
    }

    /// 结束通话
    func endCall() {
        videoCallManager?.endCall()
        cleanup()
    }

    /// 切换音频开关
    func toggleAudio() {
        isAudioEnabled.toggle()
        videoCallManager?.setAudioEnabled(isAudioEnabled)
        print("[VideoCallViewModel] Audio \(isAudioEnabled ? "enabled" : "disabled")")
    }

    /// 切换视频开关
    func toggleVideo() {
        isVideoEnabled.toggle()
        videoCallManager?.setVideoEnabled(isVideoEnabled)
        print("[VideoCallViewModel] Video \(isVideoEnabled ? "enabled" : "disabled")")
    }

    /// 切换大小屏
    func toggleVideoSize() {
        isLocalVideoLarge.toggle()
        print("[VideoCallViewModel] Switched to \(isLocalVideoLarge ? "local" : "remote") video large")
    }

    /// 切换画中画模式
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
    func restoreFromPiP() {
        pipManager?.stopPictureInPicture()
        isPiPMode = false
        shouldMinimizeToPiP = false
        print("[VideoCallViewModel] Restored from PiP mode")
    }

    // MARK: - Private Methods

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

    nonisolated private func cleanupOnDeinit() {
        Task { @MainActor in
            cleanup()
        }
    }

    deinit {
        cleanupOnDeinit()
    }
}
