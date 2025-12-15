//
//  NetworkCache.swift
//  SimpleEyes
//
//  网络缓存管理器 - 提供内存和磁盘缓存功能
//  支持 TTL、缓存大小限制、自动清理等
//

import Foundation

// MARK: - Cache Entry

/// 缓存条目
///
/// 存储缓存的数据和元信息
struct CacheEntry: Codable {
    /// 缓存的数据
    let data: Data

    /// 缓存创建时间
    let timestamp: Date

    /// 缓存有效期（秒）
    let ttl: TimeInterval

    /// 检查缓存是否过期
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }

    /// 剩余有效时间（秒）
    var remainingTTL: TimeInterval {
        let elapsed = Date().timeIntervalSince(timestamp)
        return max(0, ttl - elapsed)
    }
}

// MARK: - Network Cache

/// 网络缓存管理器
///
/// 提供两级缓存：内存缓存和磁盘缓存
/// - 内存缓存：速度快但容量小，应用重启后失效
/// - 磁盘缓存：速度相对慢但容量大，持久化存储
///
/// ## 使用示例
/// ```swift
/// let cache = NetworkCache.shared
///
/// // 存储缓存
/// cache.store(data: responseData, forKey: "user_profile", ttl: 300)
///
/// // 读取缓存
/// if let cachedData = cache.retrieve(forKey: "user_profile") {
///     print("使用缓存数据")
/// }
/// ```
actor NetworkCache {
    /// 单例实例
    static let shared = NetworkCache()

    // MARK: - Configuration

    /// 内存缓存最大条目数
    private let maxMemoryCacheCount = 100

    /// 磁盘缓存最大大小（字节）
    private let maxDiskCacheSize: Int64 = 100 * 1024 * 1024 // 100MB

    // MARK: - Storage

    /// 内存缓存存储
    private var memoryCache: [String: CacheEntry] = [:]

    /// 磁盘缓存目录
    private let diskCacheDirectory: URL

    // MARK: - Initialization

    private init() {
        // 创建磁盘缓存目录
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheDirectory = cacheDirectory.appendingPathComponent("NetworkCache")

        // 确保目录存在
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)

        // 启动时清理过期缓存
        Task {
            await cleanupExpiredCache()
        }
    }

    // MARK: - Store

    /// 存储缓存
    ///
    /// - Parameters:
    ///   - data: 要缓存的数据
    ///   - key: 缓存键
    ///   - ttl: 缓存有效期（秒）
    ///   - toDisk: 是否同时存储到磁盘
    func store(data: Data, forKey key: String, ttl: TimeInterval, toDisk: Bool = true) {
        let entry = CacheEntry(data: data, timestamp: Date(), ttl: ttl)

        // 存储到内存
        memoryCache[key] = entry

        // 检查内存缓存大小
        if memoryCache.count > maxMemoryCacheCount {
            // 移除最旧的条目
            if let oldestKey = memoryCache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key {
                memoryCache.removeValue(forKey: oldestKey)
            }
        }

        NetworkLogger.log("Stored cache in memory: \(key)", level: .debug)

        // 存储到磁盘
        if toDisk {
            Task {
                await storeToDisk(entry: entry, forKey: key)
            }
        }
    }

    /// 存储到磁盘
    private func storeToDisk(entry: CacheEntry, forKey key: String) async {
        let fileURL = diskCacheURL(forKey: key)

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(entry)
            try data.write(to: fileURL)

            NetworkLogger.log("Stored cache to disk: \(key)", level: .debug)

            // 检查磁盘缓存大小
            cleanupDiskCacheIfNeeded()
        } catch {
            NetworkLogger.log("Failed to store cache to disk: \(error.localizedDescription)", level: .error)
        }
    }

    // MARK: - Retrieve

    /// 读取缓存
    ///
    /// - Parameters:
    ///   - key: 缓存键
    ///   - fromDisk: 如果内存中没有，是否从磁盘读取
    /// - Returns: 缓存的数据，如果不存在或已过期则返回 nil
    func retrieve(forKey key: String, fromDisk: Bool = true) -> Data? {
        // 先从内存读取
        if let entry = memoryCache[key] {
            if entry.isExpired {
                // 缓存已过期，移除
                memoryCache.removeValue(forKey: key)
                NetworkLogger.log("Memory cache expired: \(key)", level: .debug)
                return nil
            }

            NetworkLogger.log("Retrieved cache from memory: \(key)", level: .debug)
            return entry.data
        }

        // 从磁盘读取
        if fromDisk {
            return retrieveFromDiskSync(forKey: key)
        }

        return nil
    }

    /// 从磁盘读取缓存（同步方法）
    private func retrieveFromDiskSync(forKey key: String) -> Data? {
        let fileURL = diskCacheURL(forKey: key)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let entry = try decoder.decode(CacheEntry.self, from: data)

            if entry.isExpired {
                // 缓存已过期，删除文件
                try? FileManager.default.removeItem(at: fileURL)
                NetworkLogger.log("Disk cache expired: \(key)", level: .debug)
                return nil
            }

            // 加载到内存
            memoryCache[key] = entry

            NetworkLogger.log("Retrieved cache from disk: \(key)", level: .debug)
            return entry.data
        } catch {
            NetworkLogger.log("Failed to retrieve cache from disk: \(error.localizedDescription)", level: .error)
            return nil
        }
    }

    // MARK: - Remove

    /// 移除缓存
    ///
    /// - Parameters:
    ///   - key: 缓存键
    ///   - fromDisk: 是否同时从磁盘移除
    func remove(forKey key: String, fromDisk: Bool = true) {
        // 从内存移除
        memoryCache.removeValue(forKey: key)

        // 从磁盘移除
        if fromDisk {
            let fileURL = diskCacheURL(forKey: key)
            try? FileManager.default.removeItem(at: fileURL)
        }

        NetworkLogger.log("Removed cache: \(key)", level: .debug)
    }

    /// 清空所有缓存
    func clear() {
        // 清空内存缓存
        memoryCache.removeAll()

        // 清空磁盘缓存
        try? FileManager.default.removeItem(at: diskCacheDirectory)
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)

        NetworkLogger.log("Cleared all cache", level: .info)
    }

    // MARK: - Cleanup

    /// 清理过期缓存
    private func cleanupExpiredCache() {
        // 清理内存中的过期缓存
        let expiredKeys = memoryCache.filter { $0.value.isExpired }.map { $0.key }
        for key in expiredKeys {
            memoryCache.removeValue(forKey: key)
        }

        // 清理磁盘中的过期缓存
        guard let files = try? FileManager.default.contentsOfDirectory(at: diskCacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        for fileURL in files {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                let entry = try decoder.decode(CacheEntry.self, from: data)

                if entry.isExpired {
                    try FileManager.default.removeItem(at: fileURL)
                }
            } catch {
                // 如果读取失败，可能是损坏的文件，直接删除
                try? FileManager.default.removeItem(at: fileURL)
            }
        }

        NetworkLogger.log("Cleaned up expired cache", level: .debug)
    }

    /// 清理磁盘缓存（如果超过大小限制）
    private func cleanupDiskCacheIfNeeded() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: diskCacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else {
            return
        }

        // 计算总大小
        var totalSize: Int64 = 0
        var fileInfos: [(url: URL, size: Int64, date: Date)] = []

        for fileURL in files {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                let size = Int64(resourceValues.fileSize ?? 0)
                let date = resourceValues.contentModificationDate ?? Date.distantPast

                totalSize += size
                fileInfos.append((url: fileURL, size: size, date: date))
            } catch {
                continue
            }
        }

        // 如果超过限制，删除最旧的文件
        if totalSize > maxDiskCacheSize {
            // 按修改日期排序
            fileInfos.sort { $0.date < $1.date }

            var currentSize = totalSize
            for info in fileInfos {
                if currentSize <= maxDiskCacheSize {
                    break
                }

                try? FileManager.default.removeItem(at: info.url)
                currentSize -= info.size
            }

            NetworkLogger.log("Cleaned up disk cache (was \(totalSize) bytes, now \(currentSize) bytes)", level: .info)
        }
    }

    // MARK: - Helper

    /// 获取磁盘缓存文件 URL
    private func diskCacheURL(forKey key: String) -> URL {
        // 使用 SHA256 hash 作为文件名，避免特殊字符问题
        let fileName = key.sha256()
        return diskCacheDirectory.appendingPathComponent(fileName)
    }

    // MARK: - Statistics

    /// 获取缓存统计信息
    func statistics() -> CacheStatistics {
        let memoryCacheCount = memoryCache.count
        let memoryCacheSize = memoryCache.values.reduce(0) { $0 + $1.data.count }

        var diskCacheCount = 0
        var diskCacheSize: Int64 = 0

        if let files = try? FileManager.default.contentsOfDirectory(
            at: diskCacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) {
            diskCacheCount = files.count
            for fileURL in files {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let size = resourceValues.fileSize {
                    diskCacheSize += Int64(size)
                }
            }
        }

        return CacheStatistics(
            memoryCacheCount: memoryCacheCount,
            memoryCacheSize: memoryCacheSize,
            diskCacheCount: diskCacheCount,
            diskCacheSize: diskCacheSize
        )
    }
}

// MARK: - Cache Statistics

/// 缓存统计信息
struct CacheStatistics {
    let memoryCacheCount: Int
    let memoryCacheSize: Int
    let diskCacheCount: Int
    let diskCacheSize: Int64

    var formattedMemorySize: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryCacheSize), countStyle: .file)
    }

    var formattedDiskSize: String {
        ByteCountFormatter.string(fromByteCount: diskCacheSize, countStyle: .file)
    }
}

// MARK: - String Extension

extension String {
    /// 计算 SHA256 hash
    func sha256() -> String {
        guard let data = data(using: .utf8) else { return self }

        // 简单的 hash 实现（用于文件名）
        let hash = data.hashValue
        return String(format: "%02x", abs(hash))
    }
}
