import Foundation
import AudioToolbox
import AVFoundation

/// 对讲管理器
/// 整合 WebSocket 通信和音频服务
class IntercomManager {

    // MARK: - Properties

    private let deviceId: String
    private var wsService: IntercomWebSocketService
    private var audioService: IntercomAudioService

    // 音频编解码器（内联实现，避免需要添加新文件）
    private var audioEncoder: SimpleAACEncoder?
    private var audioDecoder: SimpleAACDecoder?

    private var isActive: Bool = false

    var onStatusChanged: ((IntercomStatus) -> Void)?

    // MARK: - Initialization

    init(deviceId: String) {
        self.deviceId = deviceId

        wsService = IntercomWebSocketService()
        audioService = IntercomAudioService()

        // 暂时不使用编解码器，直接传输 PCM 数据
        // audioEncoder = SimpleAACEncoder()
        // audioDecoder = SimpleAACDecoder()

        setupCallbacks()
    }

    // MARK: - Setup

    private func setupCallbacks() {
        // WebSocket 连接状态回调
        wsService.onConnectionStateChanged = { [weak self] connected in
            guard let self = self else { return }

            // 确保 UI 更新回调在主线程执行
            DispatchQueue.main.async {
                if connected {
                    self.onStatusChanged?(.connected)
                } else {
                    self.onStatusChanged?(.idle)
                    // 连接断开，停止音频采集
                    if self.isActive {
                        self.stopIntercom()
                    }
                }
            }
        }

        // WebSocket 接收音频数据回调
        wsService.onAudioDataReceived = { [weak self] data in
            guard let self = self else { return }

            // 暂时直接播放 PCM 数据（无需解码）
            self.audioService.playAudio(pcmData: data)
            print("[IntercomManager] Received and playing audio: \(data.count) bytes PCM")
        }

        // 音频采集回调
        audioService.onAudioCaptured = { [weak self] pcmData in
            guard let self = self else { return }

            // 暂时直接发送 PCM 数据（无需编码）
            self.wsService.sendAudioData(pcmData)
            print("[IntercomManager] Captured and sent audio: \(pcmData.count) bytes PCM")
        }
    }

    // MARK: - Public Methods

    /// 开始对讲
    func startIntercom() {
        guard !isActive else { return }

        // UI 更新在主线程
        DispatchQueue.main.async { [weak self] in
            self?.onStatusChanged?(.connecting)
        }

        // 连接 WebSocket（APIConfig.wsURL 会自动从 UserDefaults 读取用户配置）
        let serverURL = "\(APIConfig.wsURL)?deviceId=\(deviceId)"

        print("[IntercomManager] Connecting to WebSocket: \(serverURL)")
        wsService.connect(deviceId: deviceId, serverURL: serverURL)

        // 开始音频采集
        do {
            try audioService.startCapture()
            isActive = true

            // UI 更新在主线程
            DispatchQueue.main.async { [weak self] in
                self?.onStatusChanged?(.speaking)
            }

            print("[IntercomManager] Intercom started for device: \(deviceId)")
        } catch {
            print("[IntercomManager] Failed to start audio capture: \(error)")

            // UI 更新在主线程
            DispatchQueue.main.async { [weak self] in
                self?.onStatusChanged?(.error(error.localizedDescription))
            }
            wsService.disconnect()
        }
    }

    /// 停止对讲
    func stopIntercom() {
        guard isActive else { return }

        // 停止音频采集
        audioService.stopCapture()

        // 断开 WebSocket
        wsService.disconnect()

        isActive = false

        // UI 更新在主线程
        DispatchQueue.main.async { [weak self] in
            self?.onStatusChanged?(.idle)
        }

        print("[IntercomManager] Intercom stopped")
    }

    /// 是否正在对讲
    func isIntercomActive() -> Bool {
        return isActive
    }

    // MARK: - Cleanup

    deinit {
        stopIntercom()
    }
}

// MARK: - Simple AAC Encoder (Inline Implementation)

/// 简化的 AAC 编码器
private class SimpleAACEncoder {
    private var converter: AudioConverterRef?
    private let sampleRate: Double = 16000
    private let channels: UInt32 = 1
    private let bitrate: UInt32 = 32000

