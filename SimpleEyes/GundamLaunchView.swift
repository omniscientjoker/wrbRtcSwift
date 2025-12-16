//
//  GundamLaunchView.swift
//  SimpleEyes
//
//  高达驾驶舱HUD启动动画
//  完全模仿 gundamImage.jpg 的界面风格
//

import SwiftUI

struct GundamLaunchView: View {
    @Binding var isAnimationComplete: Bool

    @State private var phase: AnimationPhase = .initial
    @State private var hudOpacity: Double = 0
    @State private var crosshairOpacity: Double = 0
    @State private var wingIndicatorsOpacity: [Double] = [0, 0, 0, 0, 0, 0] // 6个发光扇形
    @State private var scaleLineOpacity: Double = 0
    @State private var arcGridOpacity: Double = 0
    @State private var centerGeometryOpacity: Double = 0
    @State private var scanLineProgress: CGFloat = 0
    @State private var glowPulse: Double = 0
    @State private var radarRotation: Double = 0

    private let hudColor: Color = .white
    private let glowColor: Color = Color(red: 0.8, green: 0.9, blue: 1.0)

    enum AnimationPhase {
        case initial, crosshairActivation, wingIndicators, scaleLines,
             arcGrid, centerSymbols, scanning, systemReady, complete
    }

    var body: some View {
        ZStack {
            // 深蓝黑色背景
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.03, blue: 0.08),
                    Color(red: 0.0, green: 0.0, blue: 0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // 底部弧形网格
            ArcGridLayer(opacity: arcGridOpacity, color: hudColor)

            // 六个发光扇形指示器（最显眼的元素）
            WingIndicatorsLayer(opacities: wingIndicatorsOpacity, glowPulse: glowPulse, color: hudColor)

            // 中心十字准线
            CenterCrosshair(opacity: crosshairOpacity, color: hudColor)

            // 斜向刻度线系统
            DiagonalScaleLines(opacity: scaleLineOpacity, color: hudColor)

            // 中心几何符号
            CenterGeometrySymbols(opacity: centerGeometryOpacity, color: hudColor)

            // 扫描线效果
            ScanLineEffect(progress: scanLineProgress, color: glowColor)

            // 雷达扫描
            if phase == .scanning || phase == .systemReady {
                RadarSweepEffect(rotation: radarRotation, color: glowColor)
            }
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // 阶段1: 十字准线激活 (0-0.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            phase = .crosshairActivation
            withAnimation(.easeOut(duration: 0.8)) {
                crosshairOpacity = 1.0
            }
        }

        // 阶段2: 扇形指示器依次点亮 (0.5-2.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            phase = .wingIndicators
            // 依次点亮6个指示器
            for i in 0..<6 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        wingIndicatorsOpacity[i] = 1.0
                    }
                }
            }

            // 启动脉冲效果
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowPulse = 0.4
                }
            }
        }

        // 阶段3: 刻度线系统 (1.8-2.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            phase = .scaleLines
            withAnimation(.easeIn(duration: 0.7)) {
                scaleLineOpacity = 1.0
            }
        }

        // 阶段4: 弧形网格 (2.3-3.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            phase = .arcGrid
            withAnimation(.easeOut(duration: 0.9)) {
                arcGridOpacity = 1.0
            }
        }

        // 阶段5: 中心几何符号 (2.8-3.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            phase = .centerSymbols
            withAnimation(.easeIn(duration: 0.7)) {
                centerGeometryOpacity = 1.0
            }
        }

        // 阶段6: 扫描效果 (3.2-4.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            phase = .scanning
            withAnimation(.linear(duration: 1.0)) {
                scanLineProgress = 1.0
            }
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                radarRotation = 360
            }
        }

        // 阶段7: 系统就绪 (4.2-5.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            phase = .systemReady
        }

        // 阶段8: 淡出完成 (5.0-5.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            phase = .complete
            withAnimation(.easeOut(duration: 0.8)) {
                crosshairOpacity = 0
                scaleLineOpacity = 0
                arcGridOpacity = 0
                centerGeometryOpacity = 0
                wingIndicatorsOpacity = [0, 0, 0, 0, 0, 0]
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isAnimationComplete = true
            }
        }
    }
}

