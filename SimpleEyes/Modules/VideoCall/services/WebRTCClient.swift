//
//  WebRTCClient.swift
//  SimpleEyes
//
//  WebRTC 客户端服务 - 核心音视频通话引擎
//  负责管理 WebRTC 连接、媒体流处理和 ICE 连接建立
//

import Foundation
import WebRTC
import AVFoundation

/// WebRTC 客户端
///
/// 封装了 Google WebRTC 框架的核心功能，提供音视频通话能力
///
/// ## 功能特性
/// - P2P 音视频通话
/// - 自适应码率和分辨率
/// - ICE 候选收集和管理
/// - STUN/TURN 服务器支持
/// - 本地媒体采集（摄像头+麦克风）
/// - 远程媒体接收和渲染
///
/// ## 主要流程
/// 1. 初始化：异步创建 PeerConnectionFactory
/// 2. 设置本地媒体：setupLocalMedia()
/// 3. 创建对等连接：createPeerConnection()
/// 4. 创建/接受 Offer/Answer：createOffer() / createAnswer()
/// 5. 交换 ICE 候选：通过信令服务器交换
/// 6. 建立连接：自动完成 ICE 协商
///
/// ## 使用示例
/// ```swift
/// let webrtc = WebRTCClient()
/// webrtc.onLocalVideoTrack = { track in
///     // 显示本地视频
/// }
/// webrtc.onRemoteVideoTrack = { track in
///     // 显示远程视频
/// }
/// webrtc.setupLocalMedia()
/// webrtc.createPeerConnection()
/// webrtc.createOffer { sdp in
///     // 发送 offer 给对方
/// }
/// ```
class WebRTCClient: NSObject {

    // MARK: - Properties

    /// PeerConnectionFactory 实例（WebRTC 核心工厂）
    private var peerConnectionFactory: RTCPeerConnectionFactory!

    /// PeerConnection 实例（对等连接）
    private var peerConnection: RTCPeerConnection?

    /// 本地音频轨道
    private var localAudioTrack: RTCAudioTrack?

    /// 本地视频轨道
    private var localVideoTrack: RTCVideoTrack?

    /// 摄像头视频采集器
    private var videoCapturer: RTCCameraVideoCapturer?

    // MARK: - Initialization State

    /// Factory 是否已初始化
    private var isFactoryInitialized = false

    /// 初始化队列（异步初始化，避免阻塞主线程）
    private let initQueue = DispatchQueue(label: "com.simpleEyes.webrtc.init", qos: .userInitiated)

    /// 初始化完成回调
    private var initializationCompletion: (() -> Void)?

    // MARK: - Callbacks

    /// 本地视频轨道创建回调
    var onLocalVideoTrack: ((RTCVideoTrack) -> Void)?

    /// 远程视频轨道接收回调
    var onRemoteVideoTrack: ((RTCVideoTrack) -> Void)?

    /// ICE 候选生成回调
    var onIceCandidate: ((RTCIceCandidate) -> Void)?

    /// ICE 连接状态变化回调
    var onConnectionStateChange: ((RTCIceConnectionState) -> Void)?

    // MARK: - Initialization

    override init() {
        super.init()

        // 异步初始化 PeerConnectionFactory，避免阻塞主线程
        initQueue.async { [weak self] in
            guard let self = self else { return }

            // 初始化 SSL（只需要调用一次）
            RTCInitializeSSL()

            // 创建编解码器工厂
            let encoderFactory = RTCDefaultVideoEncoderFactory()
            let decoderFactory = RTCDefaultVideoDecoderFactory()

            // 创建 PeerConnectionFactory
            let factory = RTCPeerConnectionFactory(
                encoderFactory: encoderFactory,
                decoderFactory: decoderFactory
            )

            // 在主线程更新状态
            DispatchQueue.main.async {
                self.peerConnectionFactory = factory
                self.isFactoryInitialized = true
                print("[WebRTCClient] PeerConnectionFactory initialized asynchronously")

                // 调用初始化完成回调
                self.initializationCompletion?()
                self.initializationCompletion = nil
            }
        }
    }

    // MARK: - Public Methods

