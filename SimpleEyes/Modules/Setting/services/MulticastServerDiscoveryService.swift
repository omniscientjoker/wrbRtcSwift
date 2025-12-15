//
//  MulticastServerDiscoveryService.swift
//  SimpleEyes
//
//  基于 UDP Multicast 的服务器发现服务
//  使用自定义 UDP 多播协议进行局域网服务发现
//

import Foundation
import Network
import Combine

/// 基于 UDP Multicast 的服务器发现服务
///
/// 使用 UDP 多播接收服务器广播的服务信息
///
/// ## 功能特性
/// - 基于 UDP 多播协议
/// - 监听服务器心跳广播
/// - 实时解析服务器信息
/// - 支持 TTL 管理（自动移除过期服务）
///
/// ## 多播配置
/// - 多播地址：`239.255.255.250`
/// - 多播端口：`12345`
/// - 消息格式：JSON
///
/// ## 使用示例
/// ```swift
/// let discovery = MulticastServerDiscoveryService()
/// discovery.startListening()
/// // 监听 discoveredServers 数组变化
/// ForEach(discovery.discoveredServers) { server in
///     Text(server.displayName)
/// }
/// ```
///
@MainActor
class MulticastServerDiscoveryService: ObservableObject {
    // MARK: - Published Properties

    /// 已发现的服务器列表
    @Published var discoveredServers: [DiscoveredServer] = []

    /// 是否正在监听
    @Published var isScanning = false

    /// 扫描进度（兼容旧接口）
    @Published var scanProgress: Double = 0.0

    /// 是否暂停（兼容旧接口）
    @Published var isPaused = false

    // MARK: - Private Properties

    /// UDP 监听连接
    private var listener: NWListener?

    /// 多播地址
    private let multicastAddress = "239.255.255.250"

    /// 多播端口
    private let multicastPort: UInt16 = 12345

    /// 服务器超时时间（秒）
    private let serverTimeout: TimeInterval = 30

    /// 服务器最后活跃时间
    private var serverLastSeen: [String: Date] = [:]

    /// 清理定时器
    private var cleanupTimer: Timer?

    // MARK: - Public Methods

    /// 开始监听多播消息
    func startListening() {
        guard !isScanning else { return }

        print("[Multicast] Starting UDP multicast listener...")
        print("[Multicast] Multicast address: \(multicastAddress):\(multicastPort)")

        discoveredServers.removeAll()
        serverLastSeen.removeAll()

        do {
            // 创建 UDP 监听器
            let params = NWParameters.udp

            // 配置监听选项，允许地址复用
            params.allowLocalEndpointReuse = true
            params.acceptLocalOnly = false

            // 创建监听器
            listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: multicastPort))

