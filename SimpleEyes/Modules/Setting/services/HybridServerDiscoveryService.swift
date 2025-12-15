//
//  HybridServerDiscoveryService.swift
//  SimpleEyes
//
//  混合服务器发现服务
//  同时使用 Bonjour (mDNS) 和 UDP Multicast 进行服务发现
//

import Foundation
import Combine

/// 混合服务器发现服务
///
/// 整合 Bonjour 和 UDP Multicast 两种发现方式，提供最佳的服务发现体验
///
/// ## 功能特性
/// - 同时使用 Bonjour 和 Multicast 发现
/// - 自动去重合并结果
/// - 优先使用 Bonjour（更快更可靠）
/// - Multicast 作为补充方案
///
/// ## 发现策略
/// 1. 启动时同时启动两种发现服务
/// 2. 合并去重发现的服务器列表
/// 3. Bonjour 发现的服务器优先级更高
///
/// ## 使用示例
/// ```swift
/// let discovery = HybridServerDiscoveryService()
/// discovery.startDiscovery()
/// // 监听 discoveredServers 数组变化
/// ForEach(discovery.discoveredServers) { server in
///     Text(server.displayName)
/// }
/// ```
///
@MainActor
class HybridServerDiscoveryService: ObservableObject {
    // MARK: - Published Properties

    /// 已发现的服务器列表（合并后）
    @Published var discoveredServers: [DiscoveredServer] = []

    /// 是否正在扫描
    @Published var isScanning = false

    /// 扫描进度（兼容旧接口）
    @Published var scanProgress: Double = 0.0

    /// 是否暂停
    @Published var isPaused = false

    // MARK: - Private Properties

    /// Bonjour 服务发现
    private let bonjourService = BonjourServerDiscoveryService()

    /// Multicast 服务发现
    private let multicastService = MulticastServerDiscoveryService()

    /// Combine 订阅集合
    private var cancellables = Set<AnyCancellable>()

    /// 服务器去重字典 (host:port -> server)
    private var serverMap: [String: DiscoveredServer] = [:]

    // MARK: - Initialization

    init() {
        setupObservers()
    }

    // MARK: - Public Methods

    /// 开始服务发现
    func startDiscovery() {
        guard !isScanning else { return }

        print("[Hybrid] Starting hybrid service discovery (Bonjour + Multicast)...")

        // 清空之前的结果
        discoveredServers.removeAll()
        serverMap.removeAll()

        // 同时启动两种发现服务
        bonjourService.startBrowsing()
        multicastService.startListening()

        isScanning = true
        scanProgress = 0.5

        print("[Hybrid] Both discovery services started")
    }

    /// 停止服务发现
    func stopDiscovery() {
        bonjourService.stopBrowsing()
        multicastService.stopListening()

        isScanning = false
        scanProgress = 0.0

        print("[Hybrid] Both discovery services stopped")
    }

    /// 暂停扫描
    func pauseScanning() {
        bonjourService.pauseScanning()
        multicastService.pauseScanning()

        isPaused = true
    }

    /// 恢复扫描
    func resumeScanning() {
        bonjourService.resumeScanning()
        multicastService.resumeScanning()

        isPaused = false
    }

    // MARK: - Private Methods

    /// 设置观察者
    private func setupObservers() {
        // 监听 Bonjour 发现的服务器
        bonjourService.$discoveredServers
            .sink { [weak self] servers in
                Task { @MainActor [weak self] in
                    self?.handleBonjourServers(servers)
                }
            }
            .store(in: &cancellables)

        // 监听 Multicast 发现的服务器
        multicastService.$discoveredServers
            .sink { [weak self] servers in
                Task { @MainActor [weak self] in
                    self?.handleMulticastServers(servers)
                }
            }
            .store(in: &cancellables)

        // 监听 Bonjour 扫描状态
        bonjourService.$isScanning
            .combineLatest(multicastService.$isScanning)
            .sink { [weak self] bonjourScanning, multicastScanning in
                Task { @MainActor [weak self] in
                    // 只要有一个在扫描，就认为在扫描
                    self?.isScanning = bonjourScanning || multicastScanning
                }
            }
            .store(in: &cancellables)

        // 监听扫描进度
        bonjourService.$scanProgress
            .combineLatest(multicastService.$scanProgress)
            .sink { [weak self] bonjourProgress, multicastProgress in
                Task { @MainActor [weak self] in
                    // 取两者的平均值
                    self?.scanProgress = (bonjourProgress + multicastProgress) / 2.0
                }
            }
            .store(in: &cancellables)
    }

    /// 处理 Bonjour 发现的服务器
    private func handleBonjourServers(_ servers: [DiscoveredServer]) {
        for server in servers {
            let key = "\(server.host):\(server.port)"

            // Bonjour 发现的服务器优先级更高，直接覆盖
            serverMap[key] = server
            print("[Hybrid] Bonjour discovered: \(server.displayName)")
        }

        updateDiscoveredServers()
    }

    /// 处理 Multicast 发现的服务器
    private func handleMulticastServers(_ servers: [DiscoveredServer]) {
        for server in servers {
            let key = "\(server.host):\(server.port)"

            // 如果 Bonjour 还没有发现这个服务器，则添加 Multicast 发现的
            if serverMap[key] == nil {
                serverMap[key] = server
                print("[Hybrid] Multicast discovered: \(server.displayName)")
            } else {
                print("[Hybrid] Multicast duplicate (already found by Bonjour): \(server.displayName)")
            }
        }

        updateDiscoveredServers()
    }

    /// 更新发现的服务器列表
    private func updateDiscoveredServers() {
        // 从字典转换为数组，按名称排序
        discoveredServers = Array(serverMap.values).sorted { $0.name < $1.name }

        if !discoveredServers.isEmpty {
            scanProgress = 1.0
        }

        print("[Hybrid] Total unique servers: \(discoveredServers.count)")
    }
}
