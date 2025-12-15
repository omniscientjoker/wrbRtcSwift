//
//  ServerDiscoveryService.swift
//  SimpleEyes
//
//  局域网服务器发现服务 - 自动扫描发现可用的服务器
//  使用并发扫描和健康检查机制
//

import Foundation
import Combine

/// 发现的服务器信息
///
/// 表示扫描发现的服务器详细信息
struct DiscoveredServer: Identifiable, Hashable {
    let id = UUID()
    let host: String
    let port: Int
    let apiURL: String
    let wsURL: String
    let name: String

    var displayName: String {
        "\(name) (\(host):\(port))"
    }
}

/// 局域网服务器发现服务
///
/// 自动扫描局域网内的 SimpleEyes 服务器
///
/// ## 功能特性
/// - 自动扫描 C 类子网（254 个 IP）
/// - 多端口并发检测（3000, 8080, 8000, 5000, 4000）
/// - 健康检查端点验证
/// - 实时进度更新
/// - 可取消的扫描任务
///
/// ## 扫描策略
/// - 并发限制：50 个并发连接
/// - 超时时间：500ms
/// - 网络权限：首次使用时自动请求
///
/// ## 使用示例
/// ```swift
/// let discovery = ServerDiscoveryService()
/// discovery.startScanning()
/// // 监听 discoveredServers 数组变化
/// ForEach(discovery.discoveredServers) { server in
///     Text(server.displayName)
/// }
/// ```
///
/// - Note: 需要在 Info.plist 中添加本地网络权限说明
@MainActor
class ServerDiscoveryService: ObservableObject {
    // MARK: - Published Properties

    @Published var discoveredServers: [DiscoveredServer] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0

    // MARK: - Private Properties

    private var scanTask: Task<Void, Never>?

    // 常见的服务器端口
    private let commonPorts = [3000, 8080, 8000, 5000, 4000]

    // MARK: - Initialization

    init() {
        // 所有属性都有默认值，不需要额外初始化
    }

    // MARK: - Public Methods

    /// 开始扫描局域网
    func startScanning() {
        guard !isScanning else { return }

        isScanning = true
        discoveredServers.removeAll()
        scanProgress = 0.0

        scanTask = Task {
            // 直接开始扫描，系统会在第一次网络请求时自动触发权限对话框
            await scanLocalNetwork()
        }
    }

    /// 停止扫描
    func stopScanning() {
        scanTask?.cancel()
        isScanning = false
    }

    // MARK: - Private Methods

    /// 扫描本地网络
    private func scanLocalNetwork() async {
        // 获取本机 IP 地址
        guard let localIP = getLocalIPAddress() else {
            print("[ServerDiscovery] Failed to get local IP address")
            await MainActor.run {
                isScanning = false
            }
            return
        }

        print("[ServerDiscovery] Local IP: \(localIP)")

        // 获取网络前缀（例如 192.168.1）
        let ipComponents = localIP.split(separator: ".")
        guard ipComponents.count == 4 else {
            await MainActor.run {
                isScanning = false
            }
            return
        }

        let networkPrefix = "\(ipComponents[0]).\(ipComponents[1]).\(ipComponents[2])"
        print("[ServerDiscovery] Scanning network: \(networkPrefix).0/24")

        // 构建所有要扫描的地址
        var addressesToScan: [(host: String, port: Int)] = []
        for i in 1...254 {
            let host = "\(networkPrefix).\(i)"
            for port in commonPorts {
                addressesToScan.append((host: host, port: port))
            }
        }

        let totalScans = addressesToScan.count
        var completedScans = 0

        // 使用限制并发数的方式扫描（每次最多50个并发）
        let concurrentLimit = 50
        for chunk in addressesToScan.chunked(into: concurrentLimit) {
            await withTaskGroup(of: [DiscoveredServer].self) { group in
                for address in chunk {
                    group.addTask {
                        await self.checkServer(host: address.host, port: address.port)
                    }
                }

                // 收集结果
                for await servers in group {
                    completedScans += 1

                    await MainActor.run {
                        // 添加发现的服务器（去重）
                        for server in servers {
                            if !self.discoveredServers.contains(where: { $0.host == server.host && $0.port == server.port }) {
                                self.discoveredServers.append(server)
                                print("[ServerDiscovery] Found server: \(server.displayName)")
                            }
                        }

                        // 更新进度
                        self.scanProgress = Double(completedScans) / Double(totalScans)
                    }
                }
            }

            // 检查是否被取消
            if Task.isCancelled {
                break
            }
        }

        await MainActor.run {
            isScanning = false
            scanProgress = 1.0
            print("[ServerDiscovery] Scan completed. Found \(discoveredServers.count) servers")
        }
    }

    /// 检查指定主机和端口是否有服务器
    private func checkServer(host: String, port: Int) async -> [DiscoveredServer] {
        // 尝试连接 HTTP API
        let apiURL = "http://\(host):\(port)"

        // 创建请求检测服务器
        guard let url = URL(string: "\(apiURL)/api/health") else {
            return []
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 0.5 // 0.5秒超时（局域网应该很快）
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }

            // 尝试解析响应
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let serverName = json["name"] as? String {

                // 构建 WebSocket URL
                let wsURL = "ws://\(host):\(port)"

                let server = DiscoveredServer(
                    host: host,
                    port: port,
                    apiURL: apiURL,
                    wsURL: wsURL,
                    name: serverName
                )

                return [server]
            }

            // 即使没有健康检查端点，如果能连接也记录
            let server = DiscoveredServer(
                host: host,
                port: port,
                apiURL: apiURL,
                wsURL: "ws://\(host):\(port)",
                name: "未知服务器"
            )

            return [server]

        } catch {
            // 连接失败，忽略（正常情况，大部分地址没有服务器）
            return []
        }
    }

    /// 获取本机局域网 IP 地址
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }

        defer {
            freeifaddrs(ifaddr)
        }

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee

            // 检查是否是 IPv4
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {

                // 检查接口名称
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" { // WiFi 或以太网

                    // 转换地址
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr,
                              socklen_t(interface.ifa_addr.pointee.sa_len),
                              &hostname,
                              socklen_t(hostname.count),
                              nil,
                              socklen_t(0),
                              NI_NUMERICHOST)

                    address = String(cString: hostname)

                    // 如果找到了局域网地址，返回
                    if let addr = address, addr.hasPrefix("192.168.") || addr.hasPrefix("10.") || addr.hasPrefix("172.") {
                        return addr
                    }
                }
            }
        }

        return address
    }
}

// MARK: - Array Extension

extension Array {
    /// 将数组分块
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
