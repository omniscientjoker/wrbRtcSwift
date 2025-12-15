//
//  WebRTCSignalingService.swift
//  SimpleEyes
//
//  WebRTC 信令服务 - 负责 SDP 和 ICE 候选交换
//  使用 WebSocket 实现实时信令通道
//

import Foundation
import Starscream
import WebRTC

/// WebRTC 信令服务
///
/// 通过 WebSocket 实现 WebRTC 信令协议，交换 SDP 和 ICE candidates
///
/// ## 功能特性
/// - SDP Offer/Answer 交换
/// - ICE Candidate 传递
/// - 通话请求和应答
/// - 挂断通知
/// - 自动协议适配（兼容扁平和嵌套格式）
///
/// ## 信令流程
/// 1. 连接到信令服务器
/// 2. 发送通话请求（可选）
/// 3. 交换 SDP Offer/Answer
/// 4. 持续交换 ICE Candidates
/// 5. 通话结束后发送挂断通知
///
/// ## 使用示例
/// ```swift
/// let signaling = WebRTCSignalingService(deviceId: "device123")
/// signaling.onOffer = { sdp, from in
///     // 处理接收到的 Offer
/// }
/// signaling.onIceCandidate = { candidate in
///     // 添加到 WebRTC 连接
/// }
/// signaling.connect(serverURL: "ws://192.168.1.100:8080")
/// ```
class WebRTCSignalingService: WebSocketDelegate {

    // MARK: - Properties

    private var socket: Starscream.WebSocket?
    private var isConnected = false
    private let deviceId: String

    // 回调
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    var onOffer: ((RTCSessionDescription, String) -> Void)?
    var onAnswer: ((RTCSessionDescription) -> Void)?
    var onIceCandidate: ((RTCIceCandidate) -> Void)?
    var onIncomingCall: ((String, String) -> Void)? // (fromDeviceId, callType)
    var onCallFailed: ((String) -> Void)?
    var onHangup: (() -> Void)?

    // MARK: - Initialization

    init(deviceId: String) {
        self.deviceId = deviceId
    }

    // MARK: - Connection Management

    func connect(serverURL: String) {
        guard let url = URL(string: "\(serverURL)?deviceId=\(deviceId)&type=peer") else {
            print("[WebRTCSignalingService] Invalid URL: \(serverURL)")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        socket = Starscream.WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()

        print("[WebRTCSignalingService] Connecting to: \(serverURL)")
    }

    func disconnect() {
        socket?.disconnect()
        socket = nil
        isConnected = false
        print("[WebRTCSignalingService] Disconnected")
    }

    // MARK: - Signaling Methods

    /// 发送通话请求
    func sendCallRequest(to targetDeviceId: String, callType: String = "video") {
        let message: [String: Any] = [
            "type": "call",
            "to": targetDeviceId,
            "callType": callType
        ]
        sendMessage(message)
        print("[WebRTCSignalingService] Sent call request to: \(targetDeviceId)")
    }

    /// 发送 Offer（扁平格式，兼容web端）
    func sendOffer(_ sdp: RTCSessionDescription, to targetDeviceId: String) {
        let message: [String: Any] = [
            "type": "offer",
            "to": targetDeviceId,
            "sdp": sdp.sdp  // 直接发送字符串
        ]
        sendMessage(message)
        print("[WebRTCSignalingService] Sent offer to: \(targetDeviceId)")
    }

    /// 发送 Answer（扁平格式，兼容web端）
    func sendAnswer(_ sdp: RTCSessionDescription, to targetDeviceId: String) {
        let message: [String: Any] = [
            "type": "answer",
            "to": targetDeviceId,
            "sdp": sdp.sdp  // 直接发送字符串
        ]
        sendMessage(message)
        print("[WebRTCSignalingService] Sent answer to: \(targetDeviceId)")
    }

    /// 发送 ICE Candidate（扁平格式，兼容web端）
    func sendIceCandidate(_ candidate: RTCIceCandidate, to targetDeviceId: String) {
        let message: [String: Any] = [
            "type": "ice-candidate",
            "to": targetDeviceId,
            "sdpMid": candidate.sdpMid ?? "",
            "sdpMLineIndex": candidate.sdpMLineIndex,
            "candidate": candidate.sdp  // 直接发送字段
        ]
        sendMessage(message)
        print("[WebRTCSignalingService] Sent ICE candidate to: \(targetDeviceId)")
    }

    /// 发送挂断
    func sendHangup(to targetDeviceId: String) {
        let message: [String: Any] = [
            "type": "hangup",
            "to": targetDeviceId
        ]
        sendMessage(message)
        print("[WebRTCSignalingService] Sent hangup to: \(targetDeviceId)")
    }

    // MARK: - Private Methods

    private func sendMessage(_ message: [String: Any]) {
        guard isConnected else {
            print("[WebRTCSignalingService] Cannot send: not connected")
            return
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message)
            socket?.write(data: jsonData)
        } catch {
            print("[WebRTCSignalingService] Failed to serialize message: \(error)")
        }
    }

