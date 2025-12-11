//
//  VideoCaptureService.swift
//  SimpleEyes
//
//  视频采集服务 - 使用 AVCaptureSession
//

import Foundation
import AVFoundation
import UIKit

/// 视频采集服务
class VideoCaptureService: NSObject {

    // MARK: - Properties

    private var captureSession: AVCaptureSession?
    private var videoDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?

    private let sessionQueue = DispatchQueue(label: "com.simpleeyes.videocapture", qos: .userInitiated)

    // 预览层
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?

    // 视频数据回调
    var onFrameCaptured: ((CMSampleBuffer) -> Void)?

    // 采集参数
    private let fps: Int32 = 25
    private let resolution: AVCaptureSession.Preset = .hd1280x720

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Setup

    /// 设置采集会话
    func setupCaptureSession() throws {
        let session = AVCaptureSession()
        session.sessionPreset = resolution

        // 获取摄像头设备
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw NSError(domain: "VideoCaptureService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "无法访问前置摄像头"])
        }

        videoDevice = camera

        // 配置摄像头参数
        try camera.lockForConfiguration()
        camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: fps)
        camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: fps)
        camera.unlockForConfiguration()

        // 创建视频输入
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            throw NSError(domain: "VideoCaptureService", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "无法添加视频输入"])
        }
        session.addInput(input)
        videoInput = input

        // 创建视频输出
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: sessionQueue)

        guard session.canAddOutput(output) else {
            throw NSError(domain: "VideoCaptureService", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "无法添加视频输出"])
        }
        session.addOutput(output)
        videoOutput = output

        // 设置视频方向
        if let connection = output.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true // 前置摄像头镜像
            }
        }

        // 创建预览层
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        previewLayer = preview

        captureSession = session

        print("[VideoCaptureService] Capture session setup completed")
    }

    // MARK: - Start/Stop

    /// 开始采集
    func startCapture() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.startRunning()
            print("[VideoCaptureService] Capture started")
        }
    }

    /// 停止采集
    func stopCapture() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            print("[VideoCaptureService] Capture stopped")
        }
    }

    /// 是否正在采集
    var isRunning: Bool {
        return captureSession?.isRunning ?? false
    }

    // MARK: - Camera Control

    /// 切换前后摄像头
    func switchCamera() throws {
        guard let session = captureSession,
              let currentInput = videoInput else { return }

        let currentPosition = currentInput.device.position
        let newPosition: AVCaptureDevice.Position = currentPosition == .front ? .back : .front

        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            throw NSError(domain: "VideoCaptureService", code: -4,
                         userInfo: [NSLocalizedDescriptionKey: "无法访问\(newPosition == .front ? "前置" : "后置")摄像头"])
        }

        // 配置新摄像头
        try newCamera.lockForConfiguration()
        newCamera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: fps)
        newCamera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: fps)
        newCamera.unlockForConfiguration()

        let newInput = try AVCaptureDeviceInput(device: newCamera)

        session.beginConfiguration()
        session.removeInput(currentInput)

        if session.canAddInput(newInput) {
            session.addInput(newInput)
            videoInput = newInput
            videoDevice = newCamera

            // 更新镜像设置
            if let output = videoOutput,
               let connection = output.connection(with: .video) {
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = (newPosition == .front)
                }
            }
        } else {
            // 如果添加失败，恢复原来的输入
            session.addInput(currentInput)
        }

        session.commitConfiguration()

        print("[VideoCaptureService] Switched to \(newPosition == .front ? "front" : "back") camera")
    }

    // MARK: - Cleanup

    deinit {
        stopCapture()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension VideoCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        // 回调视频帧
        onFrameCaptured?(sampleBuffer)
    }

    func captureOutput(_ output: AVCaptureOutput,
                      didDrop sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        print("[VideoCaptureService] Dropped frame")
    }
}
