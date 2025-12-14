//
//  DeviceListView.swift
//  SimpleEyes
//
//  设备列表页面 - MVVM
//

import SwiftUI

struct DeviceListView: View {
    @StateObject private var viewModel = DeviceListViewModel()

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("加载设备列表...")
                        .padding()
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error, retryAction: viewModel.loadDevices)
                } else if viewModel.devices.isEmpty {
                    EmptyView(
                        icon: "video.slash",
                        message: "暂无设备",
                        actionTitle: "刷新",
                        action: viewModel.loadDevices
                    )
                } else {
                    List(viewModel.devices) { device in
                        NavigationLink(destination: DeviceDetailView(device: device)) {
                            DeviceRowView(device: device)
                        }
                    }
                    .refreshable {
                        viewModel.refresh()
                    }
                }
            }
            .navigationTitle("设备列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: viewModel.refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                if viewModel.devices.isEmpty {
                    viewModel.loadDevices()
                }
            }
            .basePage(
                title: "设备清单",
                parameters: [
                    "deviceId": "",
                    "from": "main_tab"
                ]
            )
        }
    }
}

struct DeviceRowView: View {
    let device: Device

    var body: some View {
        HStack {
            // 设备图标
            Image(systemName: "video.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(device.status == .online ? .green : .gray)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)

                Text(device.model)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Circle()
                        .fill(device.status == .online ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)

                    Text(device.status.displayText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct DeviceDetailView: View {
    let device: Device

    var body: some View {
        List {
            Section("设备信息") {
                InfoRow(label: "设备ID", value: device.deviceId)
                InfoRow(label: "名称", value: device.name)
                InfoRow(label: "型号", value: device.model)
                InfoRow(label: "状态", value: device.status.displayText)
            }

            Section("操作") {
                NavigationLink("查看直播") {
                    LiveVideoView(deviceId: device.deviceId)
                }

                NavigationLink("查看回放") {
                    PlaybackView(deviceId: device.deviceId)
                }

                NavigationLink("语音对讲") {
                    IntercomView(deviceId: device.deviceId)
                }
            }
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Reusable Components

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            Text(message)
                .foregroundColor(.secondary)
            Button("重试", action: retryAction)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

struct EmptyView: View {
    let icon: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text(message)
                .foregroundColor(.secondary)
            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    DeviceListView()
}
