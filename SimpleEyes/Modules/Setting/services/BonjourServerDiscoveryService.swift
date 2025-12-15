//
//  BonjourServerDiscoveryService.swift
//  SimpleEyes
//
//  基于 Bonjour (mDNS) 的服务器发现服务
//  使用 Network.framework 进行高效的局域网服务发现
//

import Foundation
import Network
import Combine

/// 基于 Bonjour (mDNS) 的服务器发现服务
///
/// 使用标准的 mDNS 协议自动发现局域网内的 SimpleEyes 信令服务器
///
/// ## 功能特性
/// - 基于 Bonjour/mDNS 标准协议
/// - 实时服务发现（通常 1-2 秒内响应）
/// - 自动监听服务上线/下线
/// - 无需扫描 IP 地址范围
/// - Apple 原生 Network.framework 支持
///
/// ## 服务类型
/// - 服务类型：`_simpleyes._tcp`
/// - 服务名称：服务器自定义名称
/// - TXT 记录：包含 API 和 WebSocket 端口信息
///
/// ## 使用示例
/// ```swift
/// let discovery = BonjourServerDiscoveryService()
/// discovery.startBrowsing()
/// // 监听 discoveredServers 数组变化
/// ForEach(discovery.discoveredServers) { server in
///     Text(server.displayName)
/// }
/// ```
///
/// ## 服务端配置
/// 服务端需要使用 Bonjour 广播服务，例如使用 Node.js 的 bonjour 库：
/// ```javascript
/// const bonjour = require('bonjour')()
/// bonjour.publish({
///     name: 'SimpleEyes Server',
///     type: 'simpleyes',
///     port: 8080,
///     txt: { apiPort: '8080', wsPort: '8080' }
/// })
/// ```
///
@MainActor
class BonjourServerDiscoveryService: ObservableObject {
    // MARK: - Published Properties

    /// 已发现的服务器列表
    @Published var discoveredServers: [DiscoveredServer] = []

    /// 是否正在扫描服务（兼容旧接口名称）
    @Published var isScanning = false

    /// 扫描进度（兼容旧接口，Bonjour 模式下始终为 0 或 1）
    @Published var scanProgress: Double = 0.0

    /// 是否暂停（兼容旧接口，Bonjour 不支持暂停）
    @Published var isPaused = false

    // MARK: - Private Properties

    /// Network browser 用于发现服务
    private var browser: NWBrowser?

    /// 服务类型：_simpleyes._tcp（Bonjour 服务类型）
    private let serviceType = "_simpleyes._tcp"

    /// 存储正在解析的服务端点
    private var resolvingEndpoints: [NWEndpoint: NWConnection] = [:]

    // MARK: - Public Methods

