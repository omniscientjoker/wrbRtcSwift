//
//  SettingsViewModel.swift
//  SimpleEyes
//
//  设置视图模型 - MVVM 架构
//  负责应用配置管理和服务器发现功能
//

import Foundation
import Combine

/// 设置视图模型
///
/// 使用 MVVM 架构管理应用配置
/// 主要功能：
/// - API 和 WebSocket 服务器地址配置
/// - 局域网服务器自动发现
/// - 配置的保存和恢复
/// - UserDefaults 持久化
///
/// 使用 @MainActor 确保所有 UI 更新在主线程执行
@MainActor
class SettingsViewModel: ObservableObject {

    // MARK: - 发布属性

    /// API 服务器地址
    ///
    /// 通过 didSet 自动保存到 UserDefaults
    @Published var apiServerURL: String {
        didSet {
            UserDefaults.standard.set(apiServerURL, forKey: "apiServerURL")
        }
    }

    /// WebSocket 服务器地址
    ///
    /// 通过 didSet 自动保存到 UserDefaults
    @Published var wsServerURL: String {
        didSet {
            UserDefaults.standard.set(wsServerURL, forKey: "wsServerURL")
        }
    }

    /// 是否显示保存成功提示
    @Published var showingSaveAlert = false

    /// 是否显示重置确认提示
    @Published var showingResetAlert = false

    /// 是否显示服务器选择器弹框
    @Published var showingServerPicker = false

    /// 选中的发现服务器
    @Published var selectedServer: DiscoveredServer?

    // MARK: - 私有属性

    /// Combine 订阅集合
    private var cancellables = Set<AnyCancellable>()

    /// 服务器发现服务（混合模式：Bonjour + Multicast）
    ///
    /// 同时使用 Bonjour 和 UDP Multicast 自动发现局域网中的信令服务器
    @Published var discoveryService = HybridServerDiscoveryService()

    // MARK: - 初始化

    /// 初始化设置视图模型
    ///
    /// 从 UserDefaults 加载已保存的配置
    /// 如果没有保存的配置，使用默认值
    init() {
        self.apiServerURL = UserDefaults.standard.string(forKey: "apiServerURL") ?? APIConfig.baseURL
        self.wsServerURL = UserDefaults.standard.string(forKey: "wsServerURL") ?? APIConfig.wsURL

        // 订阅 discoveryService 的变化，触发 UI 更新
        discoveryService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    // MARK: - 计算属性

    /// 配置是否有变更
    ///
    /// 对比当前配置与默认配置
    /// - Returns: true 表示已修改配置
    var hasChanges: Bool {
        apiServerURL != APIConfig.baseURL || wsServerURL != APIConfig.wsURL
    }

    // MARK: - 公共方法

    /// 保存配置
    ///
    /// 配置已通过 didSet 自动保存
    /// 此方法仅显示保存成功提示
    func saveSettings() {
        // 设置已自动保存通过 didSet
        showingSaveAlert = true
    }

    /// 恢复默认配置
    ///
    /// 将 API 和 WebSocket 地址重置为默认值
    func resetToDefaults() {
        apiServerURL = APIConfig.baseURL
        wsServerURL = APIConfig.wsURL
    }

    /// 请求重置确认
    ///
    /// 显示重置确认对话框
    func requestReset() {
        showingResetAlert = true
    }

    /// 开始扫描局域网服务器
    ///
    /// 启动混合服务发现（Bonjour + Multicast）
    /// 设置状态标志显示服务器选择器
    func startServerDiscovery() {
        discoveryService.startDiscovery()
        showingServerPicker = true
    }

    /// 停止扫描
    ///
    /// 停止服务器发现扫描
    func stopServerDiscovery() {
        discoveryService.stopDiscovery()
    }

    /// 暂停扫描
    ///
    /// 暂停服务器发现扫描（保持当前进度）
    func pauseServerDiscovery() {
        discoveryService.pauseScanning()
    }

    /// 恢复扫描
    ///
    /// 从暂停状态恢复扫描
    func resumeServerDiscovery() {
        discoveryService.resumeScanning()
    }

    /// 选择发现的服务器
    ///
    /// 将发现的服务器地址应用到配置、停止扫描并关闭选择器
    /// - Parameter server: 选中的服务器信息
    func selectServer(_ server: DiscoveredServer) {
        selectedServer = server
        apiServerURL = server.apiURL
        wsServerURL = server.wsURL

        // 停止服务发现
        stopServerDiscovery()

        showingServerPicker = false
        print("[Settings] Selected server: \(server.displayName)")
        print("[Settings] Stopped server discovery")
    }

    /// 取消服务器选择
    ///
    /// 关闭服务器选择器并停止扫描
    func cancelServerSelection() {
        showingServerPicker = false
        stopServerDiscovery()
    }
}
