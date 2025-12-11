@preconcurrency import Foundation
@preconcurrency import Alamofire

/// API 配置
struct APIConfig {
    // 默认配置
    private static let defaultBaseURL = "http://localhost:3000"
    private static let defaultWsURL = "ws://localhost:8080"

    // 从 UserDefaults 读取配置，如果未设置则使用默认值
    static var baseURL: String {
        UserDefaults.standard.string(forKey: "apiServerURL") ?? defaultBaseURL
    }

    static var wsURL: String {
        UserDefaults.standard.string(forKey: "wsServerURL") ?? defaultWsURL
    }
}

/// API 错误类型
enum APIError: Error {
    case networkError(Error)
    case serverError(String)
    case decodingError
    case invalidResponse

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

/// API 客户端
class APIClient {
    static let shared = APIClient()

    private init() {}

    // MARK: - Device APIs

    /// 获取设备列表
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

    /// 获取单个设备信息
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

    /// 获取直播流地址
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

    /// 获取录像列表
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

    /// 启动直播转码（设备端使用）
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

    /// 获取在线设备列表（用于对讲）
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
