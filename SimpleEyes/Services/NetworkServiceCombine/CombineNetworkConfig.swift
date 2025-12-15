//
//  CombineNetworkConfig.swift
//  SimpleEyes
//
//  Combine 网络服务 - 请求配置
//

import Foundation

// MARK: - Log Level

/// 日志级别
enum CombineLogLevel: Int {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case none = 999

    var prefix: String {
        switch self {
        case .debug: return "🔍 [DEBUG]"
        case .info: return "ℹ️ [INFO]"
        case .warning: return "⚠️ [WARNING]"
        case .error: return "❌ [ERROR]"
        case .none: return ""
        }
    }
}

// MARK: - Request Config

/// Combine 网络请求配置
struct CombineNetworkConfig {
    // MARK: - Properties

    /// 是否需要认证
    var requiresAuth: Bool

    /// 是否启用日志
    var enableLogging: Bool

    /// 日志级别
    var logLevel: CombineLogLevel

    /// 是否自动刷新 Token
    var autoRefreshToken: Bool

    /// 是否自动重试
    var autoRetry: Bool

    /// 最大重试次数
    var maxRetryCount: Int

    /// 重试延迟（秒）
    var retryDelay: TimeInterval

    /// 请求超时时间（秒）
    var timeout: TimeInterval

    /// 自定义请求头
    var customHeaders: [String: String]

    // MARK: - Initialization

    init(
        requiresAuth: Bool = false,
        enableLogging: Bool = true,
        logLevel: CombineLogLevel = .info,
        autoRefreshToken: Bool = true,
        autoRetry: Bool = true,
        maxRetryCount: Int = 3,
        retryDelay: TimeInterval = 1.0,
        timeout: TimeInterval = 30.0,
        customHeaders: [String: String] = [:]
    ) {
        self.requiresAuth = requiresAuth
        self.enableLogging = enableLogging
        self.logLevel = logLevel
        self.autoRefreshToken = autoRefreshToken
        self.autoRetry = autoRetry
        self.maxRetryCount = maxRetryCount
        self.retryDelay = retryDelay
        self.timeout = timeout
        self.customHeaders = customHeaders
    }

    // MARK: - Default Configs

    /// 默认配置
    static let `default` = CombineNetworkConfig()

    /// 需要认证的配置
    static let authenticated = CombineNetworkConfig(requiresAuth: true)

    /// 静默请求（无日志）
    static let silent = CombineNetworkConfig(
        enableLogging: false,
        logLevel: .none
    )

    /// 长时间请求（上传/下载）
    static let longRunning = CombineNetworkConfig(
        timeout: 120.0
    )
}

// MARK: - Builder Pattern

extension CombineNetworkConfig {
    /// 配置构建器
    class Builder {
        private var config = CombineNetworkConfig()

        func requiresAuth(_ value: Bool) -> Builder {
            config.requiresAuth = value
            return self
        }

        func enableLogging(_ value: Bool, level: CombineLogLevel = .info) -> Builder {
            config.enableLogging = value
            config.logLevel = level
            return self
        }

        func autoRefreshToken(_ value: Bool) -> Builder {
            config.autoRefreshToken = value
            return self
        }

        func autoRetry(_ value: Bool, maxCount: Int = 3, delay: TimeInterval = 1.0) -> Builder {
            config.autoRetry = value
            config.maxRetryCount = maxCount
            config.retryDelay = delay
            return self
        }

        func timeout(_ value: TimeInterval) -> Builder {
            config.timeout = value
            return self
        }

        func customHeaders(_ headers: [String: String]) -> Builder {
            config.customHeaders = headers
            return self
        }

        func build() -> CombineNetworkConfig {
            return config
        }
    }

    /// 创建构建器
    static func builder() -> Builder {
        return Builder()
    }
}
