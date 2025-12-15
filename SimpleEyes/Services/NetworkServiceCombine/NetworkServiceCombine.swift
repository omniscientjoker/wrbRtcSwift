//
//  NetworkServiceCombine.swift
//  SimpleEyes
//
//  Combine 网络服务 - 主服务实现
//  支持 Token 刷新、自动重试、日志记录、类型安全的数据解析
//

import Foundation
import Combine

// MARK: - HTTP Method

/// HTTP 请求方法
enum CombineHTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

// MARK: - Network Service Combine

/// Combine 网络服务
///
/// 功能特性：
/// - ✅ Token 自动刷新并重试
/// - ✅ 自动重试失败请求
/// - ✅ 完整的日志记录
/// - ✅ 类型安全的数据解析
/// - ✅ 响应式编程支持
///
/// ## 使用示例
/// ```swift
/// // 1. 简单请求
/// NetworkServiceCombine.shared
///     .request(
///         url: "https://api.example.com/users",
///         method: .get,
///         responseType: [User].self
///     )
///     .sink(
///         receiveCompletion: { completion in
///             if case .failure(let error) = completion {
///                 print("Error: \(error)")
///             }
///         },
///         receiveValue: { users in
///             print("Users: \(users)")
///         }
///     )
///     .store(in: &cancellables)
///
/// // 2. 需要认证的请求
/// let config = CombineNetworkConfig.builder()
///     .requiresAuth(true)
///     .autoRefreshToken(true)
///     .build()
///
/// NetworkServiceCombine.shared
///     .request(
///         url: "https://api.example.com/profile",
///         method: .get,
///         responseType: UserProfile.self,
///         config: config
///     )
///     .sink(...)
///     .store(in: &cancellables)
/// ```
class NetworkServiceCombine {
    // MARK: - Singleton

    static let shared = NetworkServiceCombine()
    private init() {}

    // MARK: - Properties

    private let tokenManager = CombineTokenManager.shared

    // MARK: - Public Request Methods

    /// 发起网络请求并解码为指定类型
    ///
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - method: HTTP 方法
    ///   - parameters: 请求参数
    ///   - responseType: 响应数据类型
    ///   - config: 请求配置
    /// - Returns: Publisher，发送解码后的数据
    func request<T: Decodable>(
        url: String,
        method: CombineHTTPMethod = .get,
        parameters: [String: Any]? = nil,
        responseType: T.Type,
        config: CombineNetworkConfig = .default
    ) -> AnyPublisher<T, CombineNetworkError> {
        // 创建请求工厂（用于重试和 token 刷新）
        let requestFactory: () -> AnyPublisher<T, CombineNetworkError> = { [weak self] in
            guard let self = self else {
                return Fail(error: CombineNetworkError.unknown(
                    NSError(domain: "NetworkService", code: -1)
                )).eraseToAnyPublisher()
            }

            return self.performRequest(
                url: url,
                method: method,
                parameters: parameters,
                responseType: responseType,
                config: config
            )
        }

        return requestFactory()
            .autoRetry(config: config, requestFactory: requestFactory)
            .autoRefreshToken(config: config, requestFactory: requestFactory)
    }

    /// 发起网络请求并返回原始 Data
    ///
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - method: HTTP 方法
    ///   - parameters: 请求参数
    ///   - config: 请求配置
    /// - Returns: Publisher，发送原始数据
    func requestData(
        url: String,
        method: CombineHTTPMethod = .get,
        parameters: [String: Any]? = nil,
        config: CombineNetworkConfig = .default
    ) -> AnyPublisher<Data, CombineNetworkError> {
        let requestFactory: () -> AnyPublisher<Data, CombineNetworkError> = { [weak self] in
            guard let self = self else {
                return Fail(error: CombineNetworkError.unknown(
                    NSError(domain: "NetworkService", code: -1)
                )).eraseToAnyPublisher()
            }

            return self.performDataRequest(
                url: url,
                method: method,
                parameters: parameters,
                config: config
            )
        }

        return requestFactory()
            .autoRetry(config: config, requestFactory: requestFactory)
            .autoRefreshToken(config: config, requestFactory: requestFactory)
    }

    // MARK: - Private Methods

    /// 执行实际的网络请求（带解码）
    private func performRequest<T: Decodable>(
        url: String,
        method: CombineHTTPMethod,
        parameters: [String: Any]?,
        responseType: T.Type,
        config: CombineNetworkConfig
    ) -> AnyPublisher<T, CombineNetworkError> {
        return performDataRequest(
            url: url,
            method: method,
            parameters: parameters,
            config: config
        )
        .decode(type: T.self, decoder: JSONDecoder())
        .mapError { error -> CombineNetworkError in
            if let networkError = error as? CombineNetworkError {
                return networkError
            } else if error is DecodingError {
                CombineNetworkLogger.log("❌ Decoding failed: \(error)", level: .error)
                return .decodingError(error)
            } else {
                return .unknown(error)
            }
        }
        .eraseToAnyPublisher()
    }