    /// 确保工厂已初始化（带回调）
    ///
    /// 内部方法：等待 PeerConnectionFactory 初始化完成后执行回调
    ///
    /// - Parameter completion: 初始化完成后的回调
    private func ensureFactoryInitialized(completion: @escaping () -> Void) {
        if isFactoryInitialized {
            completion()
        } else {
            initializationCompletion = completion
        }
    }

    /// 检查 PeerConnection 是否已创建
    var isPeerConnectionReady: Bool {
        return peerConnection != nil
    }

    /// 设置本地媒体（摄像头+麦克风）
    ///
    /// 创建本地音频和视频轨道，开始摄像头采集
    /// 必须在创建 PeerConnection 之前调用
    ///
    /// ## 功能说明
    /// 1. 创建音频轨道（麦克风输入）
    /// 2. 创建视频轨道（摄像头输入）
    /// 3. 配置视频源为自适应分辨率（640x480@24fps 起始）
    /// 4. 开始前置摄像头采集
    /// 5. 触发 onLocalVideoTrack 回调
    func setupLocalMedia() {
        ensureFactoryInitialized { [weak self] in
            guard let self = self else { return }

            // 创建音频轨道
            let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
            let audioSource = self.peerConnectionFactory.audioSource(with: audioConstraints)
            self.localAudioTrack = self.peerConnectionFactory.audioTrack(with: audioSource, trackId: "audio0")

            // 创建视频轨道
            let videoSource = self.peerConnectionFactory.videoSource()
            // 自适应分辨率：起始使用较低分辨率，根据网络状况动态调整
            videoSource.adaptOutputFormat(toWidth: 640, height: 480, fps: 24)
            self.localVideoTrack = self.peerConnectionFactory.videoTrack(with: videoSource, trackId: "video0")

            // 创建摄像头采集器
            let videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
            self.videoCapturer = videoCapturer

            // 开始摄像头采集
            self.startCaptureLocalVideo(videoCapturer: videoCapturer)

            // 通知本地视频轨道
            if let localVideoTrack = self.localVideoTrack {
                self.onLocalVideoTrack?(localVideoTrack)
            }

            print("[WebRTCClient] Local media setup completed")
        }
    }

    /// 创建 PeerConnection
    ///
    /// 创建 WebRTC 对等连接，配置 ICE 服务器和媒体约束
    ///
    /// ## ICE 服务器配置
    /// - 多个 Google STUN 服务器（提高连通率）
    /// - 备用公共 STUN 服务器
    /// - TURN 中继服务器（解决 NAT 穿透问题）
    ///
    /// ## 编码优化
    /// - 最大码率：800kbps（适合移动网络）
    /// - 最小码率：100kbps（保证最低质量）
    /// - 网络优先级：高
    ///
    /// - Note: 必须先调用 setupLocalMedia()
    func createPeerConnection() {
        ensureFactoryInitialized { [weak self] in
            guard let self = self else { return }

            let config = RTCConfiguration()

            // 配置多个 STUN/TURN 服务器以提高连通率
            config.iceServers = [
                // Google 公共 STUN 服务器
                RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
                RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"]),
                RTCIceServer(urlStrings: ["stun:stun2.l.google.com:19302"]),
                RTCIceServer(urlStrings: ["stun:stun3.l.google.com:19302"]),

                // 备用公共 STUN 服务器（提高 SRFLX 候选生成成功率）
                RTCIceServer(urlStrings: ["stun:stun.stunprotocol.org:3478"]),
                RTCIceServer(urlStrings: ["stun:stun.services.mozilla.com:3478"]),

                // TURN 服务器（解决多网络接口问题）
                RTCIceServer(
                    urlStrings: ["turn:192.168.1.50:3478"],  // 替换为实际IP
                    username: "test",
                    credential: "test123"
                ),

                // 备用 TURN 服务器（可选）
                // RTCIceServer(
                //     urlStrings: [
                //         "turn:your-turn-server.com:3478?transport=udp",
                //         "turn:your-turn-server.com:3478?transport=tcp"
                //     ],
                //     username: "username",
                //     credential: "password"
                // )
            ]

            print("[WebRTCClient] Configured \(config.iceServers.count) ICE servers")

            // ICE 传输策略：all = 尝试所有候选（包括中继）
            config.iceTransportPolicy = .all

            // 启用持续收集 ICE 候选
            config.continualGatheringPolicy = .gatherContinually

            config.sdpSemantics = .unifiedPlan

            let constraints = RTCMediaConstraints(
                mandatoryConstraints: [
                    "OfferToReceiveAudio": "true",
                    "OfferToReceiveVideo": "true"
                ],
                optionalConstraints: nil
            )

            self.peerConnection = self.peerConnectionFactory.peerConnection(
                with: config,
                constraints: constraints,
                delegate: self
            )

            // 添加本地媒体轨道
            if let localAudioTrack = self.localAudioTrack {
                self.peerConnection?.add(localAudioTrack, streamIds: ["stream0"])
            }
            if let localVideoTrack = self.localVideoTrack {
                let videoSender = self.peerConnection?.add(localVideoTrack, streamIds: ["stream0"])

                // 配置视频编码参数以优化跨网性能
                if let sender = videoSender {
                    let parameters = sender.parameters

                    // 设置编码参数
                    for encoding in parameters.encodings {
                        // 设置最大码率 (800kbps，适合移动网络)
                        encoding.maxBitrateBps = 800_000 as NSNumber
                        // 设置最小码率 (100kbps，保证最低质量)
                        encoding.minBitrateBps = 100_000 as NSNumber
                        // 网络适应性强度
                        encoding.networkPriority = .high
                    }

                    sender.parameters = parameters
                    print("[WebRTCClient] Video encoding parameters configured")
                }
            }

            print("[WebRTCClient] PeerConnection created")
        }
    }

