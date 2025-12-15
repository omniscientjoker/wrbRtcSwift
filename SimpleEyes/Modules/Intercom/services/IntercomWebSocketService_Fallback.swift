//
//  IntercomWebSocketService_Fallback.swift
//  SimpleEyes
//
//  WebSocket 对讲服务备用实现 - 基于原生 URLSession
//  当 Starscream 框架出现兼容性问题时使用此实现
//

import Foundation

/// WebSocket 对讲服务（备用实现）
///
/// 使用 iOS 原生 URLSession 实现的 WebSocket 客户端
/// 功能与 IntercomWebSocketService 完全相同，但不依赖第三方库
///
/// ## 使用场景
/// - Starscream 框架兼容性问题
/// - 需要减少第三方依赖
/// - iOS 13+ 系统（URLSession WebSocket API 最低要求）
///
/// ## 切换方法
/// 在 IntercomManager.swift 中替换：
/// ```swift
/// // 原实现
/// // private var wsService: IntercomWebSocketService
/// // 替换为
/// private var wsService: IntercomWebSocketServiceFallback
/// ```
class IntercomWebSocketServiceFallback: NSObject {
    // MARK: - Properties

    /// WebSocket 任务实例
    private var webSocketTask: URLSessionWebSocketTask?

    /// 连接状态标志
    private var isConnected = false

    // MARK: - Callbacks

    /// 接收到音频数据的回调
    var onAudioDataReceived: ((Data) -> Void)?

    /// 连接状态变化的回调
    var onConnectionStateChanged: ((Bool) -> Void)?

    // MARK: - Connection Management

    /// 连接到 WebSocket 服务器
    ///
    /// - Parameters:
    ///   - deviceId: 设备唯一标识符
    ///   - serverURL: WebSocket 服务器 URL
    func connect(deviceId: String, serverURL: String) {
        guard let url = URL(string: "\(serverURL)?deviceId=\(deviceId)") else {
            print("[IntercomWebSocketService] Invalid URL: \(serverURL)")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.addValue("app", forHTTPHeaderField: "x-role")

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        isConnected = true
        onConnectionStateChanged?(true)

        // 开始接收消息
        receiveMessage()

        print("[IntercomWebSocketService] Connecting to: \(serverURL)")
    }

    /// 断开 WebSocket 连接
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        onConnectionStateChanged?(false)
        print("[IntercomWebSocketService] Disconnected")
    }

    // MARK: - Audio Transmission

    /// 发送音频数据
    ///
    /// - Parameter data: 要发送的音频数据（二进制格式）
    func sendAudioData(_ data: Data) {
        guard isConnected else {
            print("[IntercomWebSocketService] Cannot send: not connected")
            return
        }

        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { [weak self] error in
            if let error = error {
                print("[IntercomWebSocketService] Send error: \(error)")
                self?.isConnected = false
                self?.onConnectionStateChanged?(false)
            }
        }
    }

    // MARK: - Receive Messages

    /// 接收 WebSocket 消息
    ///
    /// 异步接收消息，处理完成后自动调用自身继续接收下一条消息
    /// 实现了递归接收机制
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    // 接收到音频数据
                    self.onAudioDataReceived?(data)

                case .string(let text):
                    print("[IntercomWebSocketService] Received text: \(text)")

                @unknown default:
                    break
                }

                // 继续接收下一条消息
                self.receiveMessage()

            case .failure(let error):
                print("[IntercomWebSocketService] Receive error: \(error)")
                self.isConnected = false
                self.onConnectionStateChanged?(false)
            }
        }
    }
}

/*
 使用说明：

 如果 Starscream 有兼容性问题，可以在 IntercomManager.swift 中使用这个类：

 // 替换原来的实现
 // private var wsService: IntercomWebSocketService
 private var wsService: IntercomWebSocketServiceFallback

 // 初始化
 wsService = IntercomWebSocketServiceFallback()

 其他使用方式完全相同。
 */
