import SwiftUI
import WebRTC
import AVKit

/// 活动视频通话页面
struct ActiveCallView: View {
    @ObservedObject var viewModel: VideoCallViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isPiPMode {
                // 画中画模式：只显示远程视频
                PiPModeView(viewModel: viewModel)
            } else {
                // 正常模式：显示双方视频
                NormalModeView(viewModel: viewModel)
            }

            // 顶部状态栏
            VStack {
                TopStatusBar(viewModel: viewModel, dismiss: dismiss)
                Spacer()
            }

            // 底部控制栏
            VStack {
                Spacer()
                ControlBar(viewModel: viewModel, onHangup: {
                    viewModel.endCall()
                    dismiss()
                })
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .onDisappear {
            // 如果页面消失且还在通话中，结束通话
            if viewModel.isInCall {
                viewModel.endCall()
            }
        }
    }
}

// MARK: - Normal Mode View

/// 正常模式视图（显示双方视频）
struct NormalModeView: View {
    @ObservedObject var viewModel: VideoCallViewModel

    var body: some View {
        ZStack {
            // 大屏视频（背景）
            if viewModel.isLocalVideoLarge {
                // 本地视频大屏
                if let localTrack = viewModel.localVideoTrack {
                    WebRTCVideoView(videoTrack: localTrack)
                        .ignoresSafeArea()
                } else {
                    PlaceholderView(text: "本地视频加载中...")
                }
            } else {
                // 远程视频大屏
                if let remoteTrack = viewModel.remoteVideoTrack {
                    WebRTCVideoView(videoTrack: remoteTrack)
                        .ignoresSafeArea()
                } else {
                    PlaceholderView(text: viewModel.callState.displayText)
                }
            }

            // 小屏视频（画中画位置）
            VStack {
                HStack {
                    Spacer()
                    SmallVideoView(
                        viewModel: viewModel,
                        isLocal: !viewModel.isLocalVideoLarge
                    )
                    .padding()
                }
                Spacer()
            }
        }
    }
}

// MARK: - PiP Mode View

/// 画中画模式视图（只显示远程视频）
struct PiPModeView: View {
    @ObservedObject var viewModel: VideoCallViewModel

    var body: some View {
        if let remoteTrack = viewModel.remoteVideoTrack {
            WebRTCVideoView(videoTrack: remoteTrack)
                .ignoresSafeArea()
        } else {
            PlaceholderView(text: "等待远程视频...")
        }
    }
}

// MARK: - Small Video View

/// 小屏视频视图
struct SmallVideoView: View {
    @ObservedObject var viewModel: VideoCallViewModel
    let isLocal: Bool

    var body: some View {
        Group {
            if isLocal {
                // 显示本地视频
                if let localTrack = viewModel.localVideoTrack {
                    WebRTCVideoView(videoTrack: localTrack)
                } else {
                    PlaceholderView(text: "本地视频", small: true)
                }
            } else {
                // 显示远程视频
                if let remoteTrack = viewModel.remoteVideoTrack {
                    WebRTCVideoView(videoTrack: remoteTrack)
                } else {
                    PlaceholderView(text: "远程视频", small: true)
                }
            }
        }
        .frame(width: 120, height: 160)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 2)
        )
        .shadow(radius: 10)
        .onTapGesture {
            // 点击切换大小屏
            viewModel.toggleVideoSize()
        }
    }
}

// MARK: - Top Status Bar

/// 顶部状态栏
struct TopStatusBar: View {
    @ObservedObject var viewModel: VideoCallViewModel
    let dismiss: DismissAction

    var body: some View {
        HStack {
            // 返回按钮
            Button(action: {
                viewModel.endCall()
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }

            Spacer()

            // 状态指示器
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                Text(viewModel.callState.displayText)
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(20)

            Spacer()

            // 占位，保持居中
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal)
        .padding(.top, 50)
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

// MARK: - Control Bar

/// 底部控制栏
struct ControlBar: View {
    @ObservedObject var viewModel: VideoCallViewModel
    let onHangup: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // 主要控制按钮
            HStack(spacing: 40) {
                // 静音按钮
                ControlButton(
                    icon: viewModel.isAudioEnabled ? "mic.fill" : "mic.slash.fill",
                    isActive: !viewModel.isAudioEnabled,
                    action: { viewModel.toggleAudio() }
                )

                // 挂断按钮
                Button(action: onHangup) {
                    Image(systemName: "phone.down.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(Color.red)
                        .clipShape(Circle())
                        .shadow(color: .red.opacity(0.5), radius: 10, x: 0, y: 5)
                }

                // 关闭视频按钮
                ControlButton(
                    icon: viewModel.isVideoEnabled ? "video.fill" : "video.slash.fill",
                    isActive: !viewModel.isVideoEnabled,
                    action: { viewModel.toggleVideo() }
                )
            }

            // 次要控制按钮
            HStack(spacing: 40) {
                // 切换大小屏按钮
                ControlButton(
                    icon: "arrow.up.left.and.arrow.down.right",
                    label: "切换",
                    size: .small,
                    action: { viewModel.toggleVideoSize() }
                )

                // 画中画按钮
                ControlButton(
                    icon: "pip",
                    label: "画中画",
                    isActive: viewModel.isPiPMode,
                    size: .small,
                    action: { viewModel.togglePiPMode() }
                )
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
        .background(
            Color.black.opacity(0.6)
                .blur(radius: 10)
        )
        .cornerRadius(30)
    }
}

// MARK: - Control Button

/// 控制按钮
struct ControlButton: View {
    let icon: String
    var label: String?
    var isActive: Bool = false
    var size: Size = .large
    let action: () -> Void

    enum Size {
        case large, small

        var dimension: CGFloat {
            switch self {
            case .large: return 60
            case .small: return 50
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .large: return 28
            case .small: return 22
            }
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: size.iconSize))
                    .foregroundColor(.white)
                    .frame(width: size.dimension, height: size.dimension)
                    .background(isActive ? Color.white.opacity(0.3) : Color.gray.opacity(0.3))
                    .clipShape(Circle())
            }

            if let label = label {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

// MARK: - Placeholder View

/// 占位视图
struct PlaceholderView: View {
    let text: String
    var small: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)

            VStack(spacing: 12) {
                if !small {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.5)
                }

                Text(text)
                    .foregroundColor(.white)
                    .font(small ? .caption : .body)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

#Preview {
    NavigationView {
        ActiveCallView(viewModel: VideoCallViewModel())
    }
}