    /// 创建 Offer（发起方调用）
    ///
    /// 创建 SDP Offer 并设置为本地描述
    ///
    /// - Parameter completion: 完成回调
    ///   - Success: 返回 SDP Offer 对象
    ///   - Failure: 返回 nil
    ///
    /// - Note: 成功后需要通过信令服务器发送给对方
    func createOffer(completion: @escaping (RTCSessionDescription?) -> Void) {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": "true"
            ],
            optionalConstraints: nil
        )

        peerConnection?.offer(for: constraints) { [weak self] sdp, error in
            guard let sdp = sdp, error == nil else {
                print("[WebRTCClient] Failed to create offer: \(error?.localizedDescription ?? "unknown")")
                completion(nil)
                return
            }

            self?.peerConnection?.setLocalDescription(sdp) { error in
                if let error = error {
                    print("[WebRTCClient] Failed to set local description: \(error.localizedDescription)")
                    completion(nil)
                } else {
                    print("[WebRTCClient] Offer created and set as local description")
                    completion(sdp)
                }
            }
        }
    }

    /// 创建 Answer（接收方调用）
    ///
    /// 创建 SDP Answer 并设置为本地描述
    ///
    /// - Parameter completion: 完成回调
    ///   - Success: 返回 SDP Answer 对象
    ///   - Failure: 返回 nil
    ///
    /// - Note: 必须先调用 setRemoteDescription() 设置对方的 Offer
    func createAnswer(completion: @escaping (RTCSessionDescription?) -> Void) {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": "true"
            ],
            optionalConstraints: nil
        )

        peerConnection?.answer(for: constraints) { [weak self] sdp, error in
            guard let sdp = sdp, error == nil else {
                print("[WebRTCClient] Failed to create answer: \(error?.localizedDescription ?? "unknown")")
                completion(nil)
                return
            }

            self?.peerConnection?.setLocalDescription(sdp) { error in
                if let error = error {
                    print("[WebRTCClient] Failed to set local description: \(error.localizedDescription)")
                    completion(nil)
                } else {
                    print("[WebRTCClient] Answer created and set as local description")
                    completion(sdp)
                }
            }
        }
    }

    /// 设置远程 SDP
    ///
    /// 设置对方的 SDP 描述（Offer 或 Answer）
    ///
    /// - Parameters:
    ///   - sdp: 远程 SDP 描述对象
    ///   - completion: 完成回调，返回可能的错误
    func setRemoteDescription(sdp: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        peerConnection?.setRemoteDescription(sdp) { error in
            if let error = error {
                print("[WebRTCClient] Failed to set remote description: \(error.localizedDescription)")
            } else {
                print("[WebRTCClient] Remote description set successfully")
            }
            completion(error)
        }
    }

    /// 添加远程 ICE Candidate
    ///
    /// 添加对方发送的 ICE 候选，用于建立 P2P 连接
    ///
    /// - Parameter candidate: ICE 候选对象
    ///
    /// ## Candidate 类型
    /// - HOST: 本地地址（局域网内直连）
    /// - SRFLX: NAT 穿透后的地址（通过 STUN）
    /// - RELAY: 中继地址（通过 TURN 服务器）
    func addIceCandidate(_ candidate: RTCIceCandidate) {
        print("[WebRTCClient] 📥 Adding remote ICE candidate: \(candidate.sdpMid ?? "nil"):\(candidate.sdpMLineIndex)")

        // 分析 candidate 类型
        let candidateStr = candidate.sdp
        let candidateType: String
        if candidateStr.contains("typ host") {
            candidateType = "HOST (本地)"
        } else if candidateStr.contains("typ srflx") {
            candidateType = "SRFLX (NAT穿透)"
        } else if candidateStr.contains("typ relay") {
            candidateType = "RELAY (TURN中继)"
        } else {
            candidateType = "UNKNOWN"
        }

        print("[WebRTCClient]    Remote candidate type: \(candidateType)")
        print("[WebRTCClient]    Remote candidate: \(candidateStr.prefix(80))...")

        guard let pc = peerConnection else {
            print("[WebRTCClient] ⚠️ PeerConnection is nil, cannot add ICE candidate")
            return
        }

        pc.add(candidate) { error in
            if let error = error {
                print("[WebRTCClient] ❌ Failed to add ICE candidate: \(error.localizedDescription)")
            } else {
                print("[WebRTCClient] ✅ Remote ICE candidate added successfully")
            }
        }
    }

    /// 关闭连接并释放资源
    ///
    /// 停止媒体采集，关闭对等连接，释放所有资源
    func close() {
        videoCapturer?.stopCapture()
        peerConnection?.close()
        peerConnection = nil
        localAudioTrack = nil
        localVideoTrack = nil
        videoCapturer = nil

        print("[WebRTCClient] Connection closed")
    }

    /// 设置音频开关（静音/取消静音）
    ///
    /// - Parameter enabled: true 启用音频，false 静音
    func setAudioEnabled(_ enabled: Bool) {
        localAudioTrack?.isEnabled = enabled
        print("[WebRTCClient] Audio track \(enabled ? "enabled" : "disabled")")
    }

    /// 设置视频开关（显示/隐藏）
    ///
    /// - Parameter enabled: true 启用视频，false 关闭视频
    func setVideoEnabled(_ enabled: Bool) {
        localVideoTrack?.isEnabled = enabled
        print("[WebRTCClient] Video track \(enabled ? "enabled" : "disabled")")
    }

    // MARK: - Private Methods

    /// 开始本地视频采集
    ///
    /// 配置并启动摄像头采集，默认使用前置摄像头，640x480 分辨率
    ///
    /// - Parameter videoCapturer: 视频采集器实例
    private func startCaptureLocalVideo(videoCapturer: RTCCameraVideoCapturer) {
        // 获取前置摄像头
        guard let frontCamera = RTCCameraVideoCapturer.captureDevices()
            .first(where: { $0.position == .front }) else {
            print("[WebRTCClient] Front camera not found")
            return
        }

        // 获取支持的格式
        let supportedFormats = RTCCameraVideoCapturer.supportedFormats(for: frontCamera)
        guard let format = supportedFormats.first(where: { format in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return dimensions.width == 640 && dimensions.height == 480
        }) ?? supportedFormats.first else {
            print("[WebRTCClient] No suitable video format found")
            return
        }

        // 获取帧率
        let fps = format.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 30

        // 开始采集
        videoCapturer.startCapture(
            with: frontCamera,
            format: format,
            fps: Int(fps)
        )

        print("[WebRTCClient] Started capturing video from front camera")
    }

    deinit {
        close()
        RTCCleanupSSL()
    }
}

