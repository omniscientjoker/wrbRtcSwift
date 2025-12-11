@preconcurrency import Foundation

// MARK: - Device Models

/// 设备信息
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

/// 设备状态
enum DeviceStatus: String, Codable {
    case online = "online"
    case offline = "offline"

    var displayText: String {
        switch self {
        case .online: return "在线"
        case .offline: return "离线"
        }
    }

    var color: String {
        switch self {
        case .online: return "green"
        case .offline: return "gray"
        }
    }
}

/// 设备列表响应
struct DeviceListResponse: Codable, Sendable {
    let devices: [Device]
    let count: Int
}

// MARK: - Video Models

/// 直播流响应
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

/// 录像信息
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

    /// 格式化的时长
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

    /// 格式化的文件大小
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

/// 录像列表响应
struct PlaybackListResponse: Codable, Sendable {
    let recordings: [Recording]
    let count: Int
}

/// 转码响应
struct TranscodeResponse: Codable, Sendable {
    let success: Bool
    let deviceId: String
    let hlsUrl: String
}

// MARK: - Intercom Models

/// 对讲状态
enum IntercomStatus: Equatable {
    case idle
    case connecting
    case connected
    case speaking
    case error(String)

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

/// 在线设备
struct OnlineDevice: Codable, Identifiable, Hashable, @unchecked Sendable {
    let deviceId: String
    let status: String
    let name: String

    var id: String { deviceId }
}

/// 在线设备列表响应
struct OnlineDevicesResponse: Codable, Sendable {
    let devices: [OnlineDevice]
    let count: Int
}
