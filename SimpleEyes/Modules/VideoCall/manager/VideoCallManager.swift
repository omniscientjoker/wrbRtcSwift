import Foundation
import WebRTC
import AVFoundation

/// 视频通话状态
enum VideoCallState: Equatable {
    case idle
    case connecting
    case ringing
    case connected
    case disconnected
    case error(String)

    var displayText: String {
        switch self {
        case .idle: return "空闲"
        case .connecting: return "连接中..."
        case .ringing: return "呼叫中..."
        case .connected: return "通话中"
        case .disconnected: return "已断开"
        case .error(let message): return "错误: \(message)"
        }
    }
}

/// 视频通话管理器
/// 整合 WebRTC 客户端和信令服务
class VideoCallManager {

    // MARK: - Properties

    private let localDeviceId: String
    private var remoteDeviceId: String?

    private var webRTCClient: WebRTCClient
    private var signalingService: WebRTCSignalingService

    private var isInitiator = false // 是否是发起方
    private var pendingOffer: (sdp: RTCSessionDescription, from: String)? // 缓存的 offer

    // 回调
    var onStateChanged: ((VideoCallState) -> Void)?
    var onLocalVideoTrack: ((RTCVideoTrack) -> Void)?
    var onRemoteVideoTrack: ((RTCVideoTrack) -> Void)?
    var onIncomingCall: ((String) -> Void)? // (fromDeviceId)
    var onSignalingConnected: (() -> Void)?
    var onSignalingDisconnected: (() -> Void)?

    // MARK: - Initialization

    init(deviceId: String) {
        self.localDeviceId = deviceId

        webRTCClient = WebRTCClient()
        signalingService = WebRTCSignalingService(deviceId: deviceId)

        setupCallbacks()
    }

    // MARK: - Setup

    private func setupCallbacks() {
        // WebRTC 客户端回调
        webRTCClient.onLocalVideoTrack = { [weak self] track in
            self?.onLocalVideoTrack?(track)
        }

        webRTCClient.onRemoteVideoTrack = { [weak self] track in
            self?.onRemoteVideoTrack?(track)
        }

        webRTCClient.onIceCandidate = { [weak self] candidate in
            guard let self = self, let remoteDeviceId = self.remoteDeviceId else { return }
            self.signalingService.sendIceCandidate(candidate, to: remoteDeviceId)
        }

        webRTCClient.onConnectionStateChange = { [weak self] state in
            switch state {
            case .connected:
                self?.onStateChanged?(.connected)
            case .disconnected, .closed, .failed:
                self?.onStateChanged?(.disconnected)
            default:
                break
            }
        }

        // 信令服务回调
        signalingService.onConnected = { [weak self] in
            print("[VideoCallManager] Signaling connected")
            self?.onSignalingConnected?()
        }

        signalingService.onDisconnected = { [weak self] in
            print("[VideoCallManager] Signaling disconnected")
            self?.onSignalingDisconnected?()
            // 只有在通话中才更新通话状态
            if self?.remoteDeviceId != nil {
                self?.onStateChanged?(.disconnected)
            }
        }

        signalingService.onOffer = { [weak self] sdp, from in
            self?.handleReceivedOffer(sdp, from: from)
        }

        signalingService.onAnswer = { [weak self] sdp in
            self?.handleReceivedAnswer(sdp)
        }

        signalingService.onIceCandidate = { [weak self] candidate in
            self?.webRTCClient.addIceCandidate(candidate)
        }

        signalingService.onIncomingCall = { [weak self] fromDeviceId, callType in
            print("[VideoCallManager] Incoming call from: \(fromDeviceId)")
            self?.remoteDeviceId = fromDeviceId
            self?.onIncomingCall?(fromDeviceId)
            self?.onStateChanged?(.ringing)
        }

        signalingService.onCallFailed = { [weak self] reason in
            self?.onStateChanged?(.error("通话失败: \(reason)"))
        }

        signalingService.onHangup = { [weak self] in
            self?.endCall()
        }
    }

    // MARK: - Public Methods

    /// 连接到信令服务器（用于接收来电）
    func connectSignaling(serverURL: String) {
        signalingService.connect(serverURL: serverURL)
    }

    /// 断开信令服务器连接
    func disconnectSignaling() {
        signalingService.disconnect()
    }

