//
//  PlaybackView.swift
//  SimpleEyes
//
//  视频回放页面 - MVVM
//

import SwiftUI

struct PlaybackView: View {
    @StateObject private var viewModel: PlaybackViewModel

    init(deviceId: String = "") {
        _viewModel = StateObject(wrappedValue: PlaybackViewModel(deviceId: deviceId))
    }

    var body: some View {
        VStack(spacing: 16) {
            // 输入区域
            PlaybackInputSection(viewModel: viewModel)

            // 录像列表
            if let error = viewModel.errorMessage {
                ErrorView(message: error, retryAction: viewModel.loadRecordings)
            } else if viewModel.recordings.isEmpty && !viewModel.isLoading {
                EmptyView(
                    icon: "film",
                    message: "暂无录像",
                    actionTitle: "",
                    action: {}
                )
            } else {
                List(viewModel.recordings) { recording in
                    RecordingRowView(recording: recording) {
                        viewModel.playRecording(recording)
                    }
                }
                .listStyle(.plain)
            }

            Spacer()
        }
        .navigationTitle("视频回放")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subviews

struct PlaybackInputSection: View {
    @ObservedObject var viewModel: PlaybackViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 设备ID输入
            VStack(alignment: .leading, spacing: 8) {
                Text("设备ID")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("输入设备ID", text: $viewModel.deviceIdInput)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }

            // 日期选择
            VStack(alignment: .leading, spacing: 8) {
                Text("选择日期")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                DatePicker("", selection: $viewModel.selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }

            // 查询按钮
            Button(action: viewModel.loadRecordings) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Label("查询录像", systemImage: "magnifyingglass")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canQuery)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .basePage(
            title: "视频回放",
            parameters: [
                "deviceId": "",
                "from": "main_tab"
            ]
        )
    }
}

struct RecordingRowView: View {
    let recording: Recording
    let onPlay: () -> Void

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        HStack {
            Image(systemName: "film.fill")
                .font(.system(size: 30))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(timeFormatter.string(from: recording.startTime)) - \(timeFormatter.string(from: recording.endTime))")
                    .font(.headline)

                HStack {
                    Label(recording.formattedDuration, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label(recording.formattedSize, systemImage: "doc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: onPlay) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}

// 快速回放视图（从主页进入）
struct QuickPlaybackView: View {
    var body: some View {
        NavigationView {
            PlaybackInputNavigator()
                .navigationTitle("视频回放")
        }
    }
}

struct PlaybackInputNavigator: View {
    @State private var deviceIdInput: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "film.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            Text("视频回放")
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

            NavigationLink(destination: PlaybackView(deviceId: deviceIdInput)) {
                Label("查看回放", systemImage: "play.rectangle.fill")
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

#Preview {
    PlaybackView(deviceId: "device-001")
}
