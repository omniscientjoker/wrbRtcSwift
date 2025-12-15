//
//  CombineNetworkExample.swift
//  SimpleEyes
//
//  Combine 网络服务 - 使用示例
//  展示如何使用 NetworkServiceCombine 进行网络请求
//

import Foundation
import Combine

// MARK: - Example Models

/// 示例用户模型
struct ExampleUser: Codable {
    let id: Int
    let name: String
    let email: String
}

/// 示例设备模型
struct ExampleDevice: Codable {
    let deviceId: String
    let name: String
    let status: String
}

/// 示例响应包装
struct ExampleResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
    let message: String?
}

// MARK: - Example Service

/// 示例 API 服务类
class ExampleAPIService {
    // MARK: - Singleton

    static let shared = ExampleAPIService()
    private init() {}

    // MARK: - Properties

    private let networkService = NetworkServiceCombine.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Example 1: 简单 GET 请求

    /// 获取用户列表
    func getUserList() -> AnyPublisher<[ExampleUser], CombineNetworkError> {
        let config = CombineNetworkConfig.builder()
            .enableLogging(true, level: .info)
            .build()

        return networkService.request(
            url: "https://api.example.com/users",
            method: .get,
            responseType: ExampleResponse<[ExampleUser]>.self,
            config: config
        )
        .map { $0.data }
        .eraseToAnyPublisher()
    }

    // MARK: - Example 2: 需要认证的请求

    /// 获取用户详情（需要认证）
    func getUserProfile(userId: Int) -> AnyPublisher<ExampleUser, CombineNetworkError> {
        let config = CombineNetworkConfig.builder()
            .requiresAuth(true)              // ✅ 需要认证
            .autoRefreshToken(true)          // ✅ 自动刷新 token
            .enableLogging(true, level: .info)
            .build()

        return networkService.request(
            url: "https://api.example.com/users/\(userId)",
            method: .get,
            responseType: ExampleUser.self,
            config: config
        )
    }

    // MARK: - Example 3: POST 请求带参数

    /// 创建用户
    func createUser(name: String, email: String) -> AnyPublisher<ExampleUser, CombineNetworkError> {
        let parameters: [String: Any] = [
            "name": name,
            "email": email
        ]

        let config = CombineNetworkConfig.builder()
            .requiresAuth(true)
            .autoRefreshToken(true)
            .autoRetry(true, maxCount: 3)    // ✅ 自动重试 3 次
            .enableLogging(true, level: .info)
            .build()

        return networkService.request(
            url: "https://api.example.com/users",
            method: .post,
            parameters: parameters,
            responseType: ExampleUser.self,
            config: config
        )
    }

    // MARK: - Example 4: 自定义请求头

    /// 上传文件（自定义请求头）
    func uploadFile() -> AnyPublisher<Data, CombineNetworkError> {
        let config = CombineNetworkConfig.builder()
            .requiresAuth(true)
            .customHeaders([
                "X-Custom-Header": "custom-value",
                "X-Upload-Type": "file"
            ])
            .timeout(60.0)                   // ✅ 长超时时间
            .enableLogging(true, level: .debug)
            .build()

        return networkService.requestData(
            url: "https://api.example.com/upload",
            method: .post,
            config: config
        )
    }

    // MARK: - Example 5: 链式请求（依赖前一个结果）

