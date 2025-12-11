import Foundation

/// WebSocket 对讲服务（不依赖第三方库的备用实现）
/// 如果 Starscream 有兼容性问题，可以使用这个版本
class IntercomWebSocketServiceFallback: NSObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false

    var onAudioDataReceived: ((Data) -> Void)?
    var onConnectionStateChanged: ((Bool) -> Void)?

    // MARK: - Connection Management

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

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        onConnectionStateChanged?(false)
        print("[IntercomWebSocketService] Disconnected")
    }

    // MARK: - Audio Transmission

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
