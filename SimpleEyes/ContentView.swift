//
//  ContentView.swift
//  SimpleEyes
//
//  Created by 姜淼 on 2025/12/10.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 设备列表
//            DeviceListView()
//                .tabItem {
//                    Label("设备", systemImage: "video.circle.fill")
//                }
//                .tag(0)

            // 视频直播
            QuickLiveView()
                .tabItem {
                    Label("直播", systemImage: "play.circle.fill")
                }
                .tag(0)

            // 视频回放
            QuickPlaybackView()
                .tabItem {
                    Label("回放", systemImage: "film.fill")
                }
                .tag(1)

            // 语音对讲
            QuickIntercomView()
                .tabItem {
                    Label("对讲", systemImage: "mic.fill")
                }
                .tag(2)

            // 视频通话
            VideoCallView()
                .tabItem {
                    Label("视频", systemImage: "video.fill")
                }
                .tag(3)

            // 设置
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
    }
}

#Preview {
    ContentView()
}