    /// 获取用户详情和设备列表（链式请求）
    func getUserWithDevices(userId: Int) -> AnyPublisher<(ExampleUser, [ExampleDevice]), CombineNetworkError> {
        let config = CombineNetworkConfig.authenticated

        // 先获取用户信息
        return getUserProfile(userId: userId)
            .flatMap { user in
                // 再获取设备列表
                self.networkService.request(
                    url: "https://api.example.com/users/\(userId)/devices",
                    method: .get,
                    responseType: [ExampleDevice].self,
                    config: config
                )
                .map { devices in
                    (user, devices)
                }
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Example 6: 并发请求（合并结果）

    /// 同时获取多个用户信息
    func getMultipleUsers(userIds: [Int]) -> AnyPublisher<[ExampleUser], CombineNetworkError> {
        let publishers = userIds.map { userId in
            getUserProfile(userId: userId)
        }

        return Publishers.MergeMany(publishers)
            .collect()
            .eraseToAnyPublisher()
    }

    // MARK: - Example 7: 错误处理和重试

    /// 获取设备列表（带完整错误处理）
    func getDeviceList() -> AnyPublisher<[ExampleDevice], Never> {
        let config = CombineNetworkConfig.builder()
            .requiresAuth(true)
            .autoRefreshToken(true)
            .autoRetry(true, maxCount: 3, delay: 2.0)
            .enableLogging(true, level: .info)
            .build()

        return networkService.request(
            url: "https://api.example.com/devices",
            method: .get,
            responseType: [ExampleDevice].self,
            config: config
        )
        .catch { error -> AnyPublisher<[ExampleDevice], Never> in
            // 错误处理
            CombineNetworkLogger.log("Failed to fetch devices: \(error)", level: .error)
            return Just([]).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Example ViewModel (SwiftUI)

/// 示例 ViewModel（SwiftUI 中使用）
class ExampleViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var users: [ExampleUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let apiService = ExampleAPIService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Methods

    /// 加载用户列表
    func loadUsers() {
        isLoading = true
        errorMessage = nil

        apiService.getUserList()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false

                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] users in
                    self?.users = users
                }
            )
            .store(in: &cancellables)
    }

    /// 创建用户
    func createUser(name: String, email: String) {
        isLoading = true
        errorMessage = nil

        apiService.createUser(name: name, email: email)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false

                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] newUser in
                    self?.users.append(newUser)
                    CombineNetworkLogger.log("✅ User created: \(newUser.name)", level: .info)
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Quick Start Guide

/*
 # NetworkServiceCombine 快速开始

 ## 1. 基础配置

 ```swift
 // 保存 Token
 CombineTokenManager.shared.saveTokens(
     accessToken: "your_access_token",
     refreshToken: "your_refresh_token"
 )
 ```

 ## 2. 简单请求

 ```swift
 NetworkServiceCombine.shared
     .request(
         url: "https://api.example.com/users",
         method: .get,
         responseType: [User].self
     )
     .sink(
         receiveCompletion: { completion in
             if case .failure(let error) = completion {
                 print("Error: \(error)")
             }
         },
         receiveValue: { users in
             print("Users: \(users)")
         }
     )
     .store(in: &cancellables)
 ```

 ## 3. 需要认证的请求

 ```swift
 let config = CombineNetworkConfig.builder()
     .requiresAuth(true)
     .autoRefreshToken(true)
     .build()

 NetworkServiceCombine.shared
     .request(
         url: "https://api.example.com/profile",
         method: .get,
         responseType: UserProfile.self,
         config: config
     )
     .sink(...)
     .store(in: &cancellables)
 ```

 ## 4. POST 请求

 ```swift
 let parameters = [
     "name": "John",
     "email": "john@example.com"
 ]

 let config = CombineNetworkConfig.builder()
     .requiresAuth(true)
     .autoRetry(true, maxCount: 3)
     .build()

 NetworkServiceCombine.shared
     .request(
         url: "https://api.example.com/users",
         method: .post,
         parameters: parameters,
         responseType: User.self,
         config: config
     )
     .sink(...)
     .store(in: &cancellables)
 ```

 ## 5. 在 SwiftUI View 中使用

 ```swift
 struct UserListView: View {
     @StateObject private var viewModel = ExampleViewModel()

     var body: some View {
         List(viewModel.users) { user in
             Text(user.name)
         }
         .onAppear {
             viewModel.loadUsers()
         }
     }
 }
 ```

 ## 功能特性

 ✅ 自动 Token 刷新
 ✅ 自动重试失败请求
 ✅ 完整的日志记录
 ✅ 类型安全的数据解析
 ✅ 响应式编程支持
 ✅ 支持自定义请求头
 ✅ 灵活的配置选项
 */