// MARK: - 六个发光扇形指示器（最重要的视觉元素）

private struct WingIndicatorsLayer: View {
    let opacities: [Double]
    let glowPulse: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // 左上角
            GlowingWingIndicator(color: color, glowIntensity: glowPulse)
                .position(x: 100, y: 120)
                .opacity(opacities[0])

            // 右上角
            GlowingWingIndicator(color: color, glowIntensity: glowPulse)
                .scaleEffect(x: -1, y: 1)
                .position(x: w - 100, y: 120)
                .opacity(opacities[1])

            // 左中
            GlowingWingIndicator(color: color, glowIntensity: glowPulse)
                .position(x: 100, y: h / 2)
                .opacity(opacities[2])

            // 右中
            GlowingWingIndicator(color: color, glowIntensity: glowPulse)
                .scaleEffect(x: -1, y: 1)
                .position(x: w - 100, y: h / 2)
                .opacity(opacities[3])

            // 左下
            GlowingWingIndicator(color: color, glowIntensity: glowPulse)
                .position(x: 180, y: h - 140)
                .opacity(opacities[4])

            // 右下
            GlowingWingIndicator(color: color, glowIntensity: glowPulse)
                .scaleEffect(x: -1, y: 1)
                .position(x: w - 180, y: h - 140)
                .opacity(opacities[5])
        }
    }
}

/// 单个发光扇形指示器（类似推进器喷射效果）
private struct GlowingWingIndicator: View {
    let color: Color
    let glowIntensity: Double

    var body: some View {
        ZStack {
            // 发光底层
            ForEach(0..<4, id: \.self) { i in
                WingShape(layerIndex: i)
                    .fill(color)
                    .blur(radius: 8 + CGFloat(i) * 3)
                    .opacity(0.6 - Double(i) * 0.12 + glowIntensity)
            }

            // 主体线条
            WingShape(layerIndex: 0)
                .fill(color)
            WingShape(layerIndex: 1)
                .fill(color.opacity(0.9))
            WingShape(layerIndex: 2)
                .fill(color.opacity(0.8))
            WingShape(layerIndex: 3)
                .fill(color.opacity(0.7))
        }
    }
}

/// 扇形翼状图形（3-4条平行线组成）
private struct WingShape: Shape {
    let layerIndex: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let baseWidth: CGFloat = 50
        let baseHeight: CGFloat = 8
        let spacing: CGFloat = 4
        let yOffset = CGFloat(layerIndex) * (baseHeight + spacing)

        // 梯形形状（向右收缩）
        let leftWidth = baseWidth
        let rightWidth = baseWidth * 0.4

        path.move(to: CGPoint(x: 0, y: yOffset))
        path.addLine(to: CGPoint(x: leftWidth, y: yOffset))
        path.addLine(to: CGPoint(x: leftWidth - (leftWidth - rightWidth), y: yOffset + baseHeight))
        path.addLine(to: CGPoint(x: 0, y: yOffset + baseHeight))
        path.closeSubpath()

        return path
    }
}

// MARK: - 中心十字准线

private struct CenterCrosshair: View {
    let opacity: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2

            ZStack {
                // 顶部倒三角
                Path { path in
                    path.move(to: CGPoint(x: cx, y: cy - 60))
                    path.addLine(to: CGPoint(x: cx - 10, y: cy - 75))
                    path.addLine(to: CGPoint(x: cx + 10, y: cy - 75))
                    path.closeSubpath()
                }
                .stroke(color, lineWidth: 2)

                // 顶部虚线
                Path { path in
                    for i in stride(from: 0, to: 50, by: 8) {
                        path.move(to: CGPoint(x: cx, y: cy - 75 - CGFloat(i)))
                        path.addLine(to: CGPoint(x: cx, y: cy - 75 - CGFloat(i) - 4))
                    }
                }
                .stroke(color, lineWidth: 1.5)

                // 十字主线
                Path { path in
                    // 水平
                    path.move(to: CGPoint(x: cx - 200, y: cy))
                    path.addLine(to: CGPoint(x: cx - 20, y: cy))
                    path.move(to: CGPoint(x: cx + 20, y: cy))
                    path.addLine(to: CGPoint(x: cx + 200, y: cy))

                    // 垂直
                    path.move(to: CGPoint(x: cx, y: cy - 60))
                    path.addLine(to: CGPoint(x: cx, y: cy - 20))
                    path.move(to: CGPoint(x: cx, y: cy + 20))
                    path.addLine(to: CGPoint(x: cx, y: cy + 100))
                }
                .stroke(color, lineWidth: 2)

                // 中心小圆环
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 16, height: 16)
                    .position(x: cx, y: cy)

