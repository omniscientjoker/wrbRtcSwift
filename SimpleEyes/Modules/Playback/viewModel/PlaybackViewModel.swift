//
//  PlaybackViewModel.swift
//  SimpleEyes
//
//  视频回放视图模型 - MVVM 架构
//  负责录像回放列表的查询和播放控制
//

import Foundation
import Combine

/// 视频回放视图模型
///
/// 使用 MVVM 架构管理视频回放功能
/// 主要功能：
/// - 按日期查询录像列表
/// - 管理录像回放状态
/// - 播放指定录像
///
/// 使用 @MainActor 确保所有 UI 更新在主线程执行
@MainActor
class PlaybackViewModel: ObservableObject {
    // MARK: - 发布属性

    /// 设备ID输入
    @Published var deviceIdInput: String = ""

    /// 选中的查询日期
    @Published var selectedDate: Date = Date()

    /// 录像列表
    @Published var recordings: [Recording] = []

    /// 加载状态标志
    @Published var isLoading = false

    /// 错误消息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    /// Combine 订阅集合
    private var cancellables = Set<AnyCancellable>()

    /// API 客户端实例
    private let apiClient: APIClient

    /// 日期格式化器
    ///
    /// 格式：yyyy-MM-dd
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: - 初始化

    /// 初始化回放视图模型
    ///
    /// - Parameters:
    ///   - deviceId: 初始设备ID
    ///   - apiClient: API 客户端实例
    init(deviceId: String = "", apiClient: APIClient = .shared) {
        self.deviceIdInput = deviceId
        self.apiClient = apiClient
    }

    // MARK: - 计算属性

    /// 是否可以查询录像
    ///
    /// 条件：设备ID不为空且未在加载中
    var canQuery: Bool {
        !deviceIdInput.isEmpty && !isLoading
    }

    // MARK: - 公共方法

    /// 加载录像列表
    ///
    /// 根据设备ID和选定日期查询录像
    func loadRecordings() {
        guard canQuery else { return }

        isLoading = true
        errorMessage = nil

        let dateString = dateFormatter.string(from: selectedDate)

        apiClient.getPlaybackList(deviceId: deviceIdInput, date: dateString) { [weak self] result in
            guard let self = self else { return }

            Task { @MainActor in
                self.isLoading = false

                switch result {
                case .success(let response):
                    self.recordings = response.recordings
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.recordings = []
                }
            }
        }
    }

    /// 播放指定录像
    ///
    /// - Parameter recording: 要播放的录像记录
    /// - Note: 当前为占位实现，待完善
    func playRecording(_ recording: Recording) {
        // TODO: 实现录像播放
        print("Play recording: \(recording.url)")
    }
}
