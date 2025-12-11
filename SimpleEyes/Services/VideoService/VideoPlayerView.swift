//
//  VideoPlayerView.swift
//  SimpleEyes
//
//  视频播放器 - SwiftUI + AVPlayer
//

import SwiftUI
import AVFoundation
import AVKit

/// HLS/RTMP 视频播放器视图
struct VideoPlayerView: UIViewControllerRepresentable {
    let url: String

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()

        guard let videoURL = URL(string: url) else {
            print("[VideoPlayerView] Invalid URL: \(url)")
            return controller
        }

        let player = AVPlayer(url: videoURL)
        controller.player = player
        controller.showsPlaybackControls = true

        // 自动播放
        player.play()

        print("[VideoPlayerView] Playing video from: \(url)")

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // 更新播放器（如果 URL 改变）
        guard let videoURL = URL(string: url) else { return }

        if uiViewController.player?.currentItem?.asset as? AVURLAsset != nil {
            let currentURL = (uiViewController.player?.currentItem?.asset as? AVURLAsset)?.url

            if currentURL != videoURL {
                let newPlayer = AVPlayer(url: videoURL)
                uiViewController.player = newPlayer
                newPlayer.play()
            }
        }
    }
}

/// 摄像头预览视图（用于本地视频采集）
struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.bounds
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // 更新布局
        DispatchQueue.main.async {
            previewLayer.frame = uiView.bounds
        }
    }
}
