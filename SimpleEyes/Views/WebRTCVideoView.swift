import SwiftUI
import WebRTC

/// WebRTC 视频渲染视图
struct WebRTCVideoView: UIViewRepresentable {
    let videoTrack: RTCVideoTrack?

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let videoView = RTCMTLVideoView()
        videoView.contentMode = .scaleAspectFill
        videoView.videoContentMode = .scaleAspectFill

        #if arch(arm64)
        videoView.videoContentMode = .scaleAspectFill
        #endif

        return videoView
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        if let videoTrack = videoTrack {
            videoTrack.add(uiView)
        }
    }

    static func dismantleUIView(_ uiView: RTCMTLVideoView, coordinator: ()) {
        uiView.renderFrame(nil)
    }
}
