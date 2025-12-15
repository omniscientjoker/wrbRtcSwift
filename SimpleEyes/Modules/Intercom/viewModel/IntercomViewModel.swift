//
//  IntercomViewModel.swift
//  SimpleEyes
//
//  语音对讲视图模型 - MVVM 架构
//  负责语音对讲功能的状态管理和业务逻辑
//

import Foundation
import Combine
import AVFoundation

/// 语音对讲视图模型
///
/// 使用 MVVM 架构管理语音对讲功能
/// 主要功能：
/// - 加载在线设备列表
/// - 管理对讲状态（空闲/连接中/已连接/通话中/错误）
/// - 请求麦克风权限
/// - 开始/停止对讲
/// - 状态图标和颜色提供
///
/// 使用 @MainActor 确保所有 UI 更新在主线程执行
@MainActor
class IntercomViewModel: ObservableObject {

    // MARK: - 发布属性

    /// 设备ID输入（已废弃，改用 selectedDevice）
    @Published var deviceIdInput: String = ""

    /// 对讲状态
    ///
    /// 表示当前对讲的连接和通话状态
    @Published var intercomStatus: IntercomStatus = .idle

    /// 错误消息
    @Published var errorMessage: String?

    /// 在线设备列表
    ///
    /// 从服务器获取的可用对讲设备
    @Published var onlineDevices: [OnlineDevice] = []

    /// 选中的设备
    ///
    /// 用户当前选择要对讲的设备
    @Published var selectedDevice: OnlineDevice?

    /// 设备列表加载状态
    @Published var isLoadingDevices: Bool = false

    // MARK: - 私有属性

    /// 对讲管理器
    ///
    /// 负责实际的音频采集、编码和传输
    private var intercomManager: IntercomManager?

    /// Combine 订阅集合
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    /// 初始化对讲视图模型
    ///
    /// - Parameter deviceId: 初始设备ID（可选）
    init(deviceId: String = "") {
        self.deviceIdInput = deviceId
    }

    // MARK: - 计算属性

    /// 是否可以开始对讲
    ///
    /// 条件：已选择设备且当前状态为空闲
    var canStart: Bool {
        selectedDevice != nil && intercomStatus == .idle
    }

    /// 是否正在说话
    ///
    /// 用于触发 UI 动画效果
    var isSpeaking: Bool {
        if case .speaking = intercomStatus {
            return true
        }
        return false
    }

    /// 状态颜色标识
    ///
    /// 根据对讲状态返回对应的颜色名称
    /// - Returns: 颜色名称字符串
    var statusColor: String {
        switch intercomStatus {
        case .idle:
            return "gray"
        case .connecting:
            return "orange"
        case .connected, .speaking:
            return "green"
        case .error:
            return "red"
        }
    }

    /// 状态图标名称
    ///
    /// 根据对讲状态返回对应的 SF Symbol 图标名
    /// - Returns: SF Symbol 图标名称
    var statusIcon: String {
        switch intercomStatus {
        case .idle:
            return "mic.slash"
        case .connecting:
            return "mic.badge.plus"
        case .connected:
            return "mic"
        case .speaking:
            return "mic.fill"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    // MARK: - 公共方法

    /// 加载在线设备列表
    ///
    /// 从服务器获取当前在线的设备列表
    /// 支持保持已选设备的选中状态
    func loadOnlineDevices() {
        guard !isLoadingDevices else { return }

        isLoadingDevices = true
        errorMessage = nil

        APIClient.shared.getOnlineDevices { [weak self] result in
            guard let self = self else { return }

            Task { @MainActor in
                self.isLoadingDevices = false

                switch result {
                case .success(let response):
                    self.onlineDevices = response.devices
                    print("[IntercomViewModel] Loaded \(response.devices.count) online devices")

                    // 如果之前有选中的设备，尝试保持选中状态
                    if let selectedDeviceId = self.selectedDevice?.deviceId {
                        self.selectedDevice = response.devices.first { $0.deviceId == selectedDeviceId }
                    }

                case .failure(let error):
                    let errorMsg: String
                    switch error {
                    case .networkError:
                        errorMsg = "无法连接到服务器，请检查服务器配置"
                    case .decodingError:
                        errorMsg = "服务器响应格式错误"
                    case .serverError(let message):
                        errorMsg = "服务器错误: \(message)"
                    case .invalidResponse:
                        errorMsg = "无效的服务器响应"
                    }
                    self.errorMessage = errorMsg
                    print("[IntercomViewModel] Failed to load online devices: \(error)")
                }
            }
        }
    }

    /// 开始语音对讲
    ///
    /// 执行流程：
    /// 1. 检查是否已选择设备
    /// 2. 请求麦克风权限
    /// 3. 创建对讲管理器
    /// 4. 设置状态回调
    /// 5. 启动对讲连接
    func startIntercom() {
        guard canStart, let device = selectedDevice else { return }

        errorMessage = nil

        // 首先请求麦克风权限
        requestMicrophonePermission { [weak self] granted in
            guard let self = self else { return }

            Task { @MainActor in
                if !granted {
                    self.errorMessage = "需要麦克风权限才能使用对讲功能"
                    self.intercomStatus = .error("麦克风权限被拒绝")
                    return
                }

                // 创建对讲管理器，使用选中的设备ID
                let manager = IntercomManager(deviceId: device.deviceId)
                self.intercomManager = manager

                // 设置状态回调
                manager.onStatusChanged = { [weak self] status in
                    guard let self = self else { return }

                    Task { @MainActor in
                        self.intercomStatus = status
                        if case .error(let message) = status {
                            self.errorMessage = message
                        }
                    }
                }

                // 开始对讲
                manager.startIntercom()
            }
        }
    }

    // MARK: - 权限辅助方法

    /// 请求麦克风权限
    ///
    /// 检查并请求 AVFoundation 音频录制权限
    /// - Parameter completion: 权限结果回调，true 表示已授权
    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            completion(true)

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }

        case .denied, .restricted:
            completion(false)

        @unknown default:
            completion(false)
        }
    }

    /// 停止语音对讲
    ///
    /// 清理对讲管理器并重置状态
    func stopIntercom() {
        intercomManager?.stopIntercom()
        intercomManager = nil
        intercomStatus = .idle
        errorMessage = nil
    }

    // MARK: - 资源清理

    /// 清理对讲资源
    ///
    /// 在对象销毁前调用，确保对讲连接被正确关闭
    nonisolated private func cleanup() {
        Task { @MainActor in
            intercomManager?.stopIntercom()
            intercomManager = nil
        }
    }

    /// 析构函数
    ///
    /// 自动清理对讲资源
    deinit {
        cleanup()
    }
}
