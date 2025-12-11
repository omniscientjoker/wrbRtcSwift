//
//  IntercomView.swift
//  SimpleEyes
//
//  语音对讲页面 - MVVM
//

import SwiftUI

struct IntercomView: View {
    @StateObject private var viewModel: IntercomViewModel

    init(deviceId: String = "") {
        _viewModel = StateObject(wrappedValue: IntercomViewModel(deviceId: deviceId))
    }

    var body: some View {
        VStack(spacing: 24) {
            // 设备选择（仅在空闲状态显示）
            if case .idle = viewModel.intercomStatus {
                DeviceSelectionView(viewModel: viewModel)
            }

            // 状态显示
            IntercomStatusView(viewModel: viewModel)

            // 控制按钮
            IntercomControlButtons(viewModel: viewModel)

            // 提示信息
            IntercomTipsView()

            Spacer()
        }
        .padding(.top)
        .navigationTitle("语音对讲")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subviews

struct DeviceSelectionView: View {
    @ObservedObject var viewModel: IntercomViewModel
    @State private var hasLoaded = false

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
                        HStack {
                            Text(device.name)
                            Spacer()
                            Text("(\(device.deviceId))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(device as OnlineDevice?)
                    }
                }
                .pickerStyle(.menu)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)

                // 显示已选设备信息
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
        }
        .padding(.horizontal)
        .onAppear {
            // 首次进入时自动加载设备列表
            if !hasLoaded {
                hasLoaded = true
                viewModel.loadOnlineDevices()
            }
        }
    }
}

struct IntercomStatusView: View {
    @ObservedObject var viewModel: IntercomViewModel

    var body: some View {
        VStack(spacing: 16) {
            // 麦克风图标
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 150, height: 150)

                Circle()
                    .fill(statusColor.opacity(0.4))
                    .frame(width: 120, height: 120)

                Image(systemName: viewModel.statusIcon)
                    .font(.system(size: 60))
                    .foregroundColor(statusColor)
            }
            .scaleEffect(viewModel.isSpeaking ? 1.1 : 1.0)

            Text(viewModel.intercomStatus.displayText)
                .font(.title2)
                .fontWeight(.bold)

            // 只显示对讲相关的错误，不显示设备列表加载错误
            if let error = viewModel.errorMessage,
               viewModel.intercomStatus != .idle {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    private var statusColor: Color {
        switch viewModel.intercomStatus {
        case .idle:
            return .gray
        case .connecting:
            return .orange
        case .connected, .speaking:
            return .green
        case .error:
            return .red
        }
    }
}

struct IntercomControlButtons: View {
    @ObservedObject var viewModel: IntercomViewModel

    var body: some View {
        VStack(spacing: 12) {
            switch viewModel.intercomStatus {
            case .idle:
                Button(action: viewModel.startIntercom) {
                    Label("开始对讲", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(!viewModel.canStart)
                .padding(.horizontal)

            case .connecting:
                HStack {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("正在连接...")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.2))
                .cornerRadius(10)
                .padding(.horizontal)

            case .connected, .speaking:
                Button(action: viewModel.stopIntercom) {
                    Label("停止对讲", systemImage: "mic.slash.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.horizontal)

            case .error:
                VStack(spacing: 12) {
                    Button(action: viewModel.stopIntercom) {
                        Label("关闭", systemImage: "xmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button(action: viewModel.startIntercom) {
                        Label("重试", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canStart)
                }
                .padding(.horizontal)
            }
        }
    }
}

struct IntercomTipsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("需要麦克风和扬声器权限", systemImage: "info.circle")
                .font(.caption)
                .foregroundColor(.secondary)

            Label("对讲时请靠近设备说话", systemImage: "info.circle")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// 快速对讲视图（从主页进入）
struct QuickIntercomView: View {
    var body: some View {
        NavigationView {
            IntercomInputNavigator()
                .navigationTitle("语音对讲")
        }
    }
}

struct IntercomInputNavigator: View {
    @StateObject private var viewModel = IntercomViewModel()
    @State private var hasLoaded = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("语音对讲")
                .font(.title2)
                .fontWeight(.bold)

            // 设备列表选择区域
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
                            HStack {
                                Text(device.name)
                                Spacer()
                                Text("(\(device.deviceId))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(device as OnlineDevice?)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                    // 显示已选设备信息
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
            }
            .padding(.horizontal)

            // 开始对讲按钮
            if let selectedDevice = viewModel.selectedDevice {
                NavigationLink(destination: IntercomView(deviceId: selectedDevice.deviceId)) {
                    Label("开始对讲", systemImage: "mic.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            } else {
                Button(action: {}) {
                    Label("开始对讲", systemImage: "mic.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(true)
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            // 首次进入时自动加载设备列表
            if !hasLoaded {
                hasLoaded = true
                viewModel.loadOnlineDevices()
            }
        }
    }
}

#Preview {
    IntercomView(deviceId: "device-001")
}