    /// 开始浏览服务
    func startBrowsing() {
        guard !isScanning else { return }

        // 清空之前的结果
        discoveredServers.removeAll()
        resolvingEndpoints.removeAll()

        // 创建浏览器参数
        let parameters = NWParameters()
        parameters.includePeerToPeer = true // 包含点对点网络

        // 创建浏览器
        browser = NWBrowser(for: .bonjourWithTXTRecord(type: serviceType, domain: nil), using: parameters)

        // 设置浏览器状态处理
        browser?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch state {
                case .ready:
                    print("[Bonjour] Browser ready, searching for \(self.serviceType) services...")
                    self.isScanning = true
                    self.scanProgress = 0.5

                case .failed(let error):
                    print("[Bonjour] Browser failed: \(error)")
                    self.isScanning = false
                    self.scanProgress = 0.0

                case .cancelled:
                    print("[Bonjour] Browser cancelled")
                    self.isScanning = false
                    self.scanProgress = 0.0

                default:
                    break
                }
            }
        }

        // 设置浏览结果处理
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                print("[Bonjour] Browse results changed: \(results.count) services, \(changes.count) changes")

                for change in changes {
                    switch change {
                    case .added(let result):
                        print("[Bonjour] Service found: \(result.endpoint)")
                        self.resolveService(result)

                    case .removed(let result):
                        print("[Bonjour] Service removed: \(result.endpoint)")
                        self.removeService(result)

                    case .changed(old: _, new: let result, flags: _):
                        print("[Bonjour] Service changed: \(result.endpoint)")
                        self.resolveService(result)

                    case .identical:
                        break

                    @unknown default:
                        break
                    }
                }

                // 更新进度
                if !results.isEmpty {
                    self.scanProgress = 1.0
                }
            }
        }

        // 开始浏览
        browser?.start(queue: .main)

        print("[Bonjour] Started browsing for \(serviceType) services")
    }

    /// 停止浏览服务
    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        isScanning = false
        scanProgress = 0.0

        // 取消所有正在解析的连接
        for (_, connection) in resolvingEndpoints {
            connection.cancel()
        }
        resolvingEndpoints.removeAll()

        print("[Bonjour] Stopped browsing")
    }

    /// 暂停扫描（兼容旧接口，实际上停止浏览）
    func pauseScanning() {
        stopBrowsing()
        isPaused = true
    }

    /// 恢复扫描（兼容旧接口，重新开始浏览）
    func resumeScanning() {
        isPaused = false
        startBrowsing()
    }

    // MARK: - Private Methods

    /// 解析服务详情
    private func resolveService(_ result: NWBrowser.Result) {
        // 提取服务端点
        let endpoint = result.endpoint

        // 避免重复解析
        guard resolvingEndpoints[endpoint] == nil else {
            print("[Bonjour] Already resolving: \(endpoint)")
            return
        }

        // 提取服务名称和域名
        guard case .service(let name, let type, let domain, let interface) = endpoint else {
            print("[Bonjour] Invalid endpoint type: \(endpoint)")
            return
        }

        print("[Bonjour] Resolving service: \(name)")
        print("[Bonjour] Service details - type: \(type), domain: \(domain), interface: \(interface?.debugDescription ?? "none")")

        // 解析 TXT 记录获取端口信息（从 metadata 中获取）
        var apiPort: Int?
        var wsPort: Int?
        var serverName = name

        // 尝试从 result metadata 中获取 TXT 记录
        if case .bonjour(let txtRecord) = result.metadata {
            let txtDict = parseTXTRecord(txtRecord)
            print("[Bonjour] TXT records: \(txtDict)")

            if let apiPortStr = txtDict["apiPort"] {
                apiPort = Int(apiPortStr)
            }
            if let wsPortStr = txtDict["wsPort"] {
                wsPort = Int(wsPortStr)
            }
            if let customName = txtDict["name"] {
                serverName = customName
            }
        }

        // 创建连接以解析 IP 地址和端口
        let connection = NWConnection(to: endpoint, using: .tcp)
        resolvingEndpoints[endpoint] = connection

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch state {
                case .ready:
                    print("[Bonjour] Connection ready, extracting server info...")
                    // 获取远程端点信息
                    if let remoteEndpoint = connection.currentPath?.remoteEndpoint {
                        print("[Bonjour] Remote endpoint: \(remoteEndpoint)")
                        self.extractServerInfo(
                            from: remoteEndpoint,
                            name: serverName,
                            apiPort: apiPort,
                            wsPort: wsPort,
                            originalEndpoint: endpoint
                        )
                    }

                    // 解析完成，关闭连接
                    connection.cancel()
                    self.resolvingEndpoints.removeValue(forKey: endpoint)

                case .failed(let error):
                    print("[Bonjour] Connection failed for \(endpoint): \(error)")
                    connection.cancel()
                    self.resolvingEndpoints.removeValue(forKey: endpoint)

                case .cancelled:
                    self.resolvingEndpoints.removeValue(forKey: endpoint)

                default:
                    break
                }
            }
        }

        // 启动连接以触发地址解析
        connection.start(queue: .main)
    }

    /// 从端点提取服务器信息
    private func extractServerInfo(from endpoint: NWEndpoint, name: String, apiPort: Int?, wsPort: Int?, originalEndpoint: NWEndpoint) {
        switch endpoint {
        case .hostPort(let host, let port):
            var hostString: String?
            var portInt: Int?

            // 提取主机名/IP - 优先使用 IPv4
            switch host {
            case .ipv4(let address):
                hostString = address.debugDescription
                print("[Bonjour] Found IPv4 address: \(hostString ?? "unknown")")
            case .ipv6(let address):
                let ipv6String = address.debugDescription
                if isLinkLocalIPv6(ipv6String) {
                    print("[Bonjour] Got link-local IPv6: \(ipv6String), trying to resolve via original endpoint")
                    // 尝试使用原始端点重新连接，强制使用 IPv4
                    tryResolveWithIPv4Preference(originalEndpoint: originalEndpoint, name: name, apiPort: apiPort, wsPort: wsPort)
                    return
                } else {
                    hostString = ipv6String
                    print("[Bonjour] Found global IPv6 address: \(hostString ?? "unknown")")
                }
            case .name(let hostname, _):
                hostString = hostname
                print("[Bonjour] Found hostname: \(hostString ?? "unknown")")
            @unknown default:
                break
            }

            // 提取端口
            portInt = Int(port.rawValue)

            // 使用 TXT 记录中的端口或连接端口
            let finalAPIPort = apiPort ?? portInt ?? 8080
            let finalWSPort = wsPort ?? portInt ?? 8080

            if let host = hostString, let hostIP = extractIPAddress(from: host) {
                let server = DiscoveredServer(
                    host: hostIP,
                    port: finalAPIPort,
                    apiURL: "http://\(hostIP):\(finalAPIPort)",
                    wsURL: "ws://\(hostIP):\(finalWSPort)",
                    name: name
                )

                // 避免重复添加，如果已有相同名称的服务器，优先使用 IPv4
                if let existingIndex = discoveredServers.firstIndex(where: { $0.name == server.name }) {
                    let existing = discoveredServers[existingIndex]
                    // 如果新发现的是 IPv4 而旧的是 IPv6，替换
                    if isIPv4(hostIP) && !isIPv4(existing.host) {
                        discoveredServers[existingIndex] = server
                        print("[Bonjour] Replaced with IPv4: \(server.displayName)")
                    }
                } else if !discoveredServers.contains(where: { $0.host == server.host && $0.port == server.port }) {
                    discoveredServers.append(server)
                    print("[Bonjour] Added server: \(server.displayName)")
                }
            }

        default:
            print("[Bonjour] Unsupported endpoint type: \(endpoint)")
        }
    }

    /// 尝试使用 IPv4 偏好重新解析
    private func tryResolveWithIPv4Preference(originalEndpoint: NWEndpoint, name: String, apiPort: Int?, wsPort: Int?) {
        print("[Bonjour] Attempting to resolve with IPv4 preference...")

        // 创建偏好 IPv4 的网络参数
        let parameters = NWParameters.tcp
        parameters.preferNoProxies = true
        parameters.requiredInterfaceType = .wifi

        // 禁用 IPv6
        if let ipOptions = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ipOptions.version = .v4
        }

        let connection = NWConnection(to: originalEndpoint, using: parameters)

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch state {
                case .ready:
                    print("[Bonjour] IPv4-preferred connection ready")
                    if let remoteEndpoint = connection.currentPath?.remoteEndpoint {
                        print("[Bonjour] Resolved endpoint: \(remoteEndpoint)")
                        self.extractServerInfo(
                            from: remoteEndpoint,
                            name: name,
                            apiPort: apiPort,
                            wsPort: wsPort,
                            originalEndpoint: originalEndpoint
                        )
                    }
                    connection.cancel()

                case .failed(let error):
                    print("[Bonjour] IPv4-preferred resolution failed: \(error)")
                    connection.cancel()

                default:
                    break
                }
            }
        }

        connection.start(queue: .main)
    }

    /// 检查是否为 IPv4 地址
    private func isIPv4(_ address: String) -> Bool {
        return address.contains(".") && !address.contains(":")
    }

    /// 检查是否为 IPv6 链路本地地址
    private func isLinkLocalIPv6(_ address: String) -> Bool {
        let cleanAddress = address.replacingOccurrences(of: "Optional(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .lowercased()
        return cleanAddress.hasPrefix("fe80:")
    }

    /// 从主机字符串中提取 IP 地址
    private func extractIPAddress(from host: String) -> String? {
        // 移除可能的 IPv6 地址包装符号
        var cleanHost = host.replacingOccurrences(of: "Optional(", with: "")
        cleanHost = cleanHost.replacingOccurrences(of: ")", with: "")

        // 移除 IPv6 zone ID (例如 %en0)
        if let percentIndex = cleanHost.firstIndex(of: "%") {
            cleanHost = String(cleanHost[..<percentIndex])
        }

        // 简单验证 IP 地址格式
        if cleanHost.contains(".") || cleanHost.contains(":") {
            return cleanHost
        }

        return nil
    }

    /// 移除服务
    private func removeService(_ result: NWBrowser.Result) {
        let endpoint = result.endpoint

        // 如果正在解析，取消连接
        if let connection = resolvingEndpoints[endpoint] {
            connection.cancel()
            resolvingEndpoints.removeValue(forKey: endpoint)
        }

        // 从列表中移除（基于端点匹配）
        // 注意：这里简化处理，实际可能需要更精确的匹配
        // discoveredServers.removeAll { /* 匹配逻辑 */ }
    }

    /// 解析 TXT 记录
    private func parseTXTRecord(_ txtRecord: NWTXTRecord) -> [String: String] {
        var result: [String: String] = [:]

        // 遍历 TXT 记录的所有键值对
        for (key, value) in txtRecord {
            if case .string(let stringValue) = value {
                result[key] = stringValue
            } else if case .data(let data) = value {
                // 尝试将数据转换为字符串
                if let stringValue = String(data: data, encoding: .utf8) {
                    result[key] = stringValue
                }
            } else if case .empty = value {
                result[key] = ""
            }
        }

        return result
    }
}