    /// 开始视频通话（发起方）
    func startCall(to targetDeviceId: String) {
        guard remoteDeviceId == nil else {
            print("[VideoCallManager] Already in a call")
            return
        }

        remoteDeviceId = targetDeviceId
        isInitiator = true

        onStateChanged?(.connecting)

        // 设置本地媒体
        webRTCClient.setupLocalMedia()

        // 创建 PeerConnection
        webRTCClient.createPeerConnection()

        // 发送通话请求
        signalingService.sendCallRequest(to: targetDeviceId)

        // 创建并发送 Offer
        createAndSendOffer()
    }

    /// 接受来电
    func acceptCall() {
        guard remoteDeviceId != nil else {
            print("[VideoCallManager] No incoming call to accept")
            return
        }

        isInitiator = false
        onStateChanged?(.connecting)

        // 设置本地媒体
        webRTCClient.setupLocalMedia()

        // 创建 PeerConnection
        webRTCClient.createPeerConnection()

        // 如果已经收到 offer，立即处理
        if let pending = pendingOffer {
            print("[VideoCallManager] Processing pending offer...")
            handleReceivedOffer(pending.sdp, from: pending.from)
            pendingOffer = nil
        } else {
            print("[VideoCallManager] Call accepted, waiting for offer...")
        }
    }

    /// 拒绝来电
    func rejectCall() {
        guard let remoteDeviceId = remoteDeviceId else { return }
        signalingService.sendHangup(to: remoteDeviceId)
        pendingOffer = nil
        cleanup()
    }

    /// 结束通话
    func endCall() {
        // 先通知状态变化
        onStateChanged?(.disconnected)

        // 发送挂断信令
        if let remoteDeviceId = remoteDeviceId {
            signalingService.sendHangup(to: remoteDeviceId)
        }

        // 清理资源
        cleanup()
    }

    /// 设置音频开关
    func setAudioEnabled(_ enabled: Bool) {
        webRTCClient.setAudioEnabled(enabled)
    }

    /// 设置视频开关
    func setVideoEnabled(_ enabled: Bool) {
        webRTCClient.setVideoEnabled(enabled)
    }

    // MARK: - Private Methods

    private func createAndSendOffer() {
        guard let remoteDeviceId = remoteDeviceId else { return }

        print("[VideoCallManager] 📤 Creating offer for: \(remoteDeviceId)")
        webRTCClient.createOffer { [weak self] sdp in
            guard let sdp = sdp else {
                print("[VideoCallManager] ❌ Failed to create offer")
                self?.onStateChanged?(.error("创建 Offer 失败"))
                return
            }

            print("[VideoCallManager] ✅ Offer created, SDP length: \(sdp.sdp.count) characters")
            print("[VideoCallManager] 📤 Sending offer to: \(remoteDeviceId)")
            self?.signalingService.sendOffer(sdp, to: remoteDeviceId)
        }
    }

    private func handleReceivedOffer(_ sdp: RTCSessionDescription, from: String) {
        // 检查 PeerConnection 是否已创建
        guard webRTCClient.isPeerConnectionReady else {
            print("[VideoCallManager] PeerConnection not ready, caching offer...")
            pendingOffer = (sdp, from)
            return
        }

        print("[VideoCallManager] Processing offer from: \(from)")
        webRTCClient.setRemoteDescription(sdp: sdp) { [weak self] error in
            if let error = error {
                self?.onStateChanged?(.error("设置远程描述失败: \(error.localizedDescription)"))
                return
            }

            // 创建并发送 Answer
            self?.webRTCClient.createAnswer { answer in
                guard let answer = answer else {
                    self?.onStateChanged?(.error("创建 Answer 失败"))
                    return
                }

                self?.signalingService.sendAnswer(answer, to: from)
            }
        }
    }

    private func handleReceivedAnswer(_ sdp: RTCSessionDescription) {
        print("[VideoCallManager] 📥 Received answer, setting remote description...")
        print("[VideoCallManager] Answer SDP type: \(sdp.type.rawValue)")

        webRTCClient.setRemoteDescription(sdp: sdp) { [weak self] error in
            if let error = error {
                print("[VideoCallManager] ❌ Failed to set remote description: \(error.localizedDescription)")
                self?.onStateChanged?(.error("设置远程描述失败: \(error.localizedDescription)"))
            } else {
                print("[VideoCallManager] ✅ Remote description set successfully, connection establishing...")
            }
        }
    }

    private func cleanup() {
        webRTCClient.close()
        // 不断开信令连接，保持在线状态以接收新的来电
        // signalingService.disconnect()
        remoteDeviceId = nil
        isInitiator = false
        pendingOffer = nil
    }

    deinit {
        cleanup()
    }
}
