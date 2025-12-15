//
//  APIClient.swift
//  SimpleEyes
//
//  网络请求服务 - 封装所有与后端服务器的 HTTP API 交互
//  提供设备管理、视频流、对讲等功能的 RESTful API 调用
//

@preconcurrency import Foundation
@preconcurrency import Alamofire

// MARK: - API Configuration

/// API 配置管理
///
/// 负责管理 API 服务器和 WebSocket 服务器的 URL 配置
/// 支持从 UserDefaults 读取用户自定义配置，未设置时使用默认值
struct APIConfig {
    // 默认配置
    private static let defaultBaseURL = "http://localhost:3000"
    private static let defaultWsURL = "ws://localhost:8080"

    /// API 服务器基础 URL
    ///
    /// 从 UserDefaults 读取配置，如果未设置则使用默认值
    /// - Returns: API 服务器的基础 URL (例如: http://192.168.1.100:3000)
    static var baseURL: String {
        UserDefaults.standard.string(forKey: "apiServerURL") ?? defaultBaseURL
    }

    /// WebSocket 服务器 URL
    ///
    /// 从 UserDefaults 读取配置，如果未设置则使用默认值
    /// - Returns: WebSocket 服务器的 URL (例如: ws://192.168.1.100:8080)
    static var wsURL: String {
        UserDefaults.standard.string(forKey: "wsServerURL") ?? defaultWsURL
    }
}

// MARK: - API Error

/// API 错误类型
///
/// 定义了所有可能的 API 调用错误类型
enum APIError: Error {
    /// 网络错误（连接失败、超时等）
    case networkError(Error)
    /// 服务器返回的错误
    case serverError(String)
    /// JSON 数据解析错误
    case decodingError
    /// 无效的响应格式
    case invalidResponse

    /// 错误的本地化描述
    var localizedDescription: String {
        switch self {
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .serverError(let message):
            return "服务器错误: \(message)"
        case .decodingError:
            return "数据解析错误"
        case .invalidResponse:
            return "无效的响应"
        }
    }
}

// MARK: - API Client

/// API 客户端
///
/// 提供所有与后端服务器交互的 HTTP API 方法
/// 使用单例模式，确保全局只有一个实例
/// 基于 Alamofire 框架实现网络请求
///
/// ## 功能模块
/// - 设备管理：获取设备列表、设备详情
/// - 视频服务：获取直播流、录像列表、启动转码
/// - 对讲服务：获取在线设备列表
///
/// ## 使用示例
/// ```swift
/// // 获取设备列表
/// APIClient.shared.getDeviceList { result in
///     switch result {
///     case .success(let response):
///         print("设备数量: \(response.count)")
///     case .failure(let error):
///         print("错误: \(error.localizedDescription)")
///     }
/// }
/// ```
class APIClient {
    /// 单例实例
    static let shared = APIClient()

    /// 私有初始化方法，防止外部创建实例
    private init() {}

    // MARK: - Device APIs

    /// 获取设备列表
    ///
    /// 从服务器获取所有已注册的设备列表
    ///
    /// - Parameter completion: 完成回调
    ///   - Success: 返回 `DeviceListResponse` 包含设备列表和总数
    ///   - Failure: 返回 `APIError` 错误类型
    func getDeviceList(completion: @escaping (Result<DeviceListResponse, APIError>) -> Void) {
        let url = "\(APIConfig.baseURL)/api/device/list"

        AF.request(url).responseDecodable(of: DeviceListResponse.self) { response in
            switch response.result {
            case .success(let data):
                completion(.success(data))
            case .failure(let error):
                completion(.failure(.networkError(error)))
            }
        }
    }

    /// 获取单个设备详细信息
    ///
    /// - Parameters:
    ///   - deviceId: 设备唯一标识符
    ///   - completion: 完成回调
    ///     - Success: 返回 `Device` 设备详细信息
    ///     - Failure: 返回 `APIError` 错误类型
    func getDevice(deviceId: String, completion: @escaping (Result<Device, APIError>) -> Void) {
        let url = "\(APIConfig.baseURL)/api/device/\(deviceId)"

        AF.request(url).responseDecodable(of: Device.self) { response in
            switch response.result {
            case .success(let device):
                completion(.success(device))
            case .failure(let error):
                completion(.failure(.networkError(error)))
            }
        }
    }

    // MARK: - Video APIs

