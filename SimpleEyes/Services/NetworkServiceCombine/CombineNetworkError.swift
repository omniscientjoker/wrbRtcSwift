//
//  CombineNetworkError.swift
//  SimpleEyes
//
//  Combine 网络服务 - 错误类型定义
//

import Foundation

// MARK: - Network Error

/// Combine 网络服务错误类型
enum CombineNetworkError: Error {
    /// 无效的 URL
    case invalidURL(String)

    /// 网络连接错误
    case networkError(Error)

    /// HTTP 错误
    case httpError(statusCode: Int, data: Data?)

    /// 未授权（401）
    case unauthorized

    /// Token 过期需要刷新
    case tokenExpired

    /// 解码错误
    case decodingError(Error)

    /// 编码错误
    case encodingError(Error)

    /// 无效响应
    case invalidResponse

    /// 请求超时
    case timeout

    /// 取消请求
    case cancelled

    /// Token 刷新失败
    case tokenRefreshFailed(Error)

    /// 达到最大重试次数
    case maxRetriesReached

    /// 自定义错误
    case custom(String)

    /// 未知错误
    case unknown(Error)
}

// MARK: - LocalizedError

extension CombineNetworkError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "无效的 URL: \(url)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .httpError(let statusCode, _):
            return "HTTP 错误: \(statusCode)"
        case .unauthorized:
            return "未授权，请重新登录"
        case .tokenExpired:
            return "Token 已过期"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .encodingError(let error):
            return "数据编码错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "无效的响应"
        case .timeout:
            return "请求超时"
        case .cancelled:
            return "请求已取消"
        case .tokenRefreshFailed(let error):
            return "Token 刷新失败: \(error.localizedDescription)"
        case .maxRetriesReached:
            return "达到最大重试次数"
        case .custom(let message):
            return message
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}

// MARK: - Helper Methods

extension CombineNetworkError {
    /// 判断是否是 Token 过期错误
    static func isTokenExpiredError(_ error: Error) -> Bool {
        if let networkError = error as? CombineNetworkError {
            switch networkError {
            case .unauthorized, .tokenExpired:
                return true
            case .httpError(let statusCode, _):
                return statusCode == 401
            default:
                return false
            }
        }
        return false
    }

    /// 判断是否需要重试
    var shouldRetry: Bool {
        switch self {
        case .networkError, .timeout:
            // 网络错误和超时可以重试
            return true
        case .httpError(let statusCode, _):
            // 5xx 错误可以重试
            return statusCode >= 500 && statusCode < 600
        default:
            return false
        }
    }
}
