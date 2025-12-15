//
//  PlaybackView.swift
//  SimpleEyes
//
//  视频回放页面 - MVVM 架构
//  提供历史录像查询和回放功能，支持日期筛选和录像列表展示
//

import SwiftUI

/// 视频回放主视图
///
/// 使用 MVVM 架构模式，通过 PlaybackViewModel 管理录像数据
/// 功能包括：
/// - 设备ID输入和验证
/// - 日期选择器（查询指定日期的录像）
/// - 录像列表展示
/// - 录像播放控制
/// - 错误和空状态处理
struct PlaybackView: View {

    // MARK: - 视图模型

    /// 回放视图模型
    ///
    /// 使用 @StateObject 确保视图生命周期内的单一实例
    /// 负责录像数据查询、列表管理和播放控制
    @StateObject private var viewModel: PlaybackViewModel

    // MARK: - 初始化方法

    /// 初始化回放视图
    ///
    /// - Parameter deviceId: 设备ID，默认为空字符串
    init(deviceId: String = "") {
        _viewModel = StateObject(wrappedValue: PlaybackViewModel(deviceId: deviceId))
    }

    // MARK: - 视图布局

    /// 构建回放视图层级
    ///
    /// 根据数据状态显示不同内容：
    /// - 错误：显示错误信息和重试按钮
    /// - 空列表：显示空状态提示
    /// - 正常：显示录像列表
    /// - Returns: 返回回放视图
    var body: some View {
        VStack(spacing: 16) {
            // 输入区域
            PlaybackInputSection(viewModel: viewModel)

            // 录像列表
            if let error = viewModel.errorMessage {
                ErrorView(message: error, retryAction: viewModel.loadRecordings)
            } else if viewModel.recordings.isEmpty && !viewModel.isLoading {
                EmptyView(
                    icon: "film",
                    message: "暂无录像",
                    actionTitle: "",
                    action: {}
                )
            } else {
                List(viewModel.recordings) { recording in
                    RecordingRowView(recording: recording) {
                        viewModel.playRecording(recording)
                    }
                }
                .listStyle(.plain)
            }

            Spacer()
        }
        .navigationBar(
            title: "视频回放",
            displayMode: .inline,
            trackingParameters: [
                "deviceId": viewModel.deviceIdInput,
                "selectedDate": viewModel.selectedDate.description,
                "recordingCount": viewModel.recordings.count,
                "from": "device_detail"
            ]
        )
    }
}

// MARK: - 输入区域组件

/// 回放输入区域视图
///
/// 提供设备ID输入、日期选择和查询功能
/// 包括：
/// - 设备ID输入框
/// - 日期选择器（compact样式）
/// - 查询录像按钮（带加载状态）
struct PlaybackInputSection: View {

    // MARK: - 属性

    /// 关联的回放视图模型
    @ObservedObject var viewModel: PlaybackViewModel

    // MARK: - 视图布局

    /// 构建输入区域视图
    ///
    /// 垂直布局：设备ID输入、日期选择、查询按钮
    /// 使用灰色背景和圆角样式
    /// - Returns: 返回输入区域视图
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 设备ID输入
            VStack(alignment: .leading, spacing: 8) {
                Text("设备ID")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("输入设备ID", text: $viewModel.deviceIdInput)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }

            // 日期选择
            VStack(alignment: .leading, spacing: 8) {
                Text("选择日期")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                DatePicker("", selection: $viewModel.selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }

            // 查询按钮
            Button(action: viewModel.loadRecordings) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Label("查询录像", systemImage: "magnifyingglass")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canQuery)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

/// 录像行视图
///
/// 展示单条录像的详细信息
/// 包括：
/// - 录像图标
/// - 时间范围（开始-结束）
/// - 时长和文件大小
/// - 播放按钮
struct RecordingRowView: View {

    // MARK: - 属性

    /// 录像数据对象
    let recording: Recording

    /// 播放录像回调闭包
    let onPlay: () -> Void

    // MARK: - 格式化工具

    /// 时间格式化器
    ///
    /// 将时间格式化为 "HH:mm:ss" 格式
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    // MARK: - 视图布局

    /// 构建录像行视图
    ///
    /// 横向布局：图标、录像信息、播放按钮
    /// - Returns: 返回录像行视图
    var body: some View {
        HStack {
            Image(systemName: "film.fill")
                .font(.system(size: 30))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(timeFormatter.string(from: recording.startTime)) - \(timeFormatter.string(from: recording.endTime))")
                    .font(.headline)

                HStack {
                    Label(recording.formattedDuration, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label(recording.formattedSize, systemImage: "doc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: onPlay) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 快速入口视图

/// 快速回放视图
///
/// 从主页快速入口进入的回放视图
/// 提供独立的导航容器和页面追踪
struct QuickPlaybackView: View {

    // MARK: - 视图布局

    /// 构建快速回放视图
    ///
    /// 包装在 NavigationView 中，提供独立的导航栈
    /// - Returns: 返回快速回放视图
    var body: some View {
        NavigationView {
            PlaybackInputNavigator()
                .navigationBar(
                    title: "视频回放",
                    trackingParameters: [
                        "from": "quick_launch"
                    ]
                )
        }
    }
}

/// 回放输入导航视图
///
/// 快速入口的设备ID输入和导航界面
/// 允许用户输入设备ID后导航到回放页面
struct PlaybackInputNavigator: View {

    // MARK: - 状态属性

    /// 设备ID输入框文本
    @State private var deviceIdInput: String = ""

    // MARK: - 视图布局

    /// 构建输入导航视图
    ///
    /// 提供设备ID输入和导航到回放页面的入口
    /// - Returns: 返回输入导航视图
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "film.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            Text("视频回放")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                Text("设备ID")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("输入设备ID", text: $deviceIdInput)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal)

            NavigationLink(destination: PlaybackView(deviceId: deviceIdInput)) {
                Label("查看回放", systemImage: "play.rectangle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(deviceIdInput.isEmpty)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

// MARK: - 预览

/// SwiftUI 预览提供者
///
/// 用于在 Xcode 中实时预览 PlaybackView 的显示效果
#Preview {
    PlaybackView(deviceId: "device-001")
}
