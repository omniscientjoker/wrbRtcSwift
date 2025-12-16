//
//  VideoCallView.swift
//  SimpleEyes
//
//  视频通话页面 - MVVM 架构
//  提供视频通话的初始化、设备选择和通话建立功能
//

import SwiftUI
import WebRTC

/// 视频通话主视图
///
/// 使用 MVVM 架构模式，通过 VideoCallViewModel 管理通话状态
/// 功能包括：
/// - 信令服务器连接管理
/// - 设备ID配置和编辑
/// - 在线设备列表加载和选择
/// - 呼叫发起和接听
/// - 通话状态自动跳转
/// - 来电提示和响应
struct VideoCallView: View {

    // MARK: - 状态属性

    /// 视频通话视图模型
    ///
    /// 使用 @StateObject 确保视图生命周期内的单一实例
    /// 负责 WebRTC 连接、信令处理和通话控制
    @StateObject private var viewModel = VideoCallViewModel()

    /// 是否已加载设备列表
    ///
    /// 防止重复加载设备列表
    @State private var hasLoaded = false

    /// 是否导航到活动通话页面
    ///
    /// 根据通话状态自动控制页面跳转
    @State private var navigateToActiveCall = false

    /// 视图是否已激活
    ///
    /// 延迟加载机制，避免 TabView 切换时的性能问题
    @State private var isViewActive = false

    // MARK: - 视图布局

    /// 构建视频通话视图层级
    ///
    /// 包含空闲界面（设备选择）和活动通话界面的切换
    /// - Returns: 返回视频通话视图
    var body: some View {
        ZStack {
            // 空闲界面（设备选择）
            if isViewActive {
                CallIdleView(viewModel: viewModel, hasLoaded: $hasLoaded)
            } else {
                // 显示加载指示器
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
            }
        }
        .fullScreenCover(isPresented: $navigateToActiveCall) {
            ActiveCallView(viewModel: viewModel)
        }
        .onAppear {
            // 延迟激活视图，避免立即执行耗时操作
            if !isViewActive {
                Task {
                    // 短暂延迟，让 TabView 切换动画完成
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                    isViewActive = true
                }
            }
        }
        .onChange(of: viewModel.callState) { newState in
            // 当进入通话状态时，自动跳转到通话页面
            switch newState {
            case .connecting, .ringing, .connected:
                navigateToActiveCall = true
            case .idle, .disconnected, .error:
                navigateToActiveCall = false
            }
        }
        .alert("来电", isPresented: $viewModel.showIncomingCallAlert) {
            Button("拒绝", role: .cancel) {
                viewModel.rejectCall()
            }
            Button("接听") {
                viewModel.acceptCall()
            }
        } message: {
            if let from = viewModel.incomingCallFrom {
                Text("来自设备: \(from)")
            }
        }
        .navigationBar(
            title: "视频通话",
            displayMode: .inline,
            trackingParameters: [
                "deviceId": "",
                "from": "main_tab"
            ]
        )
    }
}


// MARK: - 空闲状态视图

/// 通话空闲视图（设备选择界面）
///
/// 显示信令连接控制和设备选择界面
/// 包含：
/// - 信令服务器连接状态
/// - 设备ID配置
/// - 在线设备列表
/// - 发起通话按钮
struct CallIdleView: View {

    // MARK: - 属性

    /// 视频通话视图模型（观察者模式）
    @ObservedObject var viewModel: VideoCallViewModel

    /// 是否已加载设备列表（绑定）
    @Binding var hasLoaded: Bool

    // MARK: - 视图布局

    /// 构建空闲状态视图
    ///
    /// - Returns: 返回设备选择界面
    var body: some View {
        VStack(spacing: 20) {
            // 信令连接控制区域
            SignalingConnectionSection(viewModel: viewModel)
            Divider()
            // 设备选择区域
            DeviceSelectionSection(viewModel: viewModel)

            Spacer()
        }
        .padding()
        .onAppear {
            if !hasLoaded {
                hasLoaded = true
                // 延迟加载设备列表，避免阻塞 UI
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
                    await MainActor.run {
                        viewModel.loadOnlineDevices()
                    }
                }
            }
        }
    }
}


// MARK: - 信令连接区块

/// 信令连接配置区块视图
///
/// 提供信令服务器连接管理和设备ID配置
/// 包含：
/// - 连接状态指示器
/// - 设备ID显示和编辑
/// - 连接/断开按钮
/// - 错误信息提示
struct SignalingConnectionSection: View {

    // MARK: - 属性

