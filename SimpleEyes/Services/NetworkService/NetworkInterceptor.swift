//
//  NetworkInterceptor.swift
//  SimpleEyes
//
//  网络拦截器 - 定义请求和响应拦截器协议及常用实现
//  支持请求前后的处理、token 刷新、日志记录等
//

import Foundation
import Alamofire

// MARK: - Interceptor Protocols

/// 请求拦截器协议
///
/// 在发送请求前执行，可以修改请求参数、添加请求头等
protocol RequestInterceptor {
    /// 拦截请求
    ///
    /// - Parameter request: URLRequest 对象
    /// - Returns: 修改后的 URLRequest
    func intercept(request: URLRequest) async throws -> URLRequest
}

/// 响应拦截器协议
///
/// 在收到响应后执行，可以处理响应数据、错误等
protocol ResponseInterceptor {
    /// 拦截响应
    ///
    /// - Parameters:
    ///   - data: 响应数据
    ///   - response: URLResponse 对象
    ///   - error: 可能的错误
    /// - Returns: 处理后的结果
    func intercept(data: Data?, response: URLResponse?, error: Error?) async throws -> (Data?, URLResponse?)
}

// MARK: - Token Interceptor

/// Token 拦截器
///
/// 自动在请求头中添加认证 token
class TokenInterceptor: RequestInterceptor {
    private let tokenProvider: () -> String?

    init(tokenProvider: @escaping () -> String?) {
        self.tokenProvider = tokenProvider
    }

    func intercept(request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request

        if let token = tokenProvider() {
            modifiedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            NetworkLogger.log("Added Authorization header", level: .debug)
        }

        return modifiedRequest
    }
}

// MARK: - Token Refresh Interceptor

/// Token 刷新拦截器
///
/// 检测 401 错误并自动刷新 token 后重试请求
class TokenRefreshInterceptor: ResponseInterceptor {
    private let tokenRefresher: () async throws -> String
    private let tokenSaver: (String) -> Void
    private var isRefreshing = false
    private var refreshTask: Task<String, Error>?

    init(tokenRefresher: @escaping () async throws -> String,
         tokenSaver: @escaping (String) -> Void) {
        self.tokenRefresher = tokenRefresher
        self.tokenSaver = tokenSaver
    }

    func intercept(data: Data?, response: URLResponse?, error: Error?) async throws -> (Data?, URLResponse?) {
        // 检查是否是 401 错误
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 401 else {
            return (data, response)
        }

        NetworkLogger.log("Received 401, attempting token refresh", level: .info)

        // 刷新 token
        let newToken = try await refreshToken()
        tokenSaver(newToken)

        NetworkLogger.log("Token refreshed successfully", level: .info)

        // 返回 nil 表示需要重试原请求
        return (nil, nil)
    }

    private func refreshToken() async throws -> String {
        // 如果已经有刷新任务在进行，等待它完成
        if let existingTask = refreshTask {
            return try await existingTask.value
        }

        // 创建新的刷新任务
        let task = Task<String, Error> {
            defer { refreshTask = nil }
            return try await tokenRefresher()
        }

        refreshTask = task
        return try await task.value
    }
}

// MARK: - Logging Interceptor

/// 日志拦截器
///
/// 记录请求和响应的详细信息
class LoggingInterceptor: RequestInterceptor, ResponseInterceptor {
    private let logLevel: LogLevel

    init(logLevel: LogLevel = .info) {
        self.logLevel = logLevel
    }

    func intercept(request: URLRequest) async throws -> URLRequest {
        guard logLevel.rawValue <= LogLevel.info.rawValue else {
            return request
        }

        NetworkLogger.log("=== REQUEST ===", level: .info)
        NetworkLogger.log("URL: \(request.url?.absoluteString ?? "unknown")", level: .info)
        NetworkLogger.log("Method: \(request.httpMethod ?? "unknown")", level: .info)

        if logLevel.rawValue <= LogLevel.debug.rawValue {
            if let headers = request.allHTTPHeaderFields {
                NetworkLogger.log("Headers: \(headers)", level: .debug)
            }

            if let body = request.httpBody,
               let bodyString = String(data: body, encoding: .utf8) {
                NetworkLogger.log("Body: \(bodyString)", level: .debug)
            }
        }

        return request
    }