// MARK: - RTCPeerConnectionDelegate

extension WebRTCClient: RTCPeerConnectionDelegate {

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("[WebRTCClient] Signaling state changed: \(stateChanged.rawValue)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("[WebRTCClient] Did add stream: \(stream.streamId)")

        // 处理远程视频轨道（Plan B 模式）
        if let videoTrack = stream.videoTracks.first {
            print("[WebRTCClient] Received remote video track (Plan B)")
            onRemoteVideoTrack?(videoTrack)
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("[WebRTCClient] Did remove stream: \(stream.streamId)")
    }

    // Unified Plan 模式的远程轨道接收
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        print("[WebRTCClient] Did add RTP receiver (Unified Plan)")

        // 处理视频轨道
        if let videoTrack = rtpReceiver.track as? RTCVideoTrack {
            print("[WebRTCClient] Received remote video track (Unified Plan)")
            onRemoteVideoTrack?(videoTrack)
        }

        // 处理音频轨道
        if rtpReceiver.track is RTCAudioTrack {
            print("[WebRTCClient] Received remote audio track (Unified Plan)")
        }
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("[WebRTCClient] Should negotiate")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        let stateText: String
        switch newState {
        case .new: stateText = "NEW"
        case .checking: stateText = "CHECKING"
        case .connected: stateText = "CONNECTED ✅"
        case .completed: stateText = "COMPLETED ✅"
        case .failed: stateText = "FAILED ❌"
        case .disconnected: stateText = "DISCONNECTED ⚠️"
        case .closed: stateText = "CLOSED"
        case .count: stateText = "COUNT"
        @unknown default: stateText = "UNKNOWN"
        }
        print("[WebRTCClient] 🔌 ICE connection state changed: \(stateText) (rawValue: \(newState.rawValue))")

        // 失败时打印更多调试信息
        if newState == .failed {
            print("[WebRTCClient] ❌ ICE 连接失败调试信息：")
            print("[WebRTCClient]    Signaling State: \(peerConnection.signalingState.rawValue)")
            print("[WebRTCClient]    Connection State: \(peerConnection.connectionState.rawValue)")
            print("[WebRTCClient]    ICE Gathering State: \(peerConnection.iceGatheringState.rawValue)")

            // 打印本地描述
            if let localDesc = peerConnection.localDescription {
                print("[WebRTCClient]    Local SDP type: \(localDesc.type.rawValue)")
                let sdpLines = localDesc.sdp.components(separatedBy: "\n")
                let candidateLines = sdpLines.filter { $0.contains("candidate:") }
                print("[WebRTCClient]    Local candidates count: \(candidateLines.count)")
            }

            // 打印远程描述
            if let remoteDesc = peerConnection.remoteDescription {
                print("[WebRTCClient]    Remote SDP type: \(remoteDesc.type.rawValue)")
                let sdpLines = remoteDesc.sdp.components(separatedBy: "\n")
                let candidateLines = sdpLines.filter { $0.contains("candidate:") }
                print("[WebRTCClient]    Remote candidates in SDP: \(candidateLines.count)")
            }
        }

        onConnectionStateChange?(newState)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        let stateText: String
        switch newState {
        case .new: stateText = "NEW"
        case .gathering: stateText = "GATHERING 🔍"
        case .complete: stateText = "COMPLETE ✅"
        @unknown default: stateText = "UNKNOWN"
        }
        print("[WebRTCClient] 🧊 ICE gathering state changed: \(stateText) (rawValue: \(newState.rawValue))")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("[WebRTCClient] 📤 Generated ICE candidate: \(candidate.sdpMid ?? "nil"):\(candidate.sdpMLineIndex)")

        // 分析 candidate 类型
        let candidateStr = candidate.sdp
        let candidateType: String
        if candidateStr.contains("typ host") {
            candidateType = "HOST (本地)"
        } else if candidateStr.contains("typ srflx") {
            candidateType = "SRFLX (NAT穿透)"
        } else if candidateStr.contains("typ relay") {
            candidateType = "RELAY (TURN中继)"
        } else if candidateStr.contains("typ prflx") {
            candidateType = "PRFLX (对等反射)"
        } else {
            candidateType = "UNKNOWN"
        }

        print("[WebRTCClient]    Type: \(candidateType)")
        print("[WebRTCClient]    Candidate: \(candidateStr.prefix(80))...")
        onIceCandidate?(candidate)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("[WebRTCClient] Removed ICE candidates")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("[WebRTCClient] Data channel opened")
    }
}
