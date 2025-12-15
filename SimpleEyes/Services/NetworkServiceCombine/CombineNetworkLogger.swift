//
//  CombineNetworkLogger.swift
//  SimpleEyes
//
//  Combine 网络服务 - 日志管理
//

import Foundation

// MARK: - Network Logger

/// Combine 网络日志管理器
class CombineNetworkLogger {
    // MARK: - Singleton

    static let shared = CombineNetworkLogger()
    private init() {}

    // MARK: - Log Methods

    /// 记录日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - level: 日志级别
    ///   - file: 文件名
    ///   - function: 函数名
    ///   - line: 行号
    static func log(
        _ message: String,
        level: CombineLogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level != .none else { return }

        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .none,
            timeStyle: .medium
        )

        print("\(timestamp) \(level.prefix) [\(fileName):\(line)] \(function) - \(message)")
    }

    /// 记录请求日志
    /// - Parameters:
    ///   - request: URLRequest 对象
    ///   - level: 日志级别
    static func logRequest(_ request: URLRequest, level: CombineLogLevel = .info) {
        guard level != .none else { return }

        var logMessage = "\n📤 ========== REQUEST =========="
        logMessage += "\n🔗 URL: \(request.url?.absoluteString ?? "N/A")"
        logMessage += "\n🔧 Method: \(request.httpMethod ?? "N/A")"

        // 请求头
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            logMessage += "\n📋 Headers:"
            headers.forEach { key, value in
                // 隐藏敏感信息
                if key.lowercased().contains("authorization") || key.lowercased().contains("token") {
                    logMessage += "\n  \(key): ***HIDDEN***"
                } else {
                    logMessage += "\n  \(key): \(value)"
                }
            }
        }

        // 请求体
        if let body = request.httpBody {
            if let jsonString = String(data: body, encoding: .utf8) {
                logMessage += "\n📦 Body: \(jsonString)"
            } else {
                logMessage += "\n📦 Body: \(body.count) bytes"
            }
        }

        logMessage += "\n=============================="

        log(logMessage, level: level)
    }

    /// 记录响应日志
    /// - Parameters:
    ///   - data: 响应数据
    ///   - response: URLResponse 对象
    ///   - error: 错误（如果有）
    ///   - level: 日志级别
    static func logResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        level: CombineLogLevel = .info
    ) {
        guard level != .none else { return }

        var logMessage = "\n📥 ========== RESPONSE =========="

        // URL
        if let url = response?.url {
            logMessage += "\n🔗 URL: \(url.absoluteString)"
        }

        // 状态码
        if let httpResponse = response as? HTTPURLResponse {
            let statusEmoji = (200...299).contains(httpResponse.statusCode) ? "✅" : "❌"
            logMessage += "\n\(statusEmoji) Status Code: \(httpResponse.statusCode)"

            // 响应头
            if !httpResponse.allHeaderFields.isEmpty {
                logMessage += "\n📋 Headers:"
                httpResponse.allHeaderFields.forEach { key, value in
                    logMessage += "\n  \(key): \(value)"
                }
            }
        }

        // 响应数据
        if let data = data {
            if let jsonString = prettyPrintJSON(data) {
                logMessage += "\n📦 Body:\n\(jsonString)"
            } else if let stringData = String(data: data, encoding: .utf8) {
                logMessage += "\n📦 Body: \(stringData)"
            } else {
                logMessage += "\n📦 Body: \(data.count) bytes"
            }
        }

        // 错误
        if let error = error {
            logMessage += "\n❌ Error: \(error.localizedDescription)"
        }

        logMessage += "\n=============================="

        log(logMessage, level: error != nil ? .error : level)
    }

    /// 记录错误日志
    /// - Parameters:
    ///   - error: 错误对象
    ///   - level: 日志级别
    static func logError(_ error: Error, level: CombineLogLevel = .error) {
        log("❌ Error: \(error.localizedDescription)", level: level)
    }

    // MARK: - Helper Methods

    /// 格式化 JSON 输出
    private static func prettyPrintJSON(_ data: Data) -> String? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(
                withJSONObject: jsonObject,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        return prettyString
    }
}
