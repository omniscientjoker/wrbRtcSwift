//
//  NetworkRequestConfig.swift
//  SimpleEyes
//
//  网络请求配置 - 定义请求的各种配置选项
//  支持自动刷新 token、请求头配置、日志、防抖、缓存等功能
//

import Foundation

// MARK: - Network Request Configuration

/// 网络请求配置
///
/// 提供灵活的请求配置选项，支持响应链、token 管理、日志、防抖、缓存等功能
///
/// ## 使用示例
/// ```swift
/// let config = NetworkRequestConfig.builder()
///     .requiresAuth(true)
///     .enableLogging(true)
///     .enableCache(true, ttl: 300)
///     .build()
/// ```
struct NetworkRequestConfig {
    // MARK: - Authentication

    /// 是否需要在请求头中添加 token
    var requiresAuth: Bool

    /// 自定义 token 获取方式（如果不设置则使用默认方式）
    var tokenProvider: (() -> String?)?

    /// 是否自动刷新过期的 token
    var autoRefreshToken: Bool

    // MARK: - Headers

    /// 自定义请求头
    var customHeaders: [String: String]

    /// 是否添加默认的 Content-Type
    var includeContentType: Bool

    // MARK: - Logging

    /// 是否记录请求日志
    var enableLogging: Bool

    /// 日志级别
    var logLevel: LogLevel

    // MARK: - Debounce & Throttle

    /// 是否启用防抖（防止短时间内重复请求）
    var enableDebounce: Bool

    /// 防抖延迟时间（秒）
    var debounceDelay: TimeInterval

    /// 防抖键（用于标识相同的请求）
    var debounceKey: String?

    // MARK: - Cache

    /// 是否启用缓存
    var enableCache: Bool

    /// 缓存有效期（秒）
    var cacheTTL: TimeInterval

    /// 缓存键（用于标识缓存）
    var cacheKey: String?

    /// 缓存策略
    var cachePolicy: CachePolicy

    // MARK: - Retry & Timeout

    /// 请求超时时间（秒）
    var timeout: TimeInterval

    /// 是否自动重试失败的请求
    var autoRetry: Bool

    /// 最大重试次数
    var maxRetryCount: Int

    /// 重试延迟时间（秒）
    var retryDelay: TimeInterval

    // MARK: - Interceptors

    /// 请求拦截器（在发送请求前执行）
    var requestInterceptors: [RequestInterceptor]

    /// 响应拦截器（在收到响应后执行）
    var responseInterceptors: [ResponseInterceptor]

    // MARK: - Initialization

    /// 默认配置
    static let `default` = NetworkRequestConfig(
        requiresAuth: false,
        tokenProvider: nil,
        autoRefreshToken: false,
        customHeaders: [:],
        includeContentType: true,
        enableLogging: false,
        logLevel: .info,
        enableDebounce: false,
        debounceDelay: 0.3,
        debounceKey: nil,
        enableCache: false,
        cacheTTL: 300,
        cacheKey: nil,
        cachePolicy: .networkFirst,
        timeout: 30,
        autoRetry: false,
        maxRetryCount: 3,
        retryDelay: 1.0,
        requestInterceptors: [],
        responseInterceptors: []
    )

    // MARK: - Builder Pattern

    /// 配置构建器
    ///
    /// 使用链式调用创建配置对象
    class Builder {
        private var config = NetworkRequestConfig.default

        /// 设置是否需要认证
        func requiresAuth(_ value: Bool) -> Builder {
            config.requiresAuth = value
            return self
        }

        /// 设置 token 提供者
        func tokenProvider(_ provider: @escaping () -> String?) -> Builder {
            config.tokenProvider = provider
            return self
        }

        /// 设置是否自动刷新 token
        func autoRefreshToken(_ value: Bool) -> Builder {
            config.autoRefreshToken = value
            return self
        }

        /// 添加自定义请求头
        func addHeader(key: String, value: String) -> Builder {
            config.customHeaders[key] = value
            return self
        }