                // 中心点
                Circle()
                    .fill(color)
                    .frame(width: 3, height: 3)
                    .position(x: cx, y: cy)
            }
        }
        .opacity(opacity)
    }
}

// MARK: - 斜向刻度线系统

private struct DiagonalScaleLines: View {
    let opacity: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2

            Canvas { context, size in
                // 左侧斜向密集刻度
                let leftStartX = cx - 250
                let leftStartY = cy
                for i in 0..<25 {
                    var path = Path()
                    let x = leftStartX + CGFloat(i) * 3
                    let y = leftStartY - CGFloat(i) * 2
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + 15, y: y - 10))
                    context.stroke(path, with: .color(color), lineWidth: 1.5)
                }

                // 右侧斜向密集刻度
                let rightStartX = cx + 250
                let rightStartY = cy
                for i in 0..<25 {
                    var path = Path()
                    let x = rightStartX - CGFloat(i) * 3
                    let y = rightStartY - CGFloat(i) * 2
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x - 15, y: y - 10))
                    context.stroke(path, with: .color(color), lineWidth: 1.5)
                }

                // 水平刻度线
                let bottomY = geo.size.height * 0.52
                for i in stride(from: 0, to: size.width, by: 30) {
                    let isBig = Int(i) % 90 == 0
                    var path = Path()
                    path.move(to: CGPoint(x: i, y: bottomY))
                    path.addLine(to: CGPoint(x: i, y: bottomY + (isBig ? 12 : 6)))
                    context.stroke(path, with: .color(color), lineWidth: isBig ? 2 : 1)
                }

                // 主水平线
                var mainLine = Path()
                mainLine.move(to: CGPoint(x: 0, y: bottomY))
                mainLine.addLine(to: CGPoint(x: size.width, y: bottomY))
                context.stroke(mainLine, with: .color(color.opacity(0.6)), lineWidth: 1.5)

                // 垂直虚线参考线
                for xPos in [cx - 150, cx + 150] {
                    for i in stride(from: 0, to: size.height, by: 12) {
                        var path = Path()
                        path.move(to: CGPoint(x: xPos, y: CGFloat(i)))
                        path.addLine(to: CGPoint(x: xPos, y: CGFloat(i) + 6))
                        context.stroke(path, with: .color(color.opacity(0.5)), lineWidth: 1)
                    }
                }
            }
        }
        .opacity(opacity)
    }
}

// MARK: - 弧形网格

private struct ArcGridLayer: View {
    let opacity: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let bottomY = geo.size.height

            Canvas { context, size in
                // 同心弧线
                for i in 1...5 {
                    let radius = CGFloat(i) * 80
                    var path = Path()
                    path.addArc(
                        center: CGPoint(x: cx, y: bottomY + 80),
                        radius: radius,
                        startAngle: .degrees(180),
                        endAngle: .degrees(360),
                        clockwise: false
                    )
                    context.stroke(
                        path,
                        with: .color(color.opacity(0.5 - Double(i) * 0.06)),
                        lineWidth: 1.5
                    )
                }

                // 放射状分隔线
                for angle in stride(from: 180.0, to: 360.0, by: 12.0) {
                    let rad = angle * .pi / 180
                    var path = Path()
                    path.move(to: CGPoint(x: cx, y: bottomY + 80))
                    let endX = cx + cos(rad) * 400
                    let endY = bottomY + 80 + sin(rad) * 400
                    path.addLine(to: CGPoint(x: endX, y: endY))
                    context.stroke(
                        path,
                        with: .color(color.opacity(0.3)),
                        lineWidth: 0.8
                    )
                }
            }
        }
        .opacity(opacity)
    }
}

