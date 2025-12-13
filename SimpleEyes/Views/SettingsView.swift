//
//  SettingsView.swift
//  SimpleEyes
//
//  设置页面 - MVVM
//

import SwiftUI
import Combine

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationView {
            Form {
                ServerConfigSection(viewModel: viewModel)
                ServerDiscoverySection(viewModel: viewModel)
                ActionSection(viewModel: viewModel)
                DefaultConfigSection()
                AboutSection()
            }
            .navigationTitle("设置")
            .sheet(isPresented: $viewModel.showingServerPicker) {
                ServerPickerView(viewModel: viewModel)
            }
            .alert("保存成功", isPresented: $viewModel.showingSaveAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("服务器配置已保存")
            }
            .alert("恢复默认配置", isPresented: $viewModel.showingResetAlert) {
                Button("取消", role: .cancel) { }
                Button("确定", role: .destructive) {
                    viewModel.resetToDefaults()
                }
            } message: {
                Text("确定要恢复默认服务器配置吗？")
            }
        }
    }
}

// MARK: - Subviews

struct ServerConfigSection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("API 服务器地址")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("http://localhost:3000", text: $viewModel.apiServerURL)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }
            .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("WebSocket 服务器地址")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("ws://localhost:8080", text: $viewModel.wsServerURL)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }
            .padding(.vertical, 8)
        } header: {
            Text("服务器配置")
        } footer: {
            Text("修改后将在下次请求时生效")
                .font(.caption)
        }
    }
}

struct ServerDiscoverySection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Section {
            Button(action: viewModel.startServerDiscovery) {
                HStack {
                    Label("扫描局域网服务器", systemImage: "wifi.circle")
                    Spacer()
                    if viewModel.discoveryService.isScanning {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(viewModel.discoveryService.isScanning)

            if let selected = viewModel.selectedServer {
                VStack(alignment: .leading, spacing: 4) {
                    Text("已选服务器")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(selected.displayName)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("服务器发现")
        } footer: {
            if viewModel.discoveryService.isScanning {
                VStack(alignment: .leading, spacing: 4) {
                    Text("正在扫描局域网...")
                    ProgressView(value: viewModel.discoveryService.scanProgress)
                        .progressViewStyle(.linear)
                    Text("进度: \(Int(viewModel.discoveryService.scanProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                Text("点击扫描按钮查找局域网内的信令服务器")
                    .font(.caption)
            }
        }
    }
}

struct ActionSection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Section {
            Button(action: viewModel.saveSettings) {
                Label("保存配置", systemImage: "checkmark.circle")
            }
            .tint(.green)

            Button(action: viewModel.requestReset) {
                Label("恢复默认", systemImage: "arrow.counterclockwise")
            }
            .tint(.orange)
        } header: {
            Text("操作")
        }
    }
}

struct DefaultConfigSection: View {
    var body: some View {
        Section {
            InfoRow(label: "API 默认地址", value: APIConfig.baseURL)
            InfoRow(label: "WS 默认地址", value: APIConfig.wsURL)
        } header: {
            Text("默认配置")
        }
    }
}

struct AboutSection: View {
    var body: some View {
        Section {
            HStack {
                Text("应用版本")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("构建版本")
                Spacer()
                Text("1")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("关于")
        }
    }
}

// MARK: - Server Picker View

struct ServerPickerView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                if viewModel.discoveryService.isScanning {
                    Section {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("正在扫描局域网...")
                                .font(.headline)
                            ProgressView(value: viewModel.discoveryService.scanProgress)
                                .progressViewStyle(.linear)
                            Text("\(Int(viewModel.discoveryService.scanProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else if viewModel.discoveryService.discoveredServers.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            Text("未发现服务器")
                                .font(.headline)
                            Text("请确保服务器已启动并连接到同一局域网")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else {
                    Section {
                        ForEach(viewModel.discoveryService.discoveredServers) { server in
                            Button(action: {
                                viewModel.selectServer(server)
                            }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(server.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    HStack {
                                        Image(systemName: "network")
                                            .font(.caption)
                                        Text("\(server.host):\(server.port)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    HStack(spacing: 12) {
                                        Label(server.apiURL, systemImage: "link")
                                            .font(.caption2)
                                            .lineLimit(1)
                                        Label(server.wsURL, systemImage: "cable.connector")
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                    .foregroundColor(.blue)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        HStack {
                            Text("发现 \(viewModel.discoveryService.discoveredServers.count) 个服务器")
                            Spacer()
                            Button("重新扫描") {
                                viewModel.startServerDiscovery()
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("选择服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.discoveryService.isScanning {
                        Button("停止") {
                            viewModel.stopServerDiscovery()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        viewModel.stopServerDiscovery()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