    /// 视频通话视图模型（观察者模式）
    @ObservedObject var viewModel: VideoCallViewModel

    /// 编辑中的设备ID
    @State private var editingDeviceId: String = ""

    /// 是否正在编辑设备ID
    @State private var isEditingDeviceId: Bool = false

    // MARK: - 视图布局

    /// 构建信令连接区块
    ///
    /// - Returns: 返回信令连接配置界面
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和状态
            HStack {
                Text("信令服务器")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                // 连接状态指示器
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.signalingConnected ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    Text(viewModel.signalingConnected ? "已连接" : "未连接")
                        .font(.caption)
                        .foregroundColor(viewModel.signalingConnected ? .green : .gray)
                }
            }

            // 设备ID显示/编辑
            VStack(alignment: .leading, spacing: 8) {
                Text("设备ID")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    if isEditingDeviceId {
                        TextField("输入设备ID", text: $editingDeviceId)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                    } else {
                        Text(viewModel.localDeviceId)
                            .font(.system(.body, design: .monospaced))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    Button(action: {
                        if isEditingDeviceId {
                            // 保存
                            viewModel.updateDeviceId(editingDeviceId)
                            isEditingDeviceId = false
                        } else {
                            // 开始编辑
                            editingDeviceId = viewModel.localDeviceId
                            isEditingDeviceId = true
                        }
                    }) {
                        Image(systemName: isEditingDeviceId ? "checkmark.circle.fill" : "pencil.circle")
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                    .disabled(viewModel.signalingConnected || viewModel.isInCall)
                }
            }

            // 连接/断开按钮
            Button(action: {
                if viewModel.signalingConnected {
                    viewModel.disconnectFromSignalingServer()
                } else {
                    viewModel.connectToSignalingServer()
                }
            }) {
                HStack {
                    Image(systemName: viewModel.signalingConnected ? "link.circle.fill" : "link.circle")
                    Text(viewModel.signalingConnected ? "断开连接" : "连接服务器")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.signalingConnected ? .red : .blue)
            .disabled(viewModel.isInCall && viewModel.signalingConnected) // 通话中不允许断开

            // 错误提示
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
            }
        }
        .padding(.horizontal)
    }
}


// MARK: - 设备选择区块

/// 设备选择区块视图
///
/// 提供在线设备列表和选择功能
/// 包含：
/// - 设备列表刷新按钮
/// - 设备加载状态指示
/// - 设备选择器（Picker）
/// - 已选设备信息展示
/// - 开始通话按钮
struct DeviceSelectionSection: View {

    // MARK: - 属性

    /// 视频通话视图模型（观察者模式）
    @ObservedObject var viewModel: VideoCallViewModel

    // MARK: - 视图布局

    /// 构建设备选择区块
    ///
    /// 根据加载状态显示不同内容：
    /// - 加载中：显示进度指示器
    /// - 空列表：显示提示信息
    /// - 有设备：显示选择器和通话按钮
    /// - Returns: 返回设备选择界面
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("选择设备")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                // 刷新按钮
                Button(action: {
                    viewModel.loadOnlineDevices()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("刷新")
                    }
                    .font(.caption)
                }
                .disabled(viewModel.isLoadingDevices)
            }

            // 设备选择器
            if viewModel.isLoadingDevices {
                HStack {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("正在加载设备...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else if viewModel.onlineDevices.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.title2)
                        .foregroundColor(.orange)

                    if viewModel.errorMessage != nil {
                        Text("加载失败")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        Text("请检查服务器配置并确保服务器已启动")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("点击刷新按钮加载在线设备")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("请先在设置中配置 WebSocket 服务器地址")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
                Picker("选择设备", selection: $viewModel.selectedDevice) {
                    Text("请选择设备").tag(nil as OnlineDevice?)
                    ForEach(viewModel.onlineDevices) { device in
                        Text("\(device.name) (\(device.deviceId))")
                            .tag(device as OnlineDevice?)
                    }
                }
                .pickerStyle(.menu)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)

                // 显示已选设备
                if let selected = viewModel.selectedDevice {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("已选: \(selected.name)")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("设备ID: \(selected.deviceId)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                }
            }

            // 开始通话按钮
            Button(action: {
                viewModel.startCall()
            }) {
                Label("开始视频通话", systemImage: "video.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canStartCall)
        }
        .padding(.horizontal)
    }
}

// MARK: - 预览

/// SwiftUI 预览提供者
///
/// 用于在 Xcode 中实时预览 VideoCallView 的显示效果
#Preview {
    NavigationView {
        VideoCallView()
    }
}