// MARK: - 中心几何符号

private struct CenterGeometrySymbols: View {
    let opacity: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2

            ZStack {
                // 左侧箭头组
                HStack(spacing: 8) {
                    ArrowIndicator(direction: .right, color: color)
                    ArrowIndicator(direction: .right, color: color)
                        .opacity(0.6)
                }
                .position(x: cx - 100, y: cy)

                // 右侧箭头组
                HStack(spacing: 8) {
                    ArrowIndicator(direction: .left, color: color)
                        .opacity(0.6)
                    ArrowIndicator(direction: .left, color: color)
                }
                .position(x: cx + 100, y: cy)

                // 下方几何图形组
                HStack(spacing: 10) {
                    TriangleSymbol()
                        .stroke(color, lineWidth: 1.5)
                        .frame(width: 16, height: 14)

                    DiamondSymbol()
                        .stroke(color, lineWidth: 1.5)
                        .frame(width: 14, height: 14)

                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)

                    DiamondSymbol()
                        .stroke(color, lineWidth: 1.5)
                        .frame(width: 14, height: 14)

                    TriangleSymbol()
                        .stroke(color, lineWidth: 1.5)
                        .frame(width: 16, height: 14)
                }
                .position(x: cx, y: cy + 65)

                // 下方向下箭头
                Path { path in
                    path.move(to: CGPoint(x: cx - 6, y: cy + 95))
                    path.addLine(to: CGPoint(x: cx, y: cy + 105))
                    path.addLine(to: CGPoint(x: cx + 6, y: cy + 95))
                }
                .stroke(color, lineWidth: 2)
            }
        }
        .opacity(opacity)
    }
}

private struct ArrowIndicator: View {
    enum Direction { case left, right }
    let direction: Direction
    let color: Color

    var body: some View {
        ZStack {
            // 菱形边框
            DiamondSymbol()
                .stroke(color, lineWidth: 1.5)
                .frame(width: 20, height: 20)

            // 内部箭头
            Path { path in
                if direction == .right {
                    path.move(to: CGPoint(x: 12, y: 10))
                    path.addLine(to: CGPoint(x: 6, y: 7))
                    path.addLine(to: CGPoint(x: 6, y: 13))
                    path.closeSubpath()
                } else {
                    path.move(to: CGPoint(x: 8, y: 10))
                    path.addLine(to: CGPoint(x: 14, y: 7))
                    path.addLine(to: CGPoint(x: 14, y: 13))
                    path.closeSubpath()
                }
            }
            .fill(color)
        }
        .frame(width: 20, height: 20)
    }
}

private struct TriangleSymbol: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct DiamondSymbol: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 扫描效果

private struct ScanLineEffect: View {
    let progress: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let yPos = progress * geo.size.height

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0), color.opacity(0.5), color.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 2)
                .position(x: geo.size.width / 2, y: yPos)
                .shadow(color: color, radius: 15)
        }
        .opacity(min(progress * 2, 1))
    }
}

private struct RadarSweepEffect: View {
    let rotation: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2

            Path { path in
                path.move(to: CGPoint(x: cx, y: cy))
                path.addArc(
                    center: CGPoint(x: cx, y: cy),
                    radius: 250,
                    startAngle: .degrees(0),
                    endAngle: .degrees(45),
                    clockwise: false
                )
            }
            .fill(
                AngularGradient(
                    colors: [color.opacity(0.3), color.opacity(0)],
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(45)
                )
            )
            .rotationEffect(.degrees(rotation))
            .opacity(0.6)
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var isComplete = false

        var body: some View {
            GundamLaunchView(isAnimationComplete: $isComplete)
        }
    }

    return PreviewWrapper()
}
