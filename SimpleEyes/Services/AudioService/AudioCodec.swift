//
//  AudioCodec.swift
//  SimpleEyes
//
//  音频编解码服务 - AAC 编解码器
//

import Foundation
import AVFoundation
import AudioToolbox

/// AAC 音频编码器
class AACAudioEncoder {

    private var converter: AudioConverterRef?
    private let outputFormat: AudioStreamBasicDescription
    private let inputFormat: AudioStreamBasicDescription

    // 编码参数
    private let sampleRate: Double = 16000
    private let channels: UInt32 = 1
    private let bitrate: UInt32 = 32000 // 32kbps

    init?() {
        // 输入格式：PCM Int16, 16kHz, 单声道
        var inputDesc = AudioStreamBasicDescription()
        inputDesc.mSampleRate = sampleRate
        inputDesc.mFormatID = kAudioFormatLinearPCM
        inputDesc.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
        inputDesc.mBitsPerChannel = 16
        inputDesc.mChannelsPerFrame = channels
        inputDesc.mBytesPerFrame = channels * 2
        inputDesc.mFramesPerPacket = 1
        inputDesc.mBytesPerPacket = inputDesc.mBytesPerFrame * inputDesc.mFramesPerPacket

        // 输出格式：AAC
        var outputDesc = AudioStreamBasicDescription()
        outputDesc.mSampleRate = sampleRate
        outputDesc.mFormatID = kAudioFormatMPEG4AAC
        outputDesc.mChannelsPerFrame = channels
        outputDesc.mFramesPerPacket = 1024 // AAC 帧大小

        self.inputFormat = inputDesc
        self.outputFormat = outputDesc

        // 创建转换器
        var converterRef: AudioConverterRef?
        let status = AudioConverterNew(&inputDesc, &outputDesc, &converterRef)

        guard status == noErr, let converter = converterRef else {
            print("[AACAudioEncoder] Failed to create converter: \(status)")
            return nil
        }

        self.converter = converter

        // 设置比特率
        var bitrateValue = bitrate
        AudioConverterSetProperty(
            converter,
            kAudioConverterEncodeBitRate,
            UInt32(MemoryLayout<UInt32>.size),
            &bitrateValue
        )

        print("[AACAudioEncoder] Initialized successfully")
    }

    /// 编码 PCM 数据为 AAC
    func encode(pcmData: Data) -> Data? {
        guard let converter = converter else { return nil }

        let inputDataSize = pcmData.count
        let maxOutputSize = inputDataSize // AAC 输出通常更小
        var outputBuffer = [UInt8](repeating: 0, count: maxOutputSize)

        // 准备输入数据
        let inputData = pcmData

        // 定义输入回调
        let inputProc: AudioConverterComplexInputDataProc = { (
            converter,
            ioNumberDataPackets,
            ioData,
            outDataPacketDescription,
            inUserData
        ) -> OSStatus in

            guard let userDataPtr = inUserData else { return -1 }
            let inputDataPtr = userDataPtr.assumingMemoryBound(to: Data.self)
            let inputData = inputDataPtr.pointee

            ioData.pointee.mNumberBuffers = 1
            ioData.pointee.mBuffers.mNumberChannels = 1
            ioData.pointee.mBuffers.mDataByteSize = UInt32(inputData.count)
            ioData.pointee.mBuffers.mData = UnsafeMutableRawPointer(mutating: (inputData as NSData).bytes)

            ioNumberDataPackets.pointee = UInt32(inputData.count / 2) // 16-bit samples

            return noErr
        }

        // 使用 withUnsafeMutableBytes 确保指针生命周期正确
        var finalOutputSize = 0
        var inputDataCopy = inputData
        let status = outputBuffer.withUnsafeMutableBytes { bufferPointer -> OSStatus in
            // 创建输出缓冲区列表
            var outputBufferList = AudioBufferList()
            outputBufferList.mNumberBuffers = 1
            outputBufferList.mBuffers.mNumberChannels = channels
            outputBufferList.mBuffers.mDataByteSize = UInt32(maxOutputSize)
            outputBufferList.mBuffers.mData = bufferPointer.baseAddress

            // 输入数据包描述
            var outputPacketDesc = AudioStreamPacketDescription()
            var ioOutputDataPacketSize: UInt32 = 1

            // 执行转换 - 使用 withUnsafeMutablePointer 来安全地传递 Data 指针
            let result = withUnsafeMutablePointer(to: &inputDataCopy) { dataPtr in
                AudioConverterFillComplexBuffer(
                    converter,
                    inputProc,
                    dataPtr,
                    &ioOutputDataPacketSize,
                    &outputBufferList,
                    &outputPacketDesc
                )
            }

            // 捕获输出大小
            finalOutputSize = Int(outputBufferList.mBuffers.mDataByteSize)
            return result
        }

        guard status == noErr else {
            print("[AACAudioEncoder] Encoding failed: \(status)")
            return nil
        }

        return Data(bytes: outputBuffer, count: finalOutputSize)
    }

