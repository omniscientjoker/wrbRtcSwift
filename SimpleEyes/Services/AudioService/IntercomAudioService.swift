import Foundation
import AVFoundation

/// 对讲音频服务
/// 负责音频采集和播放
class IntercomAudioService {

    // MARK: - Properties

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var playerNode: AVAudioPlayerNode?

    private let sampleRate: Double = 16000
    private let channels: AVAudioChannelCount = 1

    // 使用专用的音频处理队列，避免阻塞主线程
    private let audioQueue = DispatchQueue(label: "com.simpleeyes.audioservice", qos: .userInitiated)

    var onAudioCaptured: ((Data) -> Void)?

    // MARK: - Initialization

    init() {
        // 异步初始化音频会话，避免阻塞主线程
        audioQueue.async { [weak self] in
            self?.setupAudioSession()
        }
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            // 设置音频会话类别
            try audioSession.setCategory(.playAndRecord,
                                        mode: .voiceChat,
                                        options: [.defaultToSpeaker, .allowBluetoothA2DP])

            // 设置采样率
            try audioSession.setPreferredSampleRate(sampleRate)

            // 设置 I/O 缓冲区大小（20ms）
            let bufferDuration = 0.02
            try audioSession.setPreferredIOBufferDuration(bufferDuration)

            // 激活音频会话
            try audioSession.setActive(true)

            print("[IntercomAudioService] Audio session configured successfully")
        } catch {
            print("[IntercomAudioService] Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Start/Stop Capture

    /// 开始音频采集
    func startCapture() throws {
        // 创建音频引擎
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        inputNode = audioEngine.inputNode

        // 设置输入格式
        let inputFormat = inputNode?.outputFormat(forBus: 0)
        guard let inputFormat = inputFormat else {
            throw NSError(domain: "AudioService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to get input format"])
        }

        // 创建转换后的格式（16kHz, 单声道, 16-bit PCM）
        guard let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: true
        ) else {
            throw NSError(domain: "AudioService", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create recording format"])
        }

        // 创建格式转换器
        guard let converter = AVAudioConverter(from: inputFormat, to: recordingFormat) else {
            throw NSError(domain: "AudioService", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
        }

        // 安装音频tap
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, converter: converter, outputFormat: recordingFormat)
        }

        // 启动音频引擎
        try audioEngine.start()

        print("[IntercomAudioService] Audio capture started")
    }

    /// 停止音频采集
    func stopCapture() {
        guard let engine = audioEngine, let input = inputNode else {
            print("[IntercomAudioService] Audio already stopped or not started")
            return
        }

        // 先移除 tap（引擎还存在时）
        input.removeTap(onBus: 0)

        // 然后停止引擎
        if engine.isRunning {
            engine.stop()
        }

        // 最后清理引用
        audioEngine = nil
        inputNode = nil

        print("[IntercomAudioService] Audio capture stopped")
    }

    // MARK: - Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer,
                                   converter: AVAudioConverter,
                                   outputFormat: AVAudioFormat) {
        // 计算输出缓冲区大小
        let capacity = UInt32((Double(buffer.frameLength) / buffer.format.sampleRate) *
                             outputFormat.sampleRate)

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: capacity
        ) else {
            return
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            print("[IntercomAudioService] Conversion error: \(error)")
            return
        }

        // 转换为 Data
        guard let channelData = convertedBuffer.int16ChannelData else { return }
        let channelDataPointer = channelData.pointee
        let data = Data(bytes: channelDataPointer,
                       count: Int(convertedBuffer.frameLength * convertedBuffer.format.channelCount * 2))

        // 在音频队列上执行回调，保持一致的 QoS
        audioQueue.async { [weak self] in
            self?.onAudioCaptured?(data)
        }
    }

    // MARK: - Audio Playback

    /// 播放音频数据（已解码的 PCM 数据）
    func playAudio(pcmData: Data) {
        if audioEngine == nil {
            // 如果引擎未启动，初始化播放器
            initializePlayer()
            return
        }

        // 创建 PCM 缓冲区
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: true
        ) else {
            return
        }

        let frameLength = UInt32(pcmData.count / 2) // 16-bit = 2 bytes per sample
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else {
            return
        }

        buffer.frameLength = frameLength

        // 复制数据到缓冲区
        pcmData.withUnsafeBytes { rawBufferPointer in
            guard let baseAddress = rawBufferPointer.baseAddress else { return }
            let int16Pointer = baseAddress.assumingMemoryBound(to: Int16.self)
            buffer.int16ChannelData?.pointee.update(from: int16Pointer, count: Int(frameLength))
        }

        // 播放
        if playerNode == nil {
            initializePlayer()
        }

        playerNode?.scheduleBuffer(buffer, completionHandler: nil)

        if playerNode?.isPlaying == false {
            playerNode?.play()
        }
    }

    private func initializePlayer() {
        guard audioEngine == nil else { return }

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        playerNode = AVAudioPlayerNode()
        guard let playerNode = playerNode else { return }

        audioEngine.attach(playerNode)

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: true
        ) else {
            return
        }

        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)

        do {
            try audioEngine.start()
            print("[IntercomAudioService] Player initialized")
        } catch {
            print("[IntercomAudioService] Failed to start audio engine for playback: \(error)")
        }
    }

    // MARK: - Cleanup

    deinit {
        stopCapture()

        // 在音频队列上异步停用音频会话，避免 deinit 阻塞
        audioQueue.async {
            try? AVAudioSession.sharedInstance().setActive(false)
        }
    }
}
