//
//  LiveVideoViewModel.swift
//  SimpleEyes
//
//  视频直播视图模型 - MVVM 架构
//  负责视频直播流的获取和播放控制
//

import Foundation
import Combine

/// 视频直播视图模型
///
/// 使用 MVVM 架构管理视频直播功能
/// 主要功能：
/// - 获取设备直播流地址
/// - 管理直播状态（空闲/加载/播放/错误）
/// - 停止直播流
///
/// 使用 @MainActor 确保所有 UI 更新在主线程执行
@MainActor
class LiveVideoViewModel: ObservableObject {

    // MARK: - 发布属性

    /// 设备ID输入
    ///
    /// 用于标识要观看直播的设备
    @Published var deviceIdInput: String = ""

    /// 直播流地址
    ///
    /// nil: 未获取到流地址或已停止
    /// 非空: 可用的视频流 URL
    @Published var streamUrl: String?

    /// 加载状态标志
    @Published var isLoading = false

    /// 错误消息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    /// Combine 订阅集合
    private var cancellables = Set<AnyCancellable>()

    /// API 客户端实例
    private let apiClient: APIClient

    // MARK: - 初始化

    /// 初始化直播视图模型
    ///
    /// - Parameters:
    ///   - deviceId: 初始设备ID，默认为空
    ///   - apiClient: API 客户端实例，默认使用共享实例
    init(deviceId: String = "", apiClient: APIClient = .shared) {
        self.deviceIdInput = deviceId
        self.apiClient = apiClient
    }

    // MARK: - 计算属性

    /// 是否可以开始直播
    ///
    /// 条件：设备ID不为空且未在加载中
    var canStartLive: Bool {
        !deviceIdInput.isEmpty && !isLoading
    }

    // MARK: - 公共方法

    /// 开始直播流
    ///
    /// 从服务器获取设备的直播流地址
    /// 成功后更新 streamUrl，View 将自动开始播放
    func startLiveStream() {
        guard canStartLive else { return }

        isLoading = true
        errorMessage = nil

        apiClient.getLiveStream(deviceId: deviceIdInput) { [weak self] result in
            guard let self = self else { return }

            Task { @MainActor in
                self.isLoading = false

                switch result {
                case .success(let response):
                    self.streamUrl = response.url
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// 停止直播流
    ///
    /// 清除流地址和错误信息，View 将停止播放
    func stopStream() {
        streamUrl = nil
        errorMessage = nil
    }
}