    /// 执行实际的网络请求（返回 Data）
    private func performDataRequest(
        url: String,
        method: CombineHTTPMethod,
        parameters: [String: Any]?,
        config: CombineNetworkConfig
    ) -> AnyPublisher<Data, CombineNetworkError> {
        // 创建 URLRequest
        guard let urlRequest = createURLRequest(
            url: url,
            method: method,
            parameters: parameters,
            config: config
        ) else {
            return Fail(error: CombineNetworkError.invalidURL(url))
                .eraseToAnyPublisher()
        }

        // 记录请求日志
        if config.enableLogging {
            CombineNetworkLogger.logRequest(urlRequest, level: config.logLevel)
        }

        // 发起请求
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .timeout(
                .seconds(config.timeout),
                scheduler: DispatchQueue.main,
                customError: { CombineNetworkError.timeout }
            )
            .tryMap { [weak self] data, response -> Data in
                // 记录响应日志
                if config.enableLogging {
                    CombineNetworkLogger.logResponse(
                        data: data,
                        response: response,
                        error: nil,
                        level: config.logLevel
                    )
                }

                // 检查 HTTP 状态码
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw CombineNetworkError.invalidResponse
                }

                // 处理不同的状态码
                switch httpResponse.statusCode {
                case 200...299:
                    return data

                case 401:
                    throw CombineNetworkError.unauthorized

                default:
                    throw CombineNetworkError.httpError(
                        statusCode: httpResponse.statusCode,
                        data: data
                    )
                }
            }
            .mapError { error -> CombineNetworkError in
                // 记录错误日志
                if config.enableLogging {
                    CombineNetworkLogger.logError(error, level: .error)
                }

                if let networkError = error as? CombineNetworkError {
                    return networkError
                } else if let urlError = error as? URLError {
                    return .networkError(urlError)
                } else {
                    return .unknown(error)
                }
            }
            .eraseToAnyPublisher()
    }

    /// 创建 URLRequest
    private func createURLRequest(
        url: String,
        method: CombineHTTPMethod,
        parameters: [String: Any]?,
        config: CombineNetworkConfig
    ) -> URLRequest? {
        // 处理 GET 请求的查询参数
        var finalURL = url
        if method == .get, let parameters = parameters {
            let queryItems = parameters.map { key, value in
                URLQueryItem(name: key, value: "\(value)")
            }
            var urlComponents = URLComponents(string: url)
            urlComponents?.queryItems = queryItems
            finalURL = urlComponents?.url?.absoluteString ?? url
        }

        guard let requestURL = URL(string: finalURL) else {
            return nil
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method.rawValue
        request.timeoutInterval = config.timeout

        // 设置请求头
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // 添加认证 Token
        if config.requiresAuth, let token = tokenManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // 添加自定义请求头
        config.customHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // 处理请求体（非 GET 请求）
        if method != .get, let parameters = parameters {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: parameters)
                request.httpBody = jsonData
            } catch {
                CombineNetworkLogger.log("❌ Failed to encode parameters: \(error)", level: .error)
                return nil
            }
        }

        return request
    }
}

// MARK: - Publisher Extensions

extension Publisher {
    /// 自动重试失败的请求
    ///
    /// - Parameters:
    ///   - config: 网络配置
    ///   - requestFactory: 请求工厂闭包
    /// - Returns: 带重试功能的 Publisher
    func autoRetry(
        config: CombineNetworkConfig,
        requestFactory: @escaping () -> AnyPublisher<Output, Failure>
    ) -> AnyPublisher<Output, Failure> where Failure == CombineNetworkError {
        guard config.autoRetry else {
            return self.eraseToAnyPublisher()
        }

        return self.catch { error -> AnyPublisher<Output, Failure> in
            // 只重试可重试的错误
            guard error.shouldRetry else {
                return Fail(error: error).eraseToAnyPublisher()
            }

            CombineNetworkLogger.log(
                "🔄 Retrying request (max: \(config.maxRetryCount) times)",
                level: .info
            )

            return requestFactory()
                .retry(config.maxRetryCount)
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    /// 自动刷新 Token 并重试请求
    ///
    /// - Parameters:
    ///   - config: 网络配置
    ///   - requestFactory: 请求工厂闭包
    /// - Returns: 带 Token 刷新功能的 Publisher
    func autoRefreshToken(
        config: CombineNetworkConfig,
        requestFactory: @escaping () -> AnyPublisher<Output, Failure>
    ) -> AnyPublisher<Output, Failure> where Failure == CombineNetworkError {
        guard config.autoRefreshToken else {
            return self.eraseToAnyPublisher()
        }

        return self.catch { error -> AnyPublisher<Output, Failure> in
            // 检查是否是 Token 过期错误
            guard CombineNetworkError.isTokenExpiredError(error) else {
                return Fail(error: error).eraseToAnyPublisher()
            }

            CombineNetworkLogger.log("🔄 Token expired, refreshing...", level: .info)

            // 刷新 Token 并重试
            return CombineTokenManager.shared
                .refreshAccessToken()
                .flatMap { _ in
                    CombineNetworkLogger.log("✅ Token refreshed, retrying request", level: .info)
                    return requestFactory()
                }
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}
