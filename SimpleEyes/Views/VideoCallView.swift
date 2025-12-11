import SwiftUI
import WebRTC

struct VideoCallView: View {
    @StateObject private var viewModel = VideoCallViewModel()
    @State private var hasLoaded = false

    var body: some View {
        ZStack {
            // 根据通话状态切换背景色
            if viewModel.isInCall {
                // 通话中 - 黑色背景
                Color.black.ignoresSafeArea()
                // 通话中界面
                CallActiveView(viewModel: viewModel)
            } else {
                // 空闲时 - 白色背景
                Color.white.ignoresSafeArea()
                // 空闲界面（设备选择）
                CallIdleView(viewModel: viewModel, hasLoaded: $hasLoaded)
            }
        }
        .navigationTitle("视频通话")
        .navigationBarTitleDisplayMode(.inline)
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
    }
}

// MARK: - Call Idle View (设备选择)

struct CallIdleView: View {
    @ObservedObject var viewModel: VideoCallViewModel
    @Binding var hasLoaded: Bool

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
                viewModel.loadOnlineDevices()
            }
        }
    }
}

// MARK: - Signaling Connection Section

struct SignalingConnectionSection: View {
    @ObservedObject var viewModel: VideoCallViewModel
    @State private var editingDeviceId: String = ""
    @State private var isEditingDeviceId: Bool = false

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

// MARK: - Device Selection Section

struct DeviceSelectionSection: View {
    @ObservedObject var viewModel: VideoCallViewModel

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

// MARK: - Call Active View (通话中)

struct CallActiveView: View {
    @ObservedObject var viewModel: VideoCallViewModel

    var body: some View {
        ZStack {
            // 远程视频（全屏）
            if let remoteTrack = viewModel.remoteVideoTrack {
                WebRTCVideoView(videoTrack: remoteTrack)
                    .ignoresSafeArea()
            } else {
                // 等待远程视频
                VStack {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                    Text(viewModel.callState.displayText)
                        .foregroundColor(.white)
                        .padding(.top)
                }
            }

            // 本地视频（画中画）
            VStack {
                HStack {
                    Spacer()
                    if let localTrack = viewModel.localVideoTrack {
                        WebRTCVideoView(videoTrack: localTrack)
                            .frame(width: 120, height: 160)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(radius: 10)
                            .padding()
                    }
                }
                Spacer()
            }

            // 控制按钮
            VStack {
                Spacer()

                // 状态信息
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                    Text(viewModel.callState.displayText)
                        .foregroundColor(.white)
                        .font(.subheadline)
                }
                .padding(12)
                .background(Color.black.opacity(0.6))
                .cornerRadius(20)
                .padding(.bottom, 8)

                // 挂断按钮
                Button(action: {
                    viewModel.endCall()
                }) {
                    Image(systemName: "phone.down.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(Color.red)
                        .clipShape(Circle())
                        .shadow(radius: 10)
                }
                .padding(.bottom, 40)
            }
        }
    }

    private var statusColor: Color {
        switch viewModel.callState {
        case .idle, .disconnected:
            return .gray
        case .connecting, .ringing:
            return .orange
        case .connected:
            return .green
        case .error:
            return .red
        }
    }
}

#Preview {
    NavigationView {
        VideoCallView()
    }
}
