import Foundation
import WebRTC
import AVFoundation

/// WebRTC 客户端
/// 负责管理 WebRTC 连接、本地/远程媒体流
class WebRTCClient: NSObject {

    // MARK: - Properties

    private let peerConnectionFactory: RTCPeerConnectionFactory
    private var peerConnection: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack?
    private var localVideoTrack: RTCVideoTrack?
    private var videoCapturer: RTCCameraVideoCapturer?

    // 回调
    var onLocalVideoTrack: ((RTCVideoTrack) -> Void)?
    var onRemoteVideoTrack: ((RTCVideoTrack) -> Void)?
    var onIceCandidate: ((RTCIceCandidate) -> Void)?
    var onConnectionStateChange: ((RTCIceConnectionState) -> Void)?

    // MARK: - Initialization

    override init() {
        // 初始化 PeerConnectionFactory
        RTCInitializeSSL()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        peerConnectionFactory = RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )

        super.init()
    }

    // MARK: - Public Methods

    /// 检查 PeerConnection 是否已创建
    var isPeerConnectionReady: Bool {
        return peerConnection != nil
    }

    /// 设置本地媒体（摄像头+麦克风）
    func setupLocalMedia() {
        // 创建音频轨道
        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = peerConnectionFactory.audioSource(with: audioConstraints)
        localAudioTrack = peerConnectionFactory.audioTrack(with: audioSource, trackId: "audio0")

        // 创建视频轨道
        let videoSource = peerConnectionFactory.videoSource()
        // 自适应分辨率：起始使用较低分辨率，根据网络状况动态调整
        videoSource.adaptOutputFormat(toWidth: 640, height: 480, fps: 24)
        localVideoTrack = peerConnectionFactory.videoTrack(with: videoSource, trackId: "video0")

        // 创建摄像头采集器
        let videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        self.videoCapturer = videoCapturer

        // 开始摄像头采集
        startCaptureLocalVideo(videoCapturer: videoCapturer)

        // 通知本地视频轨道
        if let localVideoTrack = localVideoTrack {
            onLocalVideoTrack?(localVideoTrack)
        }

        print("[WebRTCClient] Local media setup completed")
    }

    /// 创建 PeerConnection
    func createPeerConnection() {
        let config = RTCConfiguration()

        // 配置多个 STUN/TURN 服务器以提高连通率
        config.iceServers = [
            // Google 公共 STUN 服务器
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
            RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"]),

            // TODO: 添加您自己的 TURN 服务器以确保跨网穿透
            // RTCIceServer(
            //     urlStrings: ["turn:your-turn-server.com:3478"],
            //     username: "username",
            //     credential: "password"
            // ),

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

        peerConnection = peerConnectionFactory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        )

        // 添加本地媒体轨道
        if let localAudioTrack = localAudioTrack {
            peerConnection?.add(localAudioTrack, streamIds: ["stream0"])
        }
        if let localVideoTrack = localVideoTrack {
            let videoSender = peerConnection?.add(localVideoTrack, streamIds: ["stream0"])

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

    /// 创建 Offer
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

    /// 创建 Answer
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

    /// 添加 ICE Candidate
    func addIceCandidate(_ candidate: RTCIceCandidate) {
        peerConnection?.add(candidate) { error in
            if let error = error {
                print("[WebRTCClient] Failed to add ICE candidate: \(error.localizedDescription)")
            } else {
                print("[WebRTCClient] ICE candidate added successfully")
            }
        }
    }

    /// 关闭连接
    func close() {
        videoCapturer?.stopCapture()
        peerConnection?.close()
        peerConnection = nil
        localAudioTrack = nil
        localVideoTrack = nil
        videoCapturer = nil

        print("[WebRTCClient] Connection closed")
    }

    // MARK: - Private Methods

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
        if let audioTrack = rtpReceiver.track as? RTCAudioTrack {
            print("[WebRTCClient] Received remote audio track (Unified Plan)")
        }
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("[WebRTCClient] Should negotiate")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("[WebRTCClient] ICE connection state changed: \(newState.rawValue)")
        onConnectionStateChange?(newState)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("[WebRTCClient] ICE gathering state changed: \(newState.rawValue)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("[WebRTCClient] Generated ICE candidate")
        onIceCandidate?(candidate)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("[WebRTCClient] Removed ICE candidates")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("[WebRTCClient] Data channel opened")
    }
}
