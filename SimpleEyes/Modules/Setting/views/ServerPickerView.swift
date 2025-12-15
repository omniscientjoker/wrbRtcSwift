//
//  ServerPickerView.swift
//  SimpleEyes
//
//  Created by 姜淼 on 2025/12/15.
//

import SwiftUI
import Lottie

// MARK: - 服务器选择器视图

/// 服务器选择器视图
///
/// 以模态方式展示服务器发现结果，允许用户选择服务器
/// 功能包括：
/// - 显示扫描进度
/// - 展示发现的服务器列表
/// - 服务器选择和确认
/// - 重新扫描功能
struct ServerPickerView: View {

    // MARK: - 属性

    /// 设置视图模型（观察者模式）
    @ObservedObject var viewModel: SettingsViewModel

    // MARK: - 视图布局

    /// 构建服务器选择器视图
    ///
    /// 根据扫描状态显示不同内容：
    /// - 扫描中：显示进度指示器
    /// - 未发现：显示提示信息
    /// - 已发现：显示服务器列表供选择
    /// - Returns: 返回服务器选择器视图
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Button(action: {
                    viewModel.cancelServerSelection()
                }) {
                    Text("取消")
                        .font(.body)
                        .foregroundColor(.red)
                }

                Spacer()

                Text("选择服务器")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                // 右侧控制按钮
                Group {
                    if viewModel.discoveryService.isScanning {
                        if viewModel.discoveryService.isPaused {
                            Button("继续") {
                                viewModel.resumeServerDiscovery()
                            }
                            .font(.body)
                        } else {
                            Button("暂停") {
                                viewModel.pauseServerDiscovery()
                            }
                            .font(.body)
                        }
                    } else if !viewModel.discoveryService.discoveredServers.isEmpty {
                        Button("重新") {
                            viewModel.startServerDiscovery()
                        }
                        .font(.body)
                    } else {
                        Button("完成") {
                            viewModel.cancelServerSelection()
                        }
                        .font(.body)
                    }
                }
                .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemBackground))

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    // 扫描进度提示
                    if viewModel.discoveryService.isScanning || viewModel.discoveryService.isPaused {
                        VStack(spacing: 12) {
                            if !viewModel.discoveryService.isPaused {
                                LottieView(animationName: "scanning")
                                    .frame(width: 40, height: 40)
                                
                            } else {
                                LottieView(animationName: "paused")
                                    .frame(width: 40, height: 40)
                                
                            }
                            Spacer()
                            if !viewModel.discoveryService.discoveredServers.isEmpty {
                                Text("已发现 \(viewModel.discoveryService.discoveredServers.count) 个服务器")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .cornerRadius(12)
                    }

                    // 已发现的服务器列表
                    if !viewModel.discoveryService.discoveredServers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("发现 \(viewModel.discoveryService.discoveredServers.count) 个服务器")
                                .font(.headline)
                                .padding(.horizontal, 4)

                            ForEach(viewModel.discoveryService.discoveredServers) { server in
                                Button(action: {
                                    viewModel.selectServer(server)
                                }) {
                                    HStack(spacing: 12) {
                                        // 服务器图标
                                        Image(systemName: "server.rack")
                                            .font(.system(size: 30))
                                            .foregroundColor(.blue)
                                            .frame(width: 30)

                                        // 服务器详细信息
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(server.name)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                                .lineLimit(2)
                                                .truncationMode(.middle)
                                            HStack(spacing: 4) {
                                                Image(systemName: "network")
                                                    .font(.caption2)
                                                Text(server.host)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                Text(": \(server.port)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }

                                            Divider()

                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "link")
                                                        .font(.caption2)
                                                        .foregroundColor(.blue)
                                                    Text("API:")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                    Text(server.apiURL)
                                                        .font(.caption2)
                                                        .foregroundColor(.blue)
                                                        .lineLimit(1)
                                                }

                                                HStack(spacing: 4) {
                                                    Image(systemName: "cable.connector")
                                                        .font(.caption2)
                                                        .foregroundColor(.green)
                                                    Text("WS:")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                    Text(server.wsURL)
                                                        .font(.caption2)
                                                        .foregroundColor(.green)
                                                        .lineLimit(1)
                                                }
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(viewModel.selectedServer?.id == server.id ?
                                                  Color.green.opacity(0.1) :
                                                  Color(UIColor.secondarySystemBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(viewModel.selectedServer?.id == server.id ?
                                                   Color.green : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else if !viewModel.discoveryService.isScanning && !viewModel.discoveryService.isPaused {
                        // 扫描完成但未发现服务器
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
                }
                .padding()
            }
        }
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}
