//
//  IntercomViewModel.swift
//  SimpleEyes
//
//  语音对讲 ViewModel
//

import Foundation
import Combine
import AVFoundation

@MainActor
class IntercomViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var deviceIdInput: String = ""
    @Published var intercomStatus: IntercomStatus = .idle
    @Published var errorMessage: String?

    // 在线设备列表
    @Published var onlineDevices: [OnlineDevice] = []
    @Published var selectedDevice: OnlineDevice?
    @Published var isLoadingDevices: Bool = false

    // MARK: - Private Properties

    private var intercomManager: IntercomManager?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(deviceId: String = "") {
        self.deviceIdInput = deviceId
    }

    // MARK: - Computed Properties

    var canStart: Bool {
        selectedDevice != nil && intercomStatus == .idle
    }

    var isSpeaking: Bool {
        if case .speaking = intercomStatus {
            return true
        }
        return false
    }

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

    // MARK: - Public Methods

    /// 加载在线设备列表
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

    // MARK: - Permission Helpers

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

    func stopIntercom() {
        intercomManager?.stopIntercom()
        intercomManager = nil
        intercomStatus = .idle
        errorMessage = nil
    }

    // MARK: - Cleanup

    nonisolated private func cleanup() {
        Task { @MainActor in
            intercomManager?.stopIntercom()
            intercomManager = nil
        }
    }

    deinit {
        cleanup()
    }
}