    func intercept(data: Data?, response: URLResponse?, error: Error?) async throws -> (Data?, URLResponse?) {
        guard logLevel.rawValue <= LogLevel.info.rawValue else {
            return (data, response)
        }

        NetworkLogger.log("=== RESPONSE ===", level: .info)

        if let httpResponse = response as? HTTPURLResponse {
            NetworkLogger.log("Status: \(httpResponse.statusCode)", level: .info)

            if logLevel.rawValue <= LogLevel.debug.rawValue {
                NetworkLogger.log("Headers: \(httpResponse.allHeaderFields)", level: .debug)
            }
        }

        if let error = error {
            NetworkLogger.log("Error: \(error.localizedDescription)", level: .error)
        }

        if logLevel.rawValue <= LogLevel.verbose.rawValue,
           let data = data,
           let responseString = String(data: data, encoding: .utf8) {
            NetworkLogger.log("Body: \(responseString)", level: .verbose)
        }

        return (data, response)
    }
}

// MARK: - Custom Header Interceptor

/// 自定义请求头拦截器
///
/// 添加自定义的请求头
class CustomHeaderInterceptor: RequestInterceptor {
    private let headers: [String: String]

    init(headers: [String: String]) {
        self.headers = headers
    }

    func intercept(request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request

        for (key, value) in headers {
            modifiedRequest.setValue(value, forHTTPHeaderField: key)
        }

        return modifiedRequest
    }
}

// MARK: - Content Type Interceptor

/// Content-Type 拦截器
///
/// 自动添加 Content-Type 请求头
class ContentTypeInterceptor: RequestInterceptor {
    private let contentType: String

    init(contentType: String = "application/json") {
        self.contentType = contentType
    }

    func intercept(request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request

        // 只在有 body 且未设置 Content-Type 时添加
        if request.httpBody != nil,
           request.value(forHTTPHeaderField: "Content-Type") == nil {
            modifiedRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        return modifiedRequest
    }
}

// MARK: - Error Handling Interceptor

/// 错误处理拦截器
///
/// 统一处理常见的网络错误
class ErrorHandlingInterceptor: ResponseInterceptor {
    func intercept(data: Data?, response: URLResponse?, error: Error?) async throws -> (Data?, URLResponse?) {
        // 检查 HTTP 状态码
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200..<300:
                // 成功，不做处理
                break

            case 400:
                throw NetworkError.badRequest

            case 401:
                throw NetworkError.unauthorized

            case 403:
                throw NetworkError.forbidden

            case 404:
                throw NetworkError.notFound

            case 500..<600:
                throw NetworkError.serverError(httpResponse.statusCode)

            default:
                throw NetworkError.unknown(httpResponse.statusCode)
            }
        }

        // 检查网络错误
        if let error = error {
            if (error as NSError).domain == NSURLErrorDomain {
                switch (error as NSError).code {
                case NSURLErrorNotConnectedToInternet:
                    throw NetworkError.noInternet

                case NSURLErrorTimedOut:
                    throw NetworkError.timeout

                case NSURLErrorCancelled:
                    throw NetworkError.cancelled

                default:
                    throw NetworkError.networkError(error)
                }
            }

            throw NetworkError.networkError(error)
        }

        return (data, response)
    }
}

// MARK: - Network Error

/// 网络错误枚举
enum NetworkError: Error, LocalizedError {
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case serverError(Int)
    case unknown(Int)
    case noInternet
    case timeout
    case cancelled
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .badRequest:
            return "请求参数错误"
        case .unauthorized:
            return "未授权，请重新登录"
        case .forbidden:
            return "没有访问权限"
        case .notFound:
            return "请求的资源不存在"
        case .serverError(let code):
            return "服务器错误 (\(code))"
        case .unknown(let code):
            return "未知错误 (\(code))"
        case .noInternet:
            return "网络连接不可用"
        case .timeout:
            return "请求超时"
        case .cancelled:
            return "请求已取消"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}

// MARK: - Network Logger

/// 网络日志工具
struct NetworkLogger {
    static func log(_ message: String, level: LogLevel) {
        guard level != .none else { return }

        let prefix: String
        switch level {
        case .verbose:
            prefix = "🔍 [VERBOSE]"
        case .debug:
            prefix = "🐛 [DEBUG]"
        case .info:
            prefix = "ℹ️ [INFO]"
        case .warning:
            prefix = "⚠️ [WARNING]"
        case .error:
            prefix = "❌ [ERROR]"
        case .none:
            prefix = ""
        }

        print("\(prefix) \(message)")
    }
}
