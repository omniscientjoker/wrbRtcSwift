//
//  DeviceListView.swift
//  SimpleEyes
//
//  设备列表页面 - MVVM 架构
//  提供设备列表展示、设备详情查看和操作入口
//

import SwiftUI

/// 设备列表主视图
///
/// 使用 MVVM 架构模式，通过 DeviceListViewModel 管理数据和业务逻辑
/// 功能包括：
/// - 显示所有监控设备列表
/// - 设备状态实时展示（在线/离线）
/// - 下拉刷新设备列表
/// - 导航到设备详情页面
/// - 错误和空状态处理
struct DeviceListView: View {

    // MARK: - 视图模型

    /// 设备列表视图模型
    ///
    /// 使用 @StateObject 确保视图生命周期内的单一实例
    /// 负责设备数据加载、刷新和状态管理
    @StateObject private var viewModel = DeviceListViewModel()

    // MARK: - 视图布局

    /// 构建设备列表视图层级
    ///
    /// 根据视图模型状态展示不同内容：
    /// - 加载中：显示进度指示器
    /// - 错误：显示错误信息和重试按钮
    /// - 空列表：显示空状态提示
    /// - 正常：显示设备列表
    /// - Returns: 返回设备列表导航视图
    var body: some View {
        NavigationView {
            VStack {
                // 根据加载状态显示不同内容
                if viewModel.isLoading {
                    // 加载中状态：显示加载指示器
                    ProgressView("加载设备列表...")
                        .padding()
                } else if let error = viewModel.errorMessage {
                    // 错误状态：显示错误信息和重试按钮
                    ErrorView(message: error, retryAction: viewModel.loadDevices)
                } else if viewModel.devices.isEmpty {
                    // 空状态：显示空列表提示
                    EmptyView(
                        icon: "video.slash",
                        message: "暂无设备",
                        actionTitle: "刷新",
                        action: viewModel.loadDevices
                    )
                } else {
                    // 正常状态：显示设备列表
                    List(viewModel.devices) { device in
                        NavigationLink(destination: DeviceDetailView(device: device)) {
                            DeviceRowView(device: device)
                        }
                    }
                    .refreshable {
                        // 下拉刷新
                        viewModel.refresh()
                    }
                }
            }
            .toolbar {
                // 导航栏右侧刷新按钮
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: viewModel.refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                // 首次显示时加载设备列表
                if viewModel.devices.isEmpty {
                    viewModel.loadDevices()
                }
            }
            .navigationBar(
                title: "设备列表",
                displayMode: .inline,
                trackingParameters: [
                    "deviceCount": viewModel.devices.count,
                    "from": "main_tab"
                ]
            )
        }
    }
}

// MARK: - 设备行视图

/// 设备列表行视图
///
/// 展示单个设备的基本信息，包括：
/// - 设备图标（根据状态变色）
/// - 设备名称和型号
/// - 在线状态指示器
struct DeviceRowView: View {

    // MARK: - 属性

    /// 要显示的设备信息
    let device: Device

    // MARK: - 视图布局

    /// 构建设备行视图
    ///
    /// 使用 HStack 横向布局设备信息
    /// - Returns: 返回设备行视图
    var body: some View {
        HStack {
            // 设备图标（根据在线状态显示不同颜色）
            Image(systemName: "video.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(device.status == .online ? .green : .gray)

            // 设备信息（名称、型号、状态）
            VStack(alignment: .leading, spacing: 4) {
                // 设备名称
                Text(device.name)
                    .font(.headline)

                // 设备型号
                Text(device.model)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // 设备状态指示器
                HStack {
                    // 状态圆点
                    Circle()
                        .fill(device.status == .online ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)

                    // 状态文本
                    Text(device.status.displayText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 右侧箭头指示器
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 设备详情视图

/// 设备详情视图
///
/// 展示设备的详细信息并提供操作入口
/// 包括：
/// - 设备基本信息（ID、名称、型号、状态）
/// - 功能操作入口（直播、回放、对讲）
struct DeviceDetailView: View {

    // MARK: - 属性

    /// 要显示的设备信息
    let device: Device

    // MARK: - 视图布局

    /// 构建设备详情视图
    ///
    /// 使用分组列表展示设备信息和操作选项
    /// - Returns: 返回设备详情视图
    var body: some View {
        List {
            // 设备信息section
            Section("设备信息") {
                InfoRow(label: "设备ID", value: device.deviceId)
                InfoRow(label: "名称", value: device.name)
                InfoRow(label: "型号", value: device.model)
                InfoRow(label: "状态", value: device.status.displayText)
            }

            // 操作section
            Section("操作") {
                // 导航到直播页面
                NavigationLink("查看直播") {
                    LiveVideoView(deviceId: device.deviceId)
                }

                // 导航到回放页面
                NavigationLink("查看回放") {
                    PlaybackView(deviceId: device.deviceId)
                }

                // 导航到对讲页面
                NavigationLink("语音对讲") {
                    IntercomView(deviceId: device.deviceId)
                }
            }
        }
        .navigationBar(
            title: device.name,
            displayMode: .inline,
            trackingParameters: [
                "deviceId": device.deviceId,
                "deviceName": device.name,
                "deviceStatus": device.status.displayText,
                "from": "device_list"
            ]
        )
    }
}

// MARK: - 可复用组件

/// 错误提示视图
///
/// 用于显示错误信息和重试操作
/// 包括错误图标、错误消息和重试按钮
struct ErrorView: View {

    // MARK: - 属性

    /// 错误消息文本
    let message: String

    /// 重试操作闭包
    let retryAction: () -> Void

    // MARK: - 视图布局

    /// 构建错误提示视图
    ///
    /// 垂直居中显示错误图标、消息和重试按钮
    /// - Returns: 返回错误提示视图
    var body: some View {
        VStack(spacing: 16) {
            // 错误图标
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            // 错误消息
            Text(message)
                .foregroundColor(.secondary)

            // 重试按钮
            Button("重试", action: retryAction)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

/// 空状态视图
///
/// 用于显示列表为空时的提示信息
/// 包括自定义图标、提示消息和操作按钮
struct EmptyView: View {

    // MARK: - 属性

    /// 显示的图标名称（SF Symbol）
    let icon: String

    /// 提示消息文本
    let message: String

    /// 操作按钮标题
    let actionTitle: String

    /// 操作按钮点击闭包
    let action: () -> Void

    // MARK: - 视图布局

    /// 构建空状态视图
    ///
    /// 垂直居中显示图标、消息和操作按钮
    /// - Returns: 返回空状态视图
    var body: some View {
        VStack(spacing: 16) {
            // 空状态图标
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.gray)

            // 提示消息
            Text(message)
                .foregroundColor(.secondary)

            // 操作按钮
            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

/// 信息行视图
///
/// 用于展示键值对信息
/// 左侧显示标签，右侧显示值
struct InfoRow: View {

    // MARK: - 属性

    /// 信息标签
    let label: String

    /// 信息值
    let value: String

    // MARK: - 视图布局

    /// 构建信息行视图
    ///
    /// 使用 HStack 横向布局标签和值
    /// - Returns: 返回信息行视图
    var body: some View {
        HStack {
            // 左侧标签
            Text(label)
            Spacer()
            // 右侧值
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 预览

/// SwiftUI 预览提供者
///
/// 用于在 Xcode 中实时预览 DeviceListView 的显示效果
#Preview {
    DeviceListView()
}
