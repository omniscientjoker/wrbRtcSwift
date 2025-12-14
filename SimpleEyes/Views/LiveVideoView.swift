//
//  LiveVideoView.swift
//  SimpleEyes
//
//  视频直播页面 - MVVM
//

import SwiftUI
import AVFoundation
import AVKit

struct LiveVideoView: View {
    @StateObject private var viewModel: LiveVideoViewModel

    init(deviceId: String = "") {
        _viewModel = StateObject(wrappedValue: LiveVideoViewModel(deviceId: deviceId))
    }

    var body: some View {
        VStack(spacing: 20) {
            if let url = viewModel.streamUrl {
                // 视频播放区域
                VideoPlayerPlaceholder(url: url, onStop: viewModel.stopStream)
            } else {
                // 输入区域
                LiveInputSection(viewModel: viewModel)
            }

            Spacer()
        }
        .navigationTitle("视频直播")
        .navigationBarTitleDisplayMode(.inline)
        .basePage(
            title: "实时视频",
            parameters: [
                "deviceId": "",
                "from": "main_tab"
            ]
        )
    }
}

// MARK: - Subviews

struct LiveInputSection: View {
    @ObservedObject var viewModel: LiveVideoViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("实时视频直播")
                .font(.title2)
                .fontWeight(.bold)

            // 设备ID输入框
            VStack(alignment: .leading, spacing: 8) {
                Text("设备ID")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("输入设备ID", text: $viewModel.deviceIdInput)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            // 开始直播按钮
            Button(action: viewModel.startLiveStream) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Label("开始直播", systemImage: "play.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canStartLive)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
        .padding()
    }
}

struct VideoPlayerPlaceholder: View {
    let url: String
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 使用实际的视频播放器
            VideoPlayerView(url: url)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()

            // 停止按钮
            Button(action: onStop) {
                Label("停止播放", systemImage: "stop.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding(.horizontal)
        }
    }
}

// 快速直播视图（从主页进入）
struct QuickLiveView: View {
    var body: some View {
        NavigationView {
            LiveInputNavigator()
                .navigationTitle("视频直播")
        }
    }
}

struct LiveInputNavigator: View {
    @State private var deviceIdInput: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("快速直播")
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

            NavigationLink(destination: LiveVideoView(deviceId: deviceIdInput)) {
                Label("开始观看", systemImage: "play.circle.fill")
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

// VideoPlayerView 已经在 Services/VideoService/VideoPlayerView.swift 中定义

#Preview {
    LiveVideoView(deviceId: "device-001")
}
