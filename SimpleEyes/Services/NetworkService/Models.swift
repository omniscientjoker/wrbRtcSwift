//
//  Models.swift
//  SimpleEyes
//
//  数据模型定义 - 定义所有与后端 API 交互的数据结构
//  包括设备、视频、对讲等相关模型
//

@preconcurrency import Foundation

// MARK: - Device Models

/// 设备信息模型
///
/// 表示一个物联网设备的完整信息，包括基本属性、状态和时间戳
///
/// ## 属性说明
/// - `deviceId`: 设备的唯一标识符
/// - `name`: 设备名称（用户可自定义）
/// - `model`: 设备型号
/// - `type`: 设备类型（可选）
/// - `status`: 设备当前状态（在线/离线）
/// - `registeredAt`: 设备注册时间
/// - `lastHeartbeat`: 最后一次心跳时间
/// - `updateAt`: 最后更新时间（可选）
struct Device: Codable, Identifiable, @unchecked Sendable {
    let deviceId: String
    let name: String
    let model: String
    let type: String?
    let status: DeviceStatus
    let registeredAt: Date
    let lastHeartbeat: Date
    let updateAt: Date?

    var id: String { deviceId }

    enum CodingKeys: String, CodingKey {
        case deviceId, name, model, type, status
        case registeredAt, lastHeartbeat, updateAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        name = try container.decode(String.self, forKey: .name)
        model = try container.decode(String.self, forKey: .model)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        status = try container.decode(DeviceStatus.self, forKey: .status)

        // 日期解析
        let dateFormatter = ISO8601DateFormatter()

        let registeredAtString = try container.decode(String.self, forKey: .registeredAt)
        registeredAt = dateFormatter.date(from: registeredAtString) ?? Date()

        let lastHeartbeatString = try container.decode(String.self, forKey: .lastHeartbeat)
        lastHeartbeat = dateFormatter.date(from: lastHeartbeatString) ?? Date()

        if let updateAtString = try? container.decode(String.self, forKey: .updateAt) {
            updateAt = dateFormatter.date(from: updateAtString)
        } else {
            updateAt = nil
        }
    }
}

/// 设备状态枚举
///
/// 定义设备的在线状态
enum DeviceStatus: String, Codable {
    /// 设备在线
    case online = "online"
    /// 设备离线
    case offline = "offline"

    /// 状态的显示文本
    var displayText: String {
        switch self {
        case .online: return "在线"
        case .offline: return "离线"
        }
    }

    /// 状态对应的颜色标识
    var color: String {
        switch self {
        case .online: return "green"
        case .offline: return "gray"
        }
    }
}

/// 设备列表响应模型
///
/// API 返回的设备列表数据结构
struct DeviceListResponse: Codable, Sendable {
    /// 设备数组
    let devices: [Device]
    /// 设备总数
    let count: Int
}

// MARK: - Video Models

/// 直播流响应模型
///
/// 包含设备直播流的协议、URL 和状态信息
struct LiveStreamResponse: Codable, Sendable {
    let deviceId: String
    let streamProtocol: String
    let url: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case deviceId
        case streamProtocol = "protocol"
        case url
        case status
    }
}

/// 录像信息模型
///
/// 表示一段录像文件的详细信息
///
/// ## 属性说明
/// - `id`: 录像唯一标识符
/// - `deviceId`: 所属设备ID
/// - `startTime`: 录像开始时间
/// - `endTime`: 录像结束时间
/// - `duration`: 录像时长（秒）
/// - `size`: 文件大小（字节）
/// - `url`: 录像播放地址
struct Recording: Codable, Identifiable, @unchecked Sendable {
    let id: String
    let deviceId: String
    let startTime: Date
    let endTime: Date
    let duration: Int // 秒
    let size: Int64   // 字节
    let url: String

    enum CodingKeys: String, CodingKey {
        case id, deviceId, startTime, endTime, duration, size, url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        duration = try container.decode(Int.self, forKey: .duration)
        size = try container.decode(Int64.self, forKey: .size)
        url = try container.decode(String.self, forKey: .url)

        // 日期解析
        let dateFormatter = ISO8601DateFormatter()

        let startTimeString = try container.decode(String.self, forKey: .startTime)
        startTime = dateFormatter.date(from: startTimeString) ?? Date()

        let endTimeString = try container.decode(String.self, forKey: .endTime)
        endTime = dateFormatter.date(from: endTimeString) ?? Date()
    }

    /// 格式化的时长字符串
    ///
    /// - Returns: 格式化后的时长 (例如: "01:23:45" 或 "23:45")
    var formattedDuration: String {
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// 格式化的文件大小字符串
    ///
    /// - Returns: 人类可读的文件大小 (例如: "125.6 MB")
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

/// 录像列表响应模型
///
/// API 返回的录像列表数据结构
struct PlaybackListResponse: Codable, Sendable {
    let recordings: [Recording]
    let count: Int
}

/// 转码响应模型
///
/// 视频转码任务的结果信息
struct TranscodeResponse: Codable, Sendable {
    /// 转码是否成功
    let success: Bool
    /// 设备ID
    let deviceId: String
    /// HLS 流地址
    let hlsUrl: String
}

// MARK: - Intercom Models

/// 对讲状态枚举
///
/// 定义对讲功能的各种状态
enum IntercomStatus: Equatable {
    /// 空闲状态
    case idle
    /// 正在连接
    case connecting
    /// 已连接
    case connected
    /// 正在对讲
    case speaking
    /// 错误状态（附带错误消息）
    case error(String)

    /// 状态的显示文本
    var displayText: String {
        switch self {
        case .idle: return "空闲"
        case .connecting: return "连接中..."
        case .connected: return "已连接"
        case .speaking: return "对讲中"
        case .error(let message): return "错误: \(message)"
        }
    }
}

// MARK: - Online Device Models

/// 在线设备模型
///
/// 表示当前在线的设备信息（简化版）
struct OnlineDevice: Codable, Identifiable, Hashable, @unchecked Sendable {
    let deviceId: String
    let status: String
    let name: String

    var id: String { deviceId }
}

/// 在线设备列表响应模型
///
/// API 返回的在线设备列表数据结构
struct OnlineDevicesResponse: Codable, Sendable {
    let devices: [OnlineDevice]
    let count: Int
}