    // MARK: - WebSocketDelegate

    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected(let headers):
            print("[WebRTCSignalingService] Connected: \(headers)")
            isConnected = true
            onConnected?()

        case .disconnected(let reason, let code):
            print("[WebRTCSignalingService] Disconnected: \(reason) with code: \(code)")
            isConnected = false
            onDisconnected?()

        case .text(let string):
            handleTextMessage(string)

        case .binary(let data):
            print("[WebRTCSignalingService] Received binary data: \(data.count) bytes")

        case .error(let error):
            print("[WebRTCSignalingService] Error: \(error?.localizedDescription ?? "unknown")")
            isConnected = false
            onDisconnected?()

        case .cancelled:
            print("[WebRTCSignalingService] Cancelled")
            isConnected = false
            onDisconnected?()

        case .peerClosed:
            print("[WebRTCSignalingService] Peer closed")
            isConnected = false
            onDisconnected?()

        case .ping(_), .pong(_), .reconnectSuggested(_), .viabilityChanged(_):
            break
        }
    }

    private func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            print("[WebRTCSignalingService] Invalid message format")
            return
        }

        print("[WebRTCSignalingService] Received message: \(type)")

        switch type {
        case "offer":
            handleOffer(json)

        case "answer":
            handleAnswer(json)

        case "ice-candidate":
            handleIceCandidate(json)

        case "incoming-call":
            handleIncomingCall(json)

        case "call-failed":
            if let reason = json["reason"] as? String {
                onCallFailed?(reason)
            }

        case "hangup":
            onHangup?()

        default:
            print("[WebRTCSignalingService] Unknown message type: \(type)")
        }
    }

    private func handleOffer(_ json: [String: Any]) {
        guard let from = json["from"] as? String else {
            print("[WebRTCSignalingService] Missing 'from' field in offer")
            return
        }

        // 兼容两种格式
        let sdpString: String?
        if let sdpDict = json["sdp"] as? [String: Any] {
            // 嵌套格式: {"sdp": {"sdp": "..."}}
            sdpString = sdpDict["sdp"] as? String
        } else {
            // 扁平格式: {"sdp": "..."}
            sdpString = json["sdp"] as? String
        }

        guard let sdp = sdpString else {
            print("[WebRTCSignalingService] Invalid offer format: missing SDP")
            return
        }

        let sessionDescription = RTCSessionDescription(type: .offer, sdp: sdp)
        print("[WebRTCSignalingService] Parsed offer from: \(from)")
        onOffer?(sessionDescription, from)
    }

    private func handleAnswer(_ json: [String: Any]) {
        print("[WebRTCSignalingService] Received answer message: \(json.keys)")

        // 兼容两种格式
        let sdpString: String?
        if let sdpDict = json["sdp"] as? [String: Any] {
            // 嵌套格式: {"sdp": {"sdp": "..."}}
            sdpString = sdpDict["sdp"] as? String
            print("[WebRTCSignalingService] Using nested SDP format")
        } else {
            // 扁平格式: {"sdp": "..."}
            sdpString = json["sdp"] as? String
            print("[WebRTCSignalingService] Using flat SDP format")
        }

        guard let sdp = sdpString else {
            print("[WebRTCSignalingService] ❌ Invalid answer format: missing SDP. Keys: \(json.keys)")
            return
        }

        print("[WebRTCSignalingService] ✅ Answer SDP length: \(sdp.count) characters")
        let sessionDescription = RTCSessionDescription(type: .answer, sdp: sdp)
        onAnswer?(sessionDescription)
    }

    private func handleIceCandidate(_ json: [String: Any]) {
        // 兼容两种格式
        let sdpMid: String?
        let sdpMLineIndex: Int?
        let candidateString: String?

        if let candidateDict = json["candidate"] as? [String: Any] {
            // 嵌套格式: {"candidate": {"sdpMid": ..., "sdpMLineIndex": ..., "candidate": ...}}
            sdpMid = candidateDict["sdpMid"] as? String
            sdpMLineIndex = candidateDict["sdpMLineIndex"] as? Int
            candidateString = candidateDict["candidate"] as? String
        } else {
            // 扁平格式: {"sdpMid": ..., "sdpMLineIndex": ..., "candidate": ...}
            sdpMid = json["sdpMid"] as? String
            sdpMLineIndex = json["sdpMLineIndex"] as? Int
            candidateString = json["candidate"] as? String
        }

        guard let mid = sdpMid,
              let lineIndex = sdpMLineIndex,
              let candidate = candidateString else {
            print("[WebRTCSignalingService] Invalid ICE candidate format: missing fields")
            return
        }

        let iceCandidate = RTCIceCandidate(
            sdp: candidate,
            sdpMLineIndex: Int32(lineIndex),
            sdpMid: mid
        )
        print("[WebRTCSignalingService] Parsed ICE candidate")
        onIceCandidate?(iceCandidate)
    }

    private func handleIncomingCall(_ json: [String: Any]) {
        guard let from = json["from"] as? String,
              let callType = json["callType"] as? String else {
            print("[WebRTCSignalingService] Invalid incoming call format")
            return
        }

        onIncomingCall?(from, callType)
    }
}
