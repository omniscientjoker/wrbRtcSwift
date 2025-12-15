//
//  ServerDiscoveryService.swift
//  SimpleEyes
//
//  局域网服务器发现服务 - 自动扫描发现可用的服务器
//  使用并发扫描和健康检查机制
//

import Foundation
import Combine

/// 发现的服务器信息
///
/// 表示扫描发现的服务器详细信息
struct DiscoveredServer: Identifiable, Hashable {
    let id = UUID()
    let host: String
    let port: Int
    let apiURL: String
    let wsURL: String
    let name: String

    var displayName: String {
        "\(name) (\(host):\(port))"
    }
}
