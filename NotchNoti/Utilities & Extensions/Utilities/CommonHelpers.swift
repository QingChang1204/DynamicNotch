//
//  CommonHelpers.swift
//  NotchNoti
//
//  公共工具函数和扩展
//  消除代码重复,提高可维护性
//

import Foundation

// MARK: - Date Formatters

/// 日期格式化器 (单例,避免重复创建)
enum DateFormatters {
    /// 完整会话时间: 2025-01-05 14:30:00
    static let session: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// 紧凑格式: 01/05 14:30
    static let compact: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// 日期简写: 01/05
    static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// 时间简写: 14:30
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// ISO 8601 (用于网络传输)
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    /// 格式化为可读的时长字符串
    /// - 示例: 3661秒 → "1h01m", 125秒 → "2m05s"
    var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return String(format: "%dh%02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm%02ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    /// 短格式 (省略秒)
    var shortDuration: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60

        if hours > 0 {
            return String(format: "%dh%02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }

    /// 超短格式 (仅显示主要单位)
    var compactDuration: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60

        if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - String Extensions

extension String {
    /// 截断字符串到指定长度,添加省略号
    func truncated(to length: Int, trailing: String = "...") -> String {
        if count <= length {
            return self
        }
        let endIndex = index(startIndex, offsetBy: length - trailing.count)
        return String(self[..<endIndex]) + trailing
    }

    /// 移除首尾空白和换行
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 是否为空或仅包含空白
    var isBlank: Bool {
        trimmed.isEmpty
    }
}

// MARK: - Collection Extensions

extension Collection {
    /// 安全下标访问 (返回 nil 而非崩溃)
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Array {
    /// 移除并返回第一个满足条件的元素
    mutating func removeFirst(where predicate: (Element) throws -> Bool) rethrows -> Element? {
        guard let index = try firstIndex(where: predicate) else { return nil }
        return remove(at: index)
    }
}

// MARK: - Path Helpers

enum PathHelpers {
    /// 获取相对于项目的路径
    static func relativePath(for fullPath: String, projectRoot: String) -> String {
        if fullPath.hasPrefix(projectRoot) {
            let startIndex = fullPath.index(fullPath.startIndex, offsetBy: projectRoot.count)
            var relative = String(fullPath[startIndex...])

            // 移除前导斜杠
            if relative.hasPrefix("/") {
                relative = String(relative.dropFirst())
            }

            return relative
        }

        return fullPath
    }

    /// 标准化路径 (处理 ~ 和相对路径)
    static func standardized(_ path: String) -> String {
        if path.hasPrefix("~") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return path.replacingOccurrences(of: "~", with: home)
        }

        return (path as NSString).standardizingPath
    }

    /// 确保目录存在,不存在则创建
    static func ensureDirectoryExists(at path: String) throws {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: path) {
            try fileManager.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
}

// MARK: - File Size Formatting

extension Int64 {
    /// 格式化字节大小为可读字符串
    /// - 示例: 1536 → "1.5 KB", 2_097_152 → "2.0 MB"
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}

// MARK: - Color Helpers

import SwiftUI

extension Color {
    /// 根据通知类型返回颜色
    static func notificationColor(for type: NotchNotification.NotificationType) -> Color {
        // 创建临时通知获取颜色 (利用现有逻辑)
        let notification = NotchNotification(
            title: "",
            message: "",
            type: type
        )
        return notification.color
    }

    /// 十六进制颜色初始化
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6: // RGB (24-bit)
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // RGBA (32-bit)
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Debouncer

/// 防抖工具 (用于搜索等场景)
actor Debouncer {
    private var task: Task<Void, Never>?
    private let delay: Duration

    init(delay: Duration = .milliseconds(300)) {
        self.delay = delay
    }

    func debounce(action: @escaping @Sendable () async -> Void) {
        task?.cancel()

        task = Task {
            try? await Task.sleep(for: delay)

            guard !Task.isCancelled else { return }

            await action()
        }
    }

    func cancel() {
        task?.cancel()
    }
}

// MARK: - Logging Helpers

enum Log {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] 🔍 [\(fileName):\(line)] \(function) - \(message)")
        #endif
    }

    static func info(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] ℹ️ \(message)")
    }

    static func warning(_ message: String, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] ⚠️ [\(fileName):\(line)] \(message)")
    }

    static func error(_ error: Error, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] ❌ [\(fileName):\(line)] \(error.localizedDescription)")

        if let appError = error as? AppError {
            appError.log()
        }
    }
}

// MARK: - UserDefaults Helpers

extension UserDefaults {
    /// 线程安全的批量设置
    func setBatch(_ updates: [String: Any]) {
        for (key, value) in updates {
            set(value, forKey: key)
        }
    }

    /// 清除指定前缀的所有键
    func removeAll(withPrefix prefix: String) {
        let keys = dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }
        keys.forEach { removeObject(forKey: $0) }
    }
}
