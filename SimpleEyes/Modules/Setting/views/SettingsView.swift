//
//  SettingsView.swift
//  SimpleEyes
//
//  设置页面 - MVVM 架构
//  提供应用配置管理功能，包括服务器配置、服务器发现等
//

import SwiftUI
import Combine

/// 设置页面主视图
///
/// 使用 MVVM 架构模式，通过 SettingsViewModel 管理配置数据
/// 功能包括：
/// - API 服务器地址配置
/// - WebSocket 服务器地址配置
/// - 局域网服务器自动发现
/// - 配置保存和恢复默认
/// - 应用版本信息展示
struct SettingsView: View {

    // MARK: - 视图模型

    /// 设置视图模型
    ///
    /// 使用 @StateObject 确保视图生命周期内的单一实例
    /// 负责配置数据的加载、保存和服务器发现功能
    @StateObject private var viewModel = SettingsViewModel()

    // MARK: - 视图布局

    /// 构建设置页面视图层级
    ///
    /// 使用 Form 组织各个配置分组
    /// - Returns: 返回设置页面视图
    var body: some View {
        NavigationView {
            Form {
                ServerConfigSection(viewModel: viewModel)
                ServerDiscoverySection(viewModel: viewModel)
                ActionSection(viewModel: viewModel)
                DefaultConfigSection()
                AboutSection()
            }
            .navigationBar(
                title: "设置",
                trackingParameters: [
                    "apiServerURL": viewModel.apiServerURL,
                    "wsServerURL": viewModel.wsServerURL,
                    "from": "main_tab"
                ]
            )
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
            .onChange(of: viewModel.showingServerPicker) { showing in
                if showing {
                    // 在 View 层调用 UI 组件
                    WindowOverlayManager.shared.showDialog(
                        maskConfig: MaskConfig(onMaskTap: nil)
                    ) {
                        ServerPickerView(viewModel: viewModel)
                            .frame(width: min(UIScreen.main.bounds.width - 40, 500))
                            .frame(height: min(UIScreen.main.bounds.height * 0.7, 600))
                    }
                } else {
                    // 关闭弹框
                    WindowOverlayManager.shared.hide()
                }
            }
        }
    }
}

// MARK: - 服务器配置区块

/// 服务器配置区块视图
///
/// 提供 API 和 WebSocket 服务器地址的配置界面
/// 包含：
/// - API 服务器地址输入框
/// - WebSocket 服务器地址输入框
/// - 配置说明文本
struct ServerConfigSection: View {

    // MARK: - 属性

    /// 设置视图模型（观察者模式）
    @ObservedObject var viewModel: SettingsViewModel

    // MARK: - 视图布局

    /// 构建服务器配置区块
    ///
    /// - Returns: 返回配置输入表单
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

/// 服务器发现区块视图
///
/// 提供局域网服务器自动发现功能
/// 包含：
/// - 扫描按钮（带进度指示器）
/// - 已选服务器信息展示
/// - 扫描进度和状态提示
struct ServerDiscoverySection: View {

    // MARK: - 属性

    /// 设置视图模型（观察者模式）
    @ObservedObject var viewModel: SettingsViewModel

    // MARK: - 视图布局

    /// 构建服务器发现区块
    ///
    /// - Returns: 返回服务器发现界面
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

            // 显示已发现的服务器列表
            if !viewModel.discoveryService.discoveredServers.isEmpty {
                ForEach(viewModel.discoveryService.discoveredServers) { server in
                    Button(action: {
                        viewModel.selectServer(server)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(server.name)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("\(server.host):\(server.port)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if viewModel.selectedServer?.id == server.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
        } header: {
            Text("服务器发现")
        } footer: {
            if viewModel.discoveryService.isScanning {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("正在扫描局域网...")
                        Spacer()
                        if !viewModel.discoveryService.discoveredServers.isEmpty {
                            Text("已发现 \(viewModel.discoveryService.discoveredServers.count) 个")
                                .foregroundColor(.green)
                        }
                    }
                    ProgressView(value: viewModel.discoveryService.scanProgress)
                        .progressViewStyle(.linear)
                }
                .padding(.vertical, 4)
            } else if !viewModel.discoveryService.discoveredServers.isEmpty {
                Text("扫描完成，发现 \(viewModel.discoveryService.discoveredServers.count) 个服务器")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text("点击扫描按钮查找局域网内的信令服务器")
                    .font(.caption)
            }
        }
    }
}

/// 操作区块视图
///
/// 提供配置保存和恢复默认操作
/// 包含：
/// - 保存配置按钮
/// - 恢复默认按钮
struct ActionSection: View {

    // MARK: - 属性

    /// 设置视图模型（观察者模式）
    @ObservedObject var viewModel: SettingsViewModel

    // MARK: - 视图布局

    /// 构建操作区块
    ///
    /// - Returns: 返回操作按钮组
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

/// 默认配置区块视图
///
/// 显示应用的默认服务器配置信息
/// 作为参考，帮助用户了解默认值
struct DefaultConfigSection: View {

    // MARK: - 视图布局

    /// 构建默认配置展示区块
    ///
    /// - Returns: 返回默认配置信息列表
    var body: some View {
        Section {
            InfoRow(label: "API 默认地址", value: APIConfig.baseURL)
            InfoRow(label: "WS 默认地址", value: APIConfig.wsURL)
        } header: {
            Text("默认配置")
        }
    }
}

/// 关于区块视图
///
/// 显示应用的版本信息
/// 包含：
/// - 应用版本号
/// - 构建版本号
struct AboutSection: View {

    // MARK: - 视图布局

    /// 构建关于区块
    ///
    /// - Returns: 返回版本信息列表
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



// MARK: - 预览

/// SwiftUI 预览提供者
///
/// 用于在 Xcode 中实时预览 SettingsView 的显示效果
#Preview {
    SettingsView()
}