    init?() {
        var inputDesc = AudioStreamBasicDescription()
        inputDesc.mSampleRate = sampleRate
        inputDesc.mFormatID = kAudioFormatLinearPCM
        inputDesc.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
        inputDesc.mBitsPerChannel = 16
        inputDesc.mChannelsPerFrame = channels
        inputDesc.mBytesPerFrame = channels * 2
        inputDesc.mFramesPerPacket = 1
        inputDesc.mBytesPerPacket = inputDesc.mBytesPerFrame

        var outputDesc = AudioStreamBasicDescription()
        outputDesc.mSampleRate = sampleRate
        outputDesc.mFormatID = kAudioFormatMPEG4AAC
        outputDesc.mChannelsPerFrame = channels
        outputDesc.mFramesPerPacket = 1024

        var converterRef: AudioConverterRef?
        let status = AudioConverterNew(&inputDesc, &outputDesc, &converterRef)
        guard status == noErr, let converter = converterRef else { return nil }

        self.converter = converter
        var bitrateValue = bitrate
        AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate,
                                 UInt32(MemoryLayout<UInt32>.size), &bitrateValue)
    }

    func encode(pcmData: Data) -> Data? {
        guard let converter = converter else { return nil }

        let maxOutputSize = pcmData.count
        var outputBuffer = [UInt8](repeating: 0, count: maxOutputSize)
        var inputData = pcmData

        let inputProc: AudioConverterComplexInputDataProc = { (_, ioNumberDataPackets, ioData, _, inUserData) -> OSStatus in
            guard let userDataPtr = inUserData else { return -1 }
            let inputDataPtr = userDataPtr.assumingMemoryBound(to: Data.self)
            let inputData = inputDataPtr.pointee

            ioData.pointee.mNumberBuffers = 1
            ioData.pointee.mBuffers.mNumberChannels = 1
            ioData.pointee.mBuffers.mDataByteSize = UInt32(inputData.count)
            ioData.pointee.mBuffers.mData = UnsafeMutableRawPointer(mutating: (inputData as NSData).bytes)
            ioNumberDataPackets.pointee = UInt32(inputData.count / 2)
            return noErr
        }

        var finalOutputSize = 0
        let status = outputBuffer.withUnsafeMutableBytes { bufferPointer -> OSStatus in
            var outputBufferList = AudioBufferList()
            outputBufferList.mNumberBuffers = 1
            outputBufferList.mBuffers.mNumberChannels = channels
            outputBufferList.mBuffers.mDataByteSize = UInt32(maxOutputSize)
            outputBufferList.mBuffers.mData = bufferPointer.baseAddress

            var ioOutputDataPacketSize: UInt32 = 1
            let result = withUnsafeMutablePointer(to: &inputData) { dataPtr in
                AudioConverterFillComplexBuffer(converter, inputProc, dataPtr,
                                               &ioOutputDataPacketSize, &outputBufferList, nil)
            }
            finalOutputSize = Int(outputBufferList.mBuffers.mDataByteSize)
            return result
        }

        guard status == noErr else { return nil }
        return Data(bytes: outputBuffer, count: finalOutputSize)
    }

    deinit {
        if let converter = converter {
            AudioConverterDispose(converter)
        }
    }
}

// MARK: - Simple AAC Decoder (Inline Implementation)

/// 简化的 AAC 解码器
private class SimpleAACDecoder {
    private var converter: AudioConverterRef?
    private let sampleRate: Double = 16000
    private let channels: UInt32 = 1

    init?() {
        var inputDesc = AudioStreamBasicDescription()
        inputDesc.mSampleRate = sampleRate
        inputDesc.mFormatID = kAudioFormatMPEG4AAC
        inputDesc.mChannelsPerFrame = channels
        inputDesc.mFramesPerPacket = 1024

        var outputDesc = AudioStreamBasicDescription()
        outputDesc.mSampleRate = sampleRate
        outputDesc.mFormatID = kAudioFormatLinearPCM
        outputDesc.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
        outputDesc.mBitsPerChannel = 16
        outputDesc.mChannelsPerFrame = channels
        outputDesc.mBytesPerFrame = channels * 2
        outputDesc.mFramesPerPacket = 1
        outputDesc.mBytesPerPacket = outputDesc.mBytesPerFrame

        var converterRef: AudioConverterRef?
        let status = AudioConverterNew(&inputDesc, &outputDesc, &converterRef)
        guard status == noErr, let converter = converterRef else { return nil }

        self.converter = converter
    }

    func decode(aacData: Data) -> Data? {
        guard let converter = converter else { return nil }

        let maxOutputSize = aacData.count * 4
        var outputBuffer = [UInt8](repeating: 0, count: maxOutputSize)
        var inputData = aacData

        let inputProc: AudioConverterComplexInputDataProc = { (_, ioNumberDataPackets, ioData, _, inUserData) -> OSStatus in
            guard let userDataPtr = inUserData else { return -1 }
            let inputDataPtr = userDataPtr.assumingMemoryBound(to: Data.self)
            let inputData = inputDataPtr.pointee

            ioData.pointee.mNumberBuffers = 1
            ioData.pointee.mBuffers.mNumberChannels = 1
            ioData.pointee.mBuffers.mDataByteSize = UInt32(inputData.count)
            ioData.pointee.mBuffers.mData = UnsafeMutableRawPointer(mutating: (inputData as NSData).bytes)
            ioNumberDataPackets.pointee = 1
            return noErr
        }

        var finalOutputSize = 0
        let status = outputBuffer.withUnsafeMutableBytes { bufferPointer -> OSStatus in
            var outputBufferList = AudioBufferList()
            outputBufferList.mNumberBuffers = 1
            outputBufferList.mBuffers.mNumberChannels = channels
            outputBufferList.mBuffers.mDataByteSize = UInt32(maxOutputSize)
            outputBufferList.mBuffers.mData = bufferPointer.baseAddress

            var ioOutputDataPacketSize: UInt32 = UInt32(maxOutputSize / 2)
            let result = withUnsafeMutablePointer(to: &inputData) { dataPtr in
                AudioConverterFillComplexBuffer(converter, inputProc, dataPtr,
                                               &ioOutputDataPacketSize, &outputBufferList, nil)
            }
            finalOutputSize = Int(outputBufferList.mBuffers.mDataByteSize)
            return result
        }

        guard status == noErr else { return nil }
        return Data(bytes: outputBuffer, count: finalOutputSize)
    }

    deinit {
        if let converter = converter {
            AudioConverterDispose(converter)
        }
    }
}