        /// 批量添加自定义请求头
        func addHeaders(_ headers: [String: String]) -> Builder {
            config.customHeaders.merge(headers) { _, new in new }
            return self
        }

        /// 设置是否包含 Content-Type
        func includeContentType(_ value: Bool) -> Builder {
            config.includeContentType = value
            return self
        }

        /// 设置是否启用日志
        func enableLogging(_ value: Bool, level: LogLevel = .info) -> Builder {
            config.enableLogging = value
            config.logLevel = level
            return self
        }

        /// 设置防抖
        func enableDebounce(_ value: Bool, delay: TimeInterval = 0.3, key: String? = nil) -> Builder {
            config.enableDebounce = value
            config.debounceDelay = delay
            config.debounceKey = key
            return self
        }

        /// 设置缓存
        func enableCache(_ value: Bool, ttl: TimeInterval = 300, key: String? = nil, policy: CachePolicy = .networkFirst) -> Builder {
            config.enableCache = value
            config.cacheTTL = ttl
            config.cacheKey = key
            config.cachePolicy = policy
            return self
        }

        /// 设置超时时间
        func timeout(_ seconds: TimeInterval) -> Builder {
            config.timeout = seconds
            return self
        }

        /// 设置自动重试
        func autoRetry(_ value: Bool, maxCount: Int = 3, delay: TimeInterval = 1.0) -> Builder {
            config.autoRetry = value
            config.maxRetryCount = maxCount
            config.retryDelay = delay
            return self
        }

        /// 添加请求拦截器
        func addRequestInterceptor(_ interceptor: RequestInterceptor) -> Builder {
            config.requestInterceptors.append(interceptor)
            return self
        }

        /// 添加响应拦截器
        func addResponseInterceptor(_ interceptor: ResponseInterceptor) -> Builder {
            config.responseInterceptors.append(interceptor)
            return self
        }

        /// 构建配置对象
        func build() -> NetworkRequestConfig {
            return config
        }
    }

    /// 创建配置构建器
    static func builder() -> Builder {
        return Builder()
    }
}

// MARK: - Enums

/// 日志级别
enum LogLevel: Int {
    /// 详细日志（包含请求和响应的完整信息）
    case verbose = 0
    /// 调试日志（包含关键信息）
    case debug = 1
    /// 信息日志（只记录基本信息）
    case info = 2
    /// 警告日志（只记录警告和错误）
    case warning = 3
    /// 错误日志（只记录错误）
    case error = 4
    /// 不记录日志
    case none = 5
}

/// 缓存策略
enum CachePolicy {
    /// 优先使用网络，失败时使用缓存
    case networkFirst
    /// 优先使用缓存，缓存不存在时使用网络
    case cacheFirst
    /// 只使用网络，不使用缓存
    case networkOnly
    /// 只使用缓存，缓存不存在时失败
    case cacheOnly
}

// MARK: - Predefined Configurations

extension NetworkRequestConfig {
    /// 需要认证的请求配置
    static var authenticated: NetworkRequestConfig {
        builder()
            .requiresAuth(true)
            .autoRefreshToken(true)
            .enableLogging(true, level: .info)
            .autoRetry(true, maxCount: 2)
            .build()
    }

    /// 公开 API 请求配置
    static var `public`: NetworkRequestConfig {
        builder()
            .requiresAuth(false)
            .enableLogging(true, level: .info)
            .build()
    }

    /// 带缓存的请求配置
    static var cached: NetworkRequestConfig {
        builder()
            .enableCache(true, ttl: 300, policy: .cacheFirst)
            .enableLogging(true, level: .debug)
            .build()
    }

    /// 防抖请求配置（适用于搜索等场景）
    static var debounced: NetworkRequestConfig {
        builder()
            .enableDebounce(true, delay: 0.5)
            .enableLogging(true, level: .debug)
            .build()
    }
}
