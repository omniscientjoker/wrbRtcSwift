//
//  NetworkServiceV2.swift
//  SimpleEyes
//
//  增强版网络服务 - 支持响应链、token 管理、日志、防抖、缓存等功能
//  这是一个功能完整的网络请求库，可以灵活配置各种请求选项
//

@preconcurrency import Foundation
@preconcurrency import Alamofire

// MARK: - Network Service V2

/// 增强版网络服务
///
/// 提供功能丰富的网络请求能力，支持：
/// - 自动刷新 token
/// - 请求/响应拦截器
/// - 请求日志记录
/// - 防抖和节流
/// - 响应缓存
/// - 自动重试
/// - 自定义请求头
///
/// ## 使用示例
/// ```swift
/// // 基础使用
/// let service = NetworkServiceV2.shared
///
/// // 配置请求
/// let config = NetworkRequestConfig.builder()
///     .requiresAuth(true)
///     .enableLogging(true)
///     .enableCache(true, ttl: 300)
///     .build()
///
/// // 发起请求
/// try await service.request(
///     url: "https://api.example.com/users",
///     method: .get,
///     config: config
/// )
/// ```
actor NetworkService {
    /// 单例实例
    static let shared = NetworkService()

    // MARK: - Configuration

    /// 默认 token 存储键
    private let tokenKey = "auth_token"

    /// 防抖任务管理
    private var debounceTasks: [String: Task<Data, Error>] = [:]

    /// 缓存管理器
    private let cache = NetworkCache.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Request Methods

    /// 发起网络请求
    ///
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - method: HTTP 方法
    ///   - parameters: 请求参数
    ///   - encoding: 参数编码方式
    ///   - config: 请求配置
    /// - Returns: 响应数据
    func request(
        url: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        encoding: ParameterEncoding = JSONEncoding.default,
        config: NetworkRequestConfig = .default
    ) async throws -> Data {
        // 检查防抖
        if config.enableDebounce {
            return try await debounceRequest(
                url: url,
                method: method,
                parameters: parameters,
                encoding: encoding,
                config: config
            )
        }

        // 检查缓存
        if config.enableCache, method == .get {
            if let cachedData = try await checkCache(url: url, parameters: parameters, config: config) {
                return cachedData
            }
        }

        // 执行请求
        return try await performRequest(
            url: url,
            method: method,
            parameters: parameters,
            encoding: encoding,
            config: config
        )
    }

    /// 发起网络请求并解码为指定类型
    ///
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - method: HTTP 方法
    ///   - parameters: 请求参数
    ///   - responseType: 响应类型
    ///   - encoding: 参数编码方式
    ///   - config: 请求配置
    /// - Returns: 解码后的响应对象
    func request<T: Decodable>(
        url: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        responseType: T.Type,
        encoding: ParameterEncoding = JSONEncoding.default,
        config: NetworkRequestConfig = .default
    ) async throws -> T {
        let data = try await request(
            url: url,
            method: method,
            parameters: parameters,
            encoding: encoding,
            config: config
        )

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Private Methods

    /// 执行实际的网络请求
    private func performRequest(
        url: String,
        method: HTTPMethod,
        parameters: [String: Any]?,
        encoding: ParameterEncoding,
        config: NetworkRequestConfig,
        retryCount: Int = 0
    ) async throws -> Data {
        // 创建初始请求
        var urlRequest = try URLRequest(url: url, method: method, headers: nil)
        urlRequest.timeoutInterval = config.timeout

        // 应用参数编码
        if let parameters = parameters {
            urlRequest = try encoding.encode(urlRequest, with: parameters)
        }

        // 应用请求拦截器
        urlRequest = try await applyRequestInterceptors(urlRequest, config: config)

        // 发送请求
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            // 应用响应拦截器
            let (processedData, processedResponse) = try await applyResponseInterceptors(
                data: data,
                response: response,
                error: nil,
                config: config
            )

            // 如果拦截器返回 nil，表示需要重试（例如 token 刷新后）
            if processedData == nil {
                return try await performRequest(
                    url: url,
                    method: method,
                    parameters: parameters,
                    encoding: encoding,
                    config: config,
                    retryCount: retryCount + 1
                )
            }

            guard let finalData = processedData else {
                throw NetworkError.unknown((processedResponse as? HTTPURLResponse)?.statusCode ?? -1)
            }

            // 缓存响应
            if config.enableCache, method == .get {
                await storeCache(data: finalData, url: url, parameters: parameters, config: config)
            }

            return finalData

        } catch {
            // 应用响应拦截器（处理错误）
            let (processedData, _) = try await applyResponseInterceptors(
                data: nil,
                response: nil,
                error: error,
                config: config
            )

            // 如果拦截器返回了数据，使用它
            if let data = processedData {
                return data
            }

            // 自动重试
            if config.autoRetry, retryCount < config.maxRetryCount {
                NetworkLogger.log("Retrying request (\(retryCount + 1)/\(config.maxRetryCount))...", level: .info)
                try await Task.sleep(nanoseconds: UInt64(config.retryDelay * 1_000_000_000))

                return try await performRequest(
                    url: url,
                    method: method,
                    parameters: parameters,
                    encoding: encoding,
                    config: config,
                    retryCount: retryCount + 1
                )
            }

            throw error
        }
    }

    /// 应用请求拦截器
    private func applyRequestInterceptors(_ request: URLRequest, config: NetworkRequestConfig) async throws -> URLRequest {
        var modifiedRequest = request

        // 应用 Content-Type
        if config.includeContentType {
            let contentTypeInterceptor = ContentTypeInterceptor()
            modifiedRequest = try await contentTypeInterceptor.intercept(request: modifiedRequest)
        }

        // 应用自定义请求头
        if !config.customHeaders.isEmpty {
            let headerInterceptor = CustomHeaderInterceptor(headers: config.customHeaders)
            modifiedRequest = try await headerInterceptor.intercept(request: modifiedRequest)
        }

        // 应用 Token
        if config.requiresAuth {
            let tokenProvider = config.tokenProvider ?? {
                UserDefaults.standard.string(forKey: "auth_token")
            }
            let tokenInterceptor = TokenInterceptor(tokenProvider: tokenProvider)
            modifiedRequest = try await tokenInterceptor.intercept(request: modifiedRequest)
        }

        // 应用日志
        if config.enableLogging {
            let loggingInterceptor = LoggingInterceptor(logLevel: config.logLevel)
            modifiedRequest = try await loggingInterceptor.intercept(request: modifiedRequest)
        }

        // 应用自定义拦截器
        for interceptor in config.requestInterceptors {
            modifiedRequest = try await interceptor.intercept(request: modifiedRequest)
        }

        return modifiedRequest
    }

    /// 应用响应拦截器
    private func applyResponseInterceptors(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        config: NetworkRequestConfig
    ) async throws -> (Data?, URLResponse?) {
        var currentData = data
        var currentResponse = response
        let currentError = error

        // 应用错误处理拦截器
        let errorInterceptor = ErrorHandlingInterceptor()
        (currentData, currentResponse) = try await errorInterceptor.intercept(
            data: currentData,
            response: currentResponse,
            error: currentError
        )

        // 应用 Token 刷新拦截器
        if config.autoRefreshToken {
            let refreshInterceptor = TokenRefreshInterceptor(
                tokenRefresher: { [weak self] in
                    try await self?.refreshToken() ?? ""
                },
                tokenSaver: { [weak self] newToken in
                    Task {
                        await self?.saveToken(newToken)
                    }
                }
            )
            (currentData, currentResponse) = try await refreshInterceptor.intercept(
                data: currentData,
                response: currentResponse,
                error: currentError
            )
        }

        // 应用日志
        if config.enableLogging {
            let loggingInterceptor = LoggingInterceptor(logLevel: config.logLevel)
            (currentData, currentResponse) = try await loggingInterceptor.intercept(
                data: currentData,
                response: currentResponse,
                error: currentError
            )
        }

        // 应用自定义拦截器
        for interceptor in config.responseInterceptors {
            (currentData, currentResponse) = try await interceptor.intercept(
                data: currentData,
                response: currentResponse,
                error: currentError
            )
        }

        return (currentData, currentResponse)
    }

    // MARK: - Debounce

    /// 防抖请求
    private func debounceRequest(
        url: String,
        method: HTTPMethod,
        parameters: [String: Any]?,
        encoding: ParameterEncoding,
        config: NetworkRequestConfig
    ) async throws -> Data {
        let debounceKey = config.debounceKey ?? "\(url)_\(method.rawValue)"

        // 取消之前的任务
        debounceTasks[debounceKey]?.cancel()

        // 创建新任务
        let task = Task<Data, Error> {
            // 等待防抖延迟
            try await Task.sleep(nanoseconds: UInt64(config.debounceDelay * 1_000_000_000))

            // 执行请求
            return try await performRequest(
                url: url,
                method: method,
                parameters: parameters,
                encoding: encoding,
                config: config
            )
        }

        debounceTasks[debounceKey] = task

        do {
            let data = try await task.value
            debounceTasks.removeValue(forKey: debounceKey)
            return data
        } catch {
            debounceTasks.removeValue(forKey: debounceKey)
            throw error
        }
    }

    // MARK: - Cache

    /// 检查缓存
    private func checkCache(url: String, parameters: [String: Any]?, config: NetworkRequestConfig) async throws -> Data? {
        let cacheKey = config.cacheKey ?? generateCacheKey(url: url, parameters: parameters)

        switch config.cachePolicy {
        case .networkOnly:
            return nil

        case .cacheOnly:
            if let data = await cache.retrieve(forKey: cacheKey) {
                NetworkLogger.log("Using cached data (cache-only)", level: .debug)
                return data
            }
            throw NetworkError.noInternet // 缓存不存在时抛出错误

        case .cacheFirst:
            if let data = await cache.retrieve(forKey: cacheKey) {
                NetworkLogger.log("Using cached data (cache-first)", level: .debug)
                return data
            }
            return nil // 继续网络请求

        case .networkFirst:
            return nil // 优先网络请求
        }
    }

    /// 存储缓存
    private func storeCache(data: Data, url: String, parameters: [String: Any]?, config: NetworkRequestConfig) async {
        let cacheKey = config.cacheKey ?? generateCacheKey(url: url, parameters: parameters)
        await cache.store(data: data, forKey: cacheKey, ttl: config.cacheTTL)
    }

    /// 生成缓存键
    private func generateCacheKey(url: String, parameters: [String: Any]?) -> String {
        var key = url

        if let parameters = parameters, !parameters.isEmpty {
            // 将参数排序后拼接
            let sortedParams = parameters.sorted { $0.key < $1.key }
            let paramString = sortedParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            key += "?\(paramString)"
        }

        return key
    }

    // MARK: - Token Management

    /// 获取当前 token
    private func getToken() -> String? {
        return UserDefaults.standard.string(forKey: tokenKey)
    }

    /// 保存 token
    private func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
    }

    /// 刷新 token
    ///
    /// 这里需要根据实际的 API 实现
    private func refreshToken() async throws -> String {
        // TODO: 实现实际的 token 刷新逻辑
        // 这里应该调用你的刷新 token API

        NetworkLogger.log("Token refresh not implemented", level: .warning)
        throw NetworkError.unauthorized
    }

    // MARK: - Cache Management

    /// 清空缓存
    func clearCache() async {
        await cache.clear()
    }

    /// 获取缓存统计信息
    func cacheStatistics() async -> CacheStatistics {
        return await cache.statistics()
    }
}
