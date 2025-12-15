//
//  CombineTokenManager.swift
//  SimpleEyes
//
//  Combine 网络服务 - Token 管理
//

import Foundation
import Combine

// MARK: - Token Manager

/// Combine Token 管理器
class CombineTokenManager {
    // MARK: - Singleton

    static let shared = CombineTokenManager()
    private init() {}

    // MARK: - Properties

    /// 存储键
    private let accessTokenKey = "combine_access_token"
    private let refreshTokenKey = "combine_refresh_token"

    /// Token 刷新中标志（防止多个请求同时刷新）
    private var isRefreshing = false

    /// 等待刷新完成的 Subject
    private let refreshSubject = PassthroughSubject<String, CombineNetworkError>()

    /// 刷新 Token 的锁
    private let refreshLock = NSLock()

    // MARK: - Token Access

    /// 获取 Access Token
    var accessToken: String? {
        get {
            return UserDefaults.standard.string(forKey: accessTokenKey)
        }
        set {
            if let token = newValue {
                UserDefaults.standard.set(token, forKey: accessTokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: accessTokenKey)
            }
        }
    }

    /// 获取 Refresh Token
    var refreshToken: String? {
        get {
            return UserDefaults.standard.string(forKey: refreshTokenKey)
        }
        set {
            if let token = newValue {
                UserDefaults.standard.set(token, forKey: refreshTokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: refreshTokenKey)
            }
        }
    }

    // MARK: - Token Operations

    /// 保存 Token
    /// - Parameters:
    ///   - accessToken: Access Token
    ///   - refreshToken: Refresh Token（可选）
    func saveTokens(accessToken: String, refreshToken: String? = nil) {
        self.accessToken = accessToken
        if let refreshToken = refreshToken {
            self.refreshToken = refreshToken
        }
        CombineNetworkLogger.log("✅ Token saved successfully", level: .debug)
    }

    /// 清除所有 Token
    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        CombineNetworkLogger.log("🗑️ Tokens cleared", level: .debug)
    }

    /// 刷新 Token（支持并发请求去重）
    /// - Parameter refreshEndpoint: 刷新 Token 的 API 端点
    /// - Returns: 新的 Access Token
    func refreshAccessToken(
        refreshEndpoint: String = "\(APIConfig.baseURL)/api/auth/refresh"
    ) -> AnyPublisher<String, CombineNetworkError> {
        refreshLock.lock()
        defer { refreshLock.unlock() }

        // 如果正在刷新，返回共享的 Subject
        if isRefreshing {
            CombineNetworkLogger.log("⏳ Token refresh already in progress, waiting...", level: .debug)
            return refreshSubject.eraseToAnyPublisher()
        }

        // 开始刷新
        isRefreshing = true
        CombineNetworkLogger.log("🔄 Starting token refresh...", level: .info)

        guard let refreshToken = self.refreshToken else {
            let error = CombineNetworkError.unauthorized
            isRefreshing = false
            refreshSubject.send(completion: .failure(error))
            return Fail(error: error).eraseToAnyPublisher()
        }

        // 创建刷新请求
        guard let url = URL(string: refreshEndpoint) else {
            let error = CombineNetworkError.invalidURL(refreshEndpoint)
            isRefreshing = false
            refreshSubject.send(completion: .failure(error))
            return Fail(error: error).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 构建请求体
        let body: [String: Any] = ["refreshToken": refreshToken]
        if let jsonData = try? JSONSerialization.data(withJSONObject: body) {
            request.httpBody = jsonData
        }

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                // 检查响应状态码
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw CombineNetworkError.invalidResponse
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw CombineNetworkError.httpError(
                        statusCode: httpResponse.statusCode,
                        data: data
                    )
                }

                return data
            }
            .decode(type: TokenResponse.self, decoder: JSONDecoder())
            .mapError { error -> CombineNetworkError in
                if let networkError = error as? CombineNetworkError {
                    return networkError
                } else if error is DecodingError {
                    return .decodingError(error)
                } else {
                    return .tokenRefreshFailed(error)
                }
            }
            .handleEvents(
                receiveOutput: { [weak self] response in
                    // 保存新 Token
                    self?.saveTokens(
                        accessToken: response.accessToken,
                        refreshToken: response.refreshToken
                    )
                    CombineNetworkLogger.log("✅ Token refreshed successfully", level: .info)

                    // 通知等待的请求
                    self?.refreshSubject.send(response.accessToken)
                },
                receiveCompletion: { [weak self] completion in
                    self?.isRefreshing = false

                    if case .failure(let error) = completion {
                        CombineNetworkLogger.log("❌ Token refresh failed: \(error)", level: .error)
                        self?.refreshSubject.send(completion: .failure(error))
                    } else {
                        self?.refreshSubject.send(completion: .finished)
                    }
                }
            )
            .map { $0.accessToken }
            .share()
            .eraseToAnyPublisher()
    }
}

// MARK: - Token Response Model

/// Token 刷新响应模型
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}
