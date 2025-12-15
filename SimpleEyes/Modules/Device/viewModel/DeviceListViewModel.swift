//
//  DeviceListViewModel.swift
//  SimpleEyes
//
//  设备列表视图模型 - MVVM 架构
//  负责设备列表的数据加载、刷新和状态管理
//

import Foundation
import Combine

/// 设备列表视图模型
///
/// 使用 MVVM 架构模式管理设备列表数据和业务逻辑
/// 主要功能：
/// - 从 API 加载设备列表
/// - 管理加载状态和错误信息
/// - 支持下拉刷新
/// - 响应式数据更新（使用 Combine）
///
/// 使用 @MainActor 确保所有 UI 更新在主线程执行
@MainActor
class DeviceListViewModel: ObservableObject {

    // MARK: - 发布属性

    /// 设备列表数组
    ///
    /// 使用 @Published 自动通知 View 更新
    /// 存储从服务器获取的所有设备信息
    @Published var devices: [Device] = []

    /// 加载状态标志
    ///
    /// true: 正在加载设备列表
    /// false: 加载完成或未开始
    @Published var isLoading = false

    /// 错误消息
    ///
    /// nil: 无错误
    /// 非空: 显示具体错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    /// Combine 订阅集合
    ///
    /// 存储所有 Combine 订阅，在对象销毁时自动取消
    private var cancellables = Set<AnyCancellable>()

    /// API 客户端实例
    ///
    /// 用于发起网络请求获取设备数据
    private let apiClient: APIClient

    // MARK: - 初始化

    /// 初始化设备列表视图模型
    ///
    /// - Parameter apiClient: API 客户端实例，默认使用共享实例
    ///   支持依赖注入，便于单元测试
    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - 公共方法

    /// 加载设备列表
    ///
    /// 从服务器获取设备列表数据
    /// 执行过程：
    /// 1. 设置加载状态和清除错误
    /// 2. 调用 API 获取设备列表
    /// 3. 在主线程更新 UI 状态
    /// 4. 处理成功或失败结果
    func loadDevices() {
        isLoading = true
        errorMessage = nil

        apiClient.getDeviceList { [weak self] result in
            guard let self = self else { return }

            Task { @MainActor in
                self.isLoading = false

                switch result {
                case .success(let response):
                    self.devices = response.devices
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// 刷新设备列表
    ///
    /// 提供下拉刷新功能的便捷方法
    /// 内部调用 loadDevices() 重新加载数据
    func refresh() {
        loadDevices()
    }
}
