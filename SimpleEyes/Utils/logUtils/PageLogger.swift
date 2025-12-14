import Foundation

// MARK: - 页面日志模型
struct PageLog: Codable {
    let pageName: String
    let enterTime: Date
    let exitTime: Date?
    let duration: TimeInterval?
    let parameters: [String: String]

    var durationString: String {
        guard let duration = duration else { return "页面未退出" }
        return String(format: "%.2f秒", duration)
    }
}

// MARK: - 页面日志服务
class PageLogger {
    static let shared = PageLogger()

    private var activeSessions: [String: PageSession] = [:]
    private var logs: [PageLog] = []

    private struct PageSession {
        let pageName: String
        let enterTime: Date
        let parameters: [String: String]
    }

    private init() {}

    /// 记录页面进入
    func logPageEnter(pageName: String, parameters: [String: Any] = [:]) {
        let sessionId = UUID().uuidString
        let stringParams = convertToStringDict(parameters)

        let session = PageSession(
            pageName: pageName,
            enterTime: Date(),
            parameters: stringParams
        )

        activeSessions[sessionId] = session

        // 打印日志
        print("📱 [页面进入] \(pageName)")
        print("   ⏰ 时间: \(formatDate(session.enterTime))")
        if !stringParams.isEmpty {
            print("   📦 参数: \(stringParams)")
        }

        // 这里可以发送到远程日志服务
        // sendToRemoteLogger(event: "page_enter", data: session)
    }

    /// 记录页面退出
    func logPageExit(pageName: String) {
        // 查找匹配的 session
        guard let sessionId = activeSessions.first(where: { $0.value.pageName == pageName })?.key,
              let session = activeSessions[sessionId] else {
            print("⚠️ [页面退出] 未找到对应的进入记录: \(pageName)")
            return
        }

        let exitTime = Date()
        let duration = exitTime.timeIntervalSince(session.enterTime)

        // 创建完整日志
        let log = PageLog(
            pageName: session.pageName,
            enterTime: session.enterTime,
            exitTime: exitTime,
            duration: duration,
            parameters: session.parameters
        )

        logs.append(log)
        activeSessions.removeValue(forKey: sessionId)

        // 打印日志
        print("📱 [页面退出] \(pageName)")
        print("   ⏰ 退出时间: \(formatDate(exitTime))")
        print("   ⏱️  停留时长: \(log.durationString)")

        // 这里可以发送到远程日志服务
        // sendToRemoteLogger(event: "page_exit", data: log)
    }

    /// 获取所有日志
    func getAllLogs() -> [PageLog] {
        return logs
    }

    /// 清除所有日志
    func clearLogs() {
        logs.removeAll()
        activeSessions.removeAll()
        print("🗑️  已清除所有页面日志")
    }

    /// 打印统计信息
    func printStatistics() {
        print("\n📊 ========== 页面访问统计 ==========")
        print("总访问页面数: \(logs.count)")

        // 按页面分组统计
        let grouped = Dictionary(grouping: logs, by: { $0.pageName })
        for (pageName, pageLogs) in grouped.sorted(by: { $0.key < $1.key }) {
            let totalDuration = pageLogs.compactMap { $0.duration }.reduce(0, +)
            let avgDuration = totalDuration / Double(pageLogs.count)
            print("\n[\(pageName)]")
            print("  访问次数: \(pageLogs.count)")
            print("  总停留时长: \(String(format: "%.2f秒", totalDuration))")
            print("  平均停留: \(String(format: "%.2f秒", avgDuration))")
        }
        print("=====================================\n")
    }

    // MARK: - 私有方法

    private func convertToStringDict(_ dict: [String: Any]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in dict {
            result[key] = "\(value)"
        }
        return result
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}
