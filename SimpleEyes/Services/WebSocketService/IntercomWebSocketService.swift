import Foundation
import Starscream

class IntercomWebSocketService: WebSocketDelegate {
    private var socket: WebSocket?
    private var isConnected = false

    // 使用专用队列处理 WebSocket 事件，避免优先级反转
    private let websocketQueue = DispatchQueue(label: "com.simpleeyes.websocket", qos: .userInitiated)

    var onAudioDataReceived: ((Data) -> Void)?
    var onConnectionStateChanged: ((Bool) -> Void)?

    init() {}

    // MARK: - Connection Management

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

    func disconnect() {
        socket?.disconnect()
        socket = nil
        isConnected = false
        print("[IntercomWebSocketService] Disconnected")
    }

    // MARK: - Audio Transmission

    func sendAudioData(_ data: Data) {
        guard isConnected else {
            print("[IntercomWebSocketService] Cannot send: not connected")
            return
        }
        socket?.write(data: data)
    }

    // MARK: - WebSocketDelegate

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
