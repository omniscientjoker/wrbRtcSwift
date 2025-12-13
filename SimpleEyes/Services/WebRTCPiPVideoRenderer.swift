import Foundation
import AVFoundation
import WebRTC

/// WebRTC 画中画视频渲染器
class WebRTCPiPVideoRenderer: NSObject, RTCVideoRenderer {
    // MARK: - Properties

    private let sampleBufferDisplayLayer: AVSampleBufferDisplayLayer
    private var pixelBufferPool: CVPixelBufferPool?

    // MARK: - Initialization

    init(sampleBufferDisplayLayer: AVSampleBufferDisplayLayer) {
        self.sampleBufferDisplayLayer = sampleBufferDisplayLayer
        super.init()
    }

    // MARK: - RTCVideoRenderer

    func setSize(_ size: CGSize) {
        print("[PiPRenderer] Set size: \(size)")
    }

    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame = frame else { return }

        // 将 RTCVideoFrame 转换为 CVPixelBuffer
        guard let pixelBuffer = convertToPixelBuffer(frame) else {
            return
        }

        // 创建 CMSampleBuffer
        guard let sampleBuffer = createSampleBuffer(from: pixelBuffer, presentationTime: Int64(frame.timeStamp)) else {
            return
        }

        // 显示到 layer
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.sampleBufferDisplayLayer.status == .failed {
                self.sampleBufferDisplayLayer.flush()
            }
            self.sampleBufferDisplayLayer.enqueue(sampleBuffer)
        }
    }

    // MARK: - Private Methods

    private func convertToPixelBuffer(_ frame: RTCVideoFrame) -> CVPixelBuffer? {
        // 如果已经是 CVPixelBuffer，直接返回
        if let pixelBuffer = frame.buffer as? RTCCVPixelBuffer {
            return pixelBuffer.pixelBuffer
        }

        // 转换为 I420Buffer
        let i420Buffer = frame.buffer.toI420()

        let width = Int(i420Buffer.width)
        let height = Int(i420Buffer.height)

        // 创建 pixel buffer pool（如果需要）
        if pixelBufferPool == nil {
            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]

            var pool: CVPixelBufferPool?
            let status = CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &pool)
            if status != kCVReturnSuccess {
                print("[PiPRenderer] Failed to create pixel buffer pool: \(status)")
                return nil
            }
            pixelBufferPool = pool
        }

        // 从 pool 获取 pixel buffer
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool!, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            print("[PiPRenderer] Failed to create pixel buffer: \(status)")
            return nil
        }

        // 锁定 pixel buffer
        CVPixelBufferLockBaseAddress(buffer, [])
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, [])
        }

        // 复制 Y 平面
        let yPlaneAddress = CVPixelBufferGetBaseAddressOfPlane(buffer, 0)
        let yPlaneStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let yDataPtr = i420Buffer.dataY
        let yStride = Int(i420Buffer.strideY)

        for row in 0..<height {
            let src = yDataPtr.advanced(by: row * yStride)
            let dst = yPlaneAddress!.advanced(by: row * yPlaneStride)
            memcpy(dst, src, width)
        }

        // 复制 UV 平面（交错）
        let uvPlaneAddress = CVPixelBufferGetBaseAddressOfPlane(buffer, 1)
        let uvPlaneStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
        let uDataPtr = i420Buffer.dataU
        let vDataPtr = i420Buffer.dataV
        let uvStride = Int(i420Buffer.strideU)

        for row in 0..<(height / 2) {
            for col in 0..<(width / 2) {
                let dstOffset = row * uvPlaneStride + col * 2
                let srcOffset = row * uvStride + col

                let u = uDataPtr.advanced(by: srcOffset).pointee
                let v = vDataPtr.advanced(by: srcOffset).pointee

                uvPlaneAddress!.advanced(by: dstOffset).storeBytes(of: u, as: UInt8.self)
                uvPlaneAddress!.advanced(by: dstOffset + 1).storeBytes(of: v, as: UInt8.self)
            }
        }

        return buffer
    }

    private func createSampleBuffer(from pixelBuffer: CVPixelBuffer, presentationTime: Int64) -> CMSampleBuffer? {
        var formatDescription: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )

        guard status == noErr, let formatDesc = formatDescription else {
            print("[PiPRenderer] Failed to create format description: \(status)")
            return nil
        }

        // 创建时间信息
        let timestamp = CMTime(value: presentationTime, timescale: 1_000_000_000)
        var timingInfo = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: timestamp,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        let createStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDesc,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )

        guard createStatus == noErr else {
            print("[PiPRenderer] Failed to create sample buffer: \(createStatus)")
            return nil
        }

        return sampleBuffer
    }
}
