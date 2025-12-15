//
//  IntercomWebSocketService.swift
//  SimpleEyes
//
//  WebSocket 对讲服务 - 基于 Starscream 实现
//  负责通过 WebSocket 连接实现实时音频数据传输
//

import Foundation
import Starscream

/// WebSocket 对讲服务
///
/// 使用 Starscream 框架实现的 WebSocket 客户端，用于实时音频对讲
///
/// ## 功能特性
/// - 实时音频数据传输
/// - 自动重连机制
/// - 连接状态管理
/// - 异步事件处理（避免阻塞主线程）
///
/// ## 使用示例
/// ```swift
/// let service = IntercomWebSocketService()
/// service.onAudioDataReceived = { data in
///     // 处理接收到的音频数据
/// }
/// service.onConnectionStateChanged = { isConnected in
///     // 处理连接状态变化
/// }
/// service.connect(deviceId: "device123", serverURL: "ws://192.168.1.100:8080")
/// ```
class IntercomWebSocketService: WebSocketDelegate {
    // MARK: - Properties

    /// WebSocket 连接实例
    private var socket: WebSocket?

    /// 连接状态标志
    private var isConnected = false

    /// 专用队列处理 WebSocket 事件，避免优先级反转
    private let websocketQueue = DispatchQueue(label: "com.simpleeyes.websocket", qos: .userInitiated)

    // MARK: - Callbacks

    /// 接收到音频数据的回调
    /// - Parameter data: 接收到的音频数据（二进制格式）
    var onAudioDataReceived: ((Data) -> Void)?

    /// 连接状态变化的回调
    /// - Parameter isConnected: 是否已连接
    var onConnectionStateChanged: ((Bool) -> Void)?

    // MARK: - Initialization

    init() {}

    // MARK: - Connection Management

    /// 连接到 WebSocket 服务器
    ///
    /// - Parameters:
    ///   - deviceId: 设备唯一标识符
    ///   - serverURL: WebSocket 服务器 URL（已包含 deviceId 参数）
    ///
    /// - Note: URL 格式应为: ws://host:port?deviceId=xxx
    func connect(deviceId: String, serverURL: String) {
        // serverURL 已经包含了 ?deviceId= 参数，直接使用
        guard let url = URL(string: serverURL) else {
            print("[IntercomWebSocketService] Invalid URL: \(serverURL)")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.addValue("app", forHTTPHeaderField: "x-role")

        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()

        print("[IntercomWebSocketService] Connecting to: \(serverURL)")
    }

    /// 断开 WebSocket 连接
    func disconnect() {
        socket?.disconnect()
        socket = nil
        isConnected = false
        print("[IntercomWebSocketService] Disconnected")
    }

    // MARK: - Audio Transmission

    /// 发送音频数据
    ///
    /// - Parameter data: 要发送的音频数据（二进制格式）
    ///
    /// - Note: 只有在连接状态下才会发送数据，否则会输出警告日志
    func sendAudioData(_ data: Data) {
        guard isConnected else {
            print("[IntercomWebSocketService] Cannot send: not connected")
            return
        }
        socket?.write(data: data)
    }

    // MARK: - WebSocketDelegate

    /// WebSocket 事件处理方法
    ///
    /// 处理所有 WebSocket 事件，包括连接、断开、数据接收、错误等
    /// 所有事件都在专用队列上异步处理，确保不阻塞主线程
    ///
    /// - Parameters:
    ///   - event: WebSocket 事件类型
    ///   - client: WebSocket 客户端实例
    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        // 在 websocket 队列上处理所有事件，确保一致的 QoS
        websocketQueue.async { [weak self] in
            guard let self = self else { return }

            switch event {
            case .connected(let headers):
                print("[IntercomWebSocketService] Connected: \(headers)")
                self.isConnected = true
                self.onConnectionStateChanged?(true)

            case .disconnected(let reason, let code):
                print("[IntercomWebSocketService] Disconnected: \(reason) with code: \(code)")
                self.isConnected = false
                self.onConnectionStateChanged?(false)

            case .text(let string):
                print("[IntercomWebSocketService] Received text: \(string)")

            case .binary(let data):
                // 接收到音频数据
                self.onAudioDataReceived?(data)

            case .error(let error):
                print("[IntercomWebSocketService] Error: \(error?.localizedDescription ?? "unknown")")
                self.isConnected = false
                self.onConnectionStateChanged?(false)

            case .cancelled:
                print("[IntercomWebSocketService] Cancelled")
                self.isConnected = false
                self.onConnectionStateChanged?(false)

            case .reconnectSuggested(let shouldReconnect):
                print("[IntercomWebSocketService] Reconnect suggested: \(shouldReconnect)")

            case .viabilityChanged(let isViable):
                print("[IntercomWebSocketService] Viability changed: \(isViable)")

            case .peerClosed:
                print("[IntercomWebSocketService] Peer closed")
                self.isConnected = false
                self.onConnectionStateChanged?(false)

            case .ping(_), .pong(_):
                break // 忽略 ping/pong
            }
        }
    }
}