    deinit {
        if let converter = converter {
            AudioConverterDispose(converter)
        }
    }
}

/// AAC 音频解码器
class AACAudioDecoder {

    private var converter: AudioConverterRef?
    private let inputFormat: AudioStreamBasicDescription
    private let outputFormat: AudioStreamBasicDescription

    private let sampleRate: Double = 16000
    private let channels: UInt32 = 1

    init?() {
        // 输入格式：AAC
        var inputDesc = AudioStreamBasicDescription()
        inputDesc.mSampleRate = sampleRate
        inputDesc.mFormatID = kAudioFormatMPEG4AAC
        inputDesc.mChannelsPerFrame = channels
        inputDesc.mFramesPerPacket = 1024

        // 输出格式：PCM Int16, 16kHz, 单声道
        var outputDesc = AudioStreamBasicDescription()
        outputDesc.mSampleRate = sampleRate
        outputDesc.mFormatID = kAudioFormatLinearPCM
        outputDesc.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
        outputDesc.mBitsPerChannel = 16
        outputDesc.mChannelsPerFrame = channels
        outputDesc.mBytesPerFrame = channels * 2
        outputDesc.mFramesPerPacket = 1
        outputDesc.mBytesPerPacket = outputDesc.mBytesPerFrame * outputDesc.mFramesPerPacket

        self.inputFormat = inputDesc
        self.outputFormat = outputDesc

        // 创建转换器
        var converterRef: AudioConverterRef?
        let status = AudioConverterNew(&inputDesc, &outputDesc, &converterRef)

        guard status == noErr, let converter = converterRef else {
            print("[AACAudioDecoder] Failed to create converter: \(status)")
            return nil
        }

        self.converter = converter
        print("[AACAudioDecoder] Initialized successfully")
    }

    /// 解码 AAC 数据为 PCM
    func decode(aacData: Data) -> Data? {
        guard let converter = converter else { return nil }

        let maxOutputSize = aacData.count * 4 // PCM 通常更大
        var outputBuffer = [UInt8](repeating: 0, count: maxOutputSize)

        // 准备输入数据
        let inputData = aacData

        // 定义输入回调
        let inputProc: AudioConverterComplexInputDataProc = { (
            converter,
            ioNumberDataPackets,
            ioData,
            outDataPacketDescription,
            inUserData
        ) -> OSStatus in

            guard let userDataPtr = inUserData else { return -1 }
            let inputDataPtr = userDataPtr.assumingMemoryBound(to: Data.self)
            let inputData = inputDataPtr.pointee

            ioData.pointee.mNumberBuffers = 1
            ioData.pointee.mBuffers.mNumberChannels = 1
            ioData.pointee.mBuffers.mDataByteSize = UInt32(inputData.count)
            ioData.pointee.mBuffers.mData = UnsafeMutableRawPointer(mutating: (inputData as NSData).bytes)

            ioNumberDataPackets.pointee = 1 // AAC packets

            return noErr
        }

        // 使用 withUnsafeMutableBytes 确保指针生命周期正确
        var finalOutputSize = 0
        var inputDataCopy = inputData
        let status = outputBuffer.withUnsafeMutableBytes { bufferPointer -> OSStatus in
            // 创建输出缓冲区列表
            var outputBufferList = AudioBufferList()
            outputBufferList.mNumberBuffers = 1
            outputBufferList.mBuffers.mNumberChannels = channels
            outputBufferList.mBuffers.mDataByteSize = UInt32(maxOutputSize)
            outputBufferList.mBuffers.mData = bufferPointer.baseAddress

            var ioOutputDataPacketSize: UInt32 = UInt32(maxOutputSize / 2) // 采样点数

            // 执行转换 - 使用 withUnsafeMutablePointer 来安全地传递 Data 指针
            let result = withUnsafeMutablePointer(to: &inputDataCopy) { dataPtr in
                AudioConverterFillComplexBuffer(
                    converter,
                    inputProc,
                    dataPtr,
                    &ioOutputDataPacketSize,
                    &outputBufferList,
                    nil
                )
            }

            // 捕获输出大小
            finalOutputSize = Int(outputBufferList.mBuffers.mDataByteSize)
            return result
        }

        guard status == noErr else {
            print("[AACAudioDecoder] Decoding failed: \(status)")
            return nil
        }

        return Data(bytes: outputBuffer, count: finalOutputSize)
    }

    deinit {
        if let converter = converter {
            AudioConverterDispose(converter)
        }
    }
}