    /// 获取设备的直播流地址
    ///
    /// - Parameters:
    ///   - deviceId: 设备唯一标识符
    ///   - completion: 完成回调
    ///     - Success: 返回 `LiveStreamResponse` 包含流协议、URL 和状态
    ///     - Failure: 返回 `APIError` 错误类型
    func getLiveStream(deviceId: String, completion: @escaping (Result<LiveStreamResponse, APIError>) -> Void) {
        let url = "\(APIConfig.baseURL)/api/video/live/\(deviceId)"

        AF.request(url).responseDecodable(of: LiveStreamResponse.self) { response in
            switch response.result {
            case .success(let stream):
                completion(.success(stream))
            case .failure(let error):
                completion(.failure(.networkError(error)))
            }
        }
    }

    /// 获取设备的录像列表
    ///
    /// - Parameters:
    ///   - deviceId: 设备唯一标识符
    ///   - date: 可选的日期过滤条件 (格式: YYYY-MM-DD)，默认为 nil 获取所有录像
    ///   - completion: 完成回调
    ///     - Success: 返回 `PlaybackListResponse` 包含录像列表和总数
    ///     - Failure: 返回 `APIError` 错误类型
    func getPlaybackList(deviceId: String, date: String? = nil,
                        completion: @escaping (Result<PlaybackListResponse, APIError>) -> Void) {
        var url = "\(APIConfig.baseURL)/api/video/playback/\(deviceId)"
        if let date = date {
            url += "?date=\(date)"
        }

        AF.request(url).responseDecodable(of: PlaybackListResponse.self) { response in
            switch response.result {
            case .success(let data):
                completion(.success(data))
            case .failure(let error):
                completion(.failure(.networkError(error)))
            }
        }
    }

    /// 启动直播转码任务
    ///
    /// 在服务器端启动视频流转码任务，将输入流转换为 HLS 格式
    /// 通常由设备端调用
    ///
    /// - Parameters:
    ///   - deviceId: 设备唯一标识符
    ///   - inputUrl: 输入视频流的 URL (支持 RTSP、RTMP 等协议)
    ///   - completion: 完成回调
    ///     - Success: 返回 `TranscodeResponse` 包含转码结果和 HLS URL
    ///     - Failure: 返回 `APIError` 错误类型
    ///
    /// - Note: 转码参数固定为 1280x720 分辨率，2000k 码率，25fps
    func startLiveTranscode(deviceId: String, inputUrl: String,
                           completion: @escaping (Result<TranscodeResponse, APIError>) -> Void) {
        let url = "\(APIConfig.baseURL)/api/video/live/\(deviceId)/start"
        let parameters: [String: Any] = [
            "inputUrl": inputUrl,
            "resolution": "1280x720",
            "bitrate": "2000k",
            "fps": 25
        ]

        AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default)
            .responseDecodable(of: TranscodeResponse.self) { response in
                switch response.result {
                case .success(let data):
                    completion(.success(data))
                case .failure(let error):
                    completion(.failure(.networkError(error)))
                }
            }
    }

    // MARK: - Intercom APIs

    /// 获取在线设备列表
    ///
    /// 从 WebSocket 服务器获取当前在线的设备列表，用于对讲功能
    ///
    /// - Parameter completion: 完成回调
    ///   - Success: 返回 `OnlineDevicesResponse` 包含在线设备列表和总数
    ///   - Failure: 返回 `APIError` 错误类型
    ///
    /// - Note: 此方法使用 WebSocket 服务器的 HTTP API，会自动将 ws:// 转换为 http://
    func getOnlineDevices(completion: @escaping (Result<OnlineDevicesResponse, APIError>) -> Void) {
        // 使用 WebSocket 服务器的 HTTP API（同一个端口）
        let wsURL = APIConfig.wsURL
        // 将 ws:// 或 wss:// 替换为 http:// 或 https://
        let httpURL = wsURL.replacingOccurrences(of: "ws://", with: "http://")
                            .replacingOccurrences(of: "wss://", with: "https://")

        let url = "\(httpURL)/api/devices/online"

        print("[APIClient] Requesting online devices from: \(url)")

        AF.request(url).validate().responseData { response in
            // 打印原始响应数据用于调试
            if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
                print("[APIClient] Response status code: \(response.response?.statusCode ?? -1)")
                print("[APIClient] Response data: \(responseString)")
            }

            switch response.result {
            case .success(let data):
                // 尝试解码 JSON
                do {
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(OnlineDevicesResponse.self, from: data)
                    completion(.success(result))
                } catch {
                    print("[APIClient] JSON decode error: \(error)")
                    completion(.failure(.decodingError))
                }
            case .failure(let error):
                print("[APIClient] Request error: \(error)")
                completion(.failure(.networkError(error)))
            }
        }
    }
}