            // 设置状态处理
            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }

                    switch state {
                    case .ready:
                        print("[Multicast] Listener ready on port \(self.multicastPort)")
                        self.isScanning = true
                        self.scanProgress = 0.5

                        // 加入多播组
                        self.joinMulticastGroup()

                    case .failed(let error):
                        print("[Multicast] Listener failed: \(error)")
                        self.isScanning = false
                        self.scanProgress = 0.0

                    case .cancelled:
                        print("[Multicast] Listener cancelled")
                        self.isScanning = false
                        self.scanProgress = 0.0

                    default:
                        break
                    }
                }
            }

            // 设置新连接处理
            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.handleIncomingConnection(connection)
                }
            }

            // 启动监听器
            listener?.start(queue: .main)

            // 启动清理定时器
            startCleanupTimer()

            isScanning = true
            scanProgress = 0.5

        } catch {
            print("[Multicast] Failed to create listener: \(error)")
        }
    }

    /// 停止监听
    func stopListening() {
        listener?.cancel()
        listener = nil
        isScanning = false
        scanProgress = 0.0

        cleanupTimer?.invalidate()
        cleanupTimer = nil

        print("[Multicast] Stopped listening")
    }

    /// 暂停扫描（兼容旧接口）
    func pauseScanning() {
        stopListening()
        isPaused = true
    }

    /// 恢复扫描（兼容旧接口）
    func resumeScanning() {
        isPaused = false
        startListening()
    }

    // MARK: - Private Methods

    /// 加入多播组
    private func joinMulticastGroup() {
        // 创建一个 UDP 连接来接收多播消息
        let host = NWEndpoint.Host(multicastAddress)
        let port = NWEndpoint.Port(integerLiteral: multicastPort)

        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        // 配置多播选项
        if let udpOptions = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            udpOptions.version = .v4
        }

        let connection = NWConnection(host: host, port: port, using: params)

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .ready:
                    print("[Multicast] Joined multicast group \(self?.multicastAddress ?? ""):\(self?.multicastPort ?? 0)")
                    // 开始接收数据
                    self?.receiveMulticastMessages(on: connection)

                case .failed(let error):
                    print("[Multicast] Failed to join multicast group: \(error)")

                default:
                    break
                }
            }
        }

        connection.start(queue: .main)
    }

    /// 接收多播消息
    private func receiveMulticastMessages(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            Task { @MainActor [weak self] in
                if let error = error {
                    print("[Multicast] Receive error: \(error)")
                    return
                }

                if let data = data, !data.isEmpty {
                    self?.handleMulticastMessage(data)
                }

                // 继续接收下一条消息
                self?.receiveMulticastMessages(on: connection)
            }
        }
    }

    /// 处理传入的连接
    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .ready:
                    self?.receiveData(on: connection)
                case .failed(let error):
                    print("[Multicast] Connection failed: \(error)")
                default:
                    break
                }
            }
        }

        connection.start(queue: .main)
    }

    /// 接收数据
    private func receiveData(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                if let error = error {
                    print("[Multicast] Receive error: \(error)")
                    return
                }

                if let data = data, !data.isEmpty {
                    self?.handleMulticastMessage(data)
                }

                if !isComplete {
                    self?.receiveData(on: connection)
                }
            }
        }
    }

    /// 处理多播消息
    private func handleMulticastMessage(_ data: Data) {
        do {
            // 解析 JSON 消息
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            guard let name = json?["name"] as? String,
                  let host = json?["host"] as? String,
                  let port = json?["port"] as? Int,
                  let apiURL = json?["apiURL"] as? String,
                  let wsURL = json?["wsURL"] as? String else {
                print("[Multicast] Invalid message format")
                return
            }

            let serverId = "\(host):\(port)"

            // 更新服务器最后活跃时间
            serverLastSeen[serverId] = Date()

            // 创建服务器对象
            let server = DiscoveredServer(
                host: host,
                port: port,
                apiURL: apiURL,
                wsURL: wsURL,
                name: name
            )

            // 避免重复添加
            if !discoveredServers.contains(where: { $0.host == server.host && $0.port == server.port }) {
                discoveredServers.append(server)
                scanProgress = 1.0
                print("[Multicast] Discovered server: \(server.displayName)")
            }

        } catch {
            print("[Multicast] Failed to parse message: \(error)")
        }
    }

    /// 启动清理定时器
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.cleanupStaleServers()
            }
        }
    }

    /// 清理过期服务器
    private func cleanupStaleServers() {
        let now = Date()

        // 移除超过 serverTimeout 秒没有收到心跳的服务器
        discoveredServers.removeAll { server in
            let serverId = "\(server.host):\(server.port)"
            guard let lastSeen = serverLastSeen[serverId] else {
                return true // 没有记录，移除
            }

            let elapsed = now.timeIntervalSince(lastSeen)
            if elapsed > serverTimeout {
                print("[Multicast] Removing stale server: \(server.displayName) (last seen \(Int(elapsed))s ago)")
                serverLastSeen.removeValue(forKey: serverId)
                return true
            }

            return false
        }
    }
}
