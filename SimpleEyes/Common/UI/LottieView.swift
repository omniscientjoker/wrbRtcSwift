//
//  LottieView.swift
//  SimpleEyes
//
//  Created by 姜淼 on 2025/12/15.
//

import SwiftUI
import Lottie

/// LottieView SwiftUI 包装器
///
/// 将 Lottie 动画集成到 SwiftUI 中使用
struct LottieView: UIViewRepresentable {

    // MARK: - 属性

    /// 动画名称（JSON 文件名，不含扩展名）
    let animationName: String

    /// 动画播放模式
    let loopMode: LottieLoopMode

    /// 动画播放速度（默认为 1.0）
    let animationSpeed: CGFloat

    /// 内容模式
    let contentMode: UIView.ContentMode

    // MARK: - 初始化

    /// 创建 LottieView
    /// - Parameters:
    ///   - animationName: 动画文件名（不含 .json 扩展名）
    ///   - loopMode: 循环模式，默认为循环播放
    ///   - animationSpeed: 播放速度，默认为 1.0
    ///   - contentMode: 内容模式，默认为 scaleAspectFit
    init(
        animationName: String,
        loopMode: LottieLoopMode = .loop,
        animationSpeed: CGFloat = 1.0,
        contentMode: UIView.ContentMode = .scaleAspectFit
    ) {
        self.animationName = animationName
        self.loopMode = loopMode
        self.animationSpeed = animationSpeed
        self.contentMode = contentMode
    }

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView(name: animationName)
        animationView.loopMode = loopMode
        animationView.animationSpeed = animationSpeed
        animationView.contentMode = contentMode
        animationView.play()
        return animationView
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        // SwiftUI 会在需要时重新创建视图，这里保持简单即可
    }
}

// MARK: - Preview

#if DEBUG
struct LottieView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            LottieView(animationName: "scanning")
                .frame(width: 100, height: 100)

            LottieView(animationName: "paused")
                .frame(width: 100, height: 100)
        }
    }
}
#endif
