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
                ActionSection(viewModel: viewModel)
                DefaultConfigSection()
                AboutSection()
            }
            .navigationTitle("设置")
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

#Preview {
    SettingsView()
}
