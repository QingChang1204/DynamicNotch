//
//  AppConfig.swift
//  NotchNoti
//
//  统一配置管理 - 消除魔法数字，支持环境区分
//  生产级别配置中心
//

import Foundation

/// 应用配置中心 (单例)
enum AppConfig {
    /// 当前环境
    static var environment: Environment = .production

    /// 环境类型
    enum Environment: String {
        case development = "dev"
        case production = "prod"
    }

    // MARK: - Socket配置

    enum Socket {
        /// Socket重试次数
        static let maxRetries = 5

        /// Socket重试间隔（毫秒）
        static let retryDelayMs: UInt32 = 200_000  // 200ms

        /// Socket连接超时（秒）
        static let connectionTimeoutSeconds: TimeInterval = 5.0
    }

    // MARK: - MCP配置

    enum MCP {
        /// 交互式通知超时（秒）
        static let actionTimeoutSeconds: TimeInterval = 50.0

        /// 文件监控超时（秒）
        static let fileWatcherTimeoutSeconds: TimeInterval = 50.0

        /// 输入验证 - 标题最大长度
        static let maxTitleLength = 100

        /// 输入验证 - 消息最大长度
        static let maxMessageLength = 500

        /// 输入验证 - 单个Action最大长度
        static let maxActionLength = 30

        /// 输入验证 - 最多Action数量
        static let maxActionsCount = 3
    }

    // MARK: - 通知配置

    enum Notification {
        /// 通知合并时间窗口（秒）
        static let mergeTimeWindow: TimeInterval = 0.5

        /// 通知去重时间窗口（秒）
        static let dedupTimeWindow: TimeInterval = 300  // 5分钟

        /// 最大队列大小
        static let maxQueueSize = 10

        /// 最大历史记录（内存）
        static let maxHistoryCount = 50

        /// 最大持久化记录（CoreData）
        static let maxPersistentCount = 5000

        /// 默认分页大小
        static let defaultPageSize = 20

        /// 交互式通知显示时长（秒）
        static let actionableDuration: TimeInterval = 30.0

        /// Diff通知显示时长（秒）
        static let diffDuration: TimeInterval = 2.0

        /// 消息长度影响 - 每N字符增加显示时间
        static let charactersPerExtraSecond = 50

        /// 消息长度影响 - 最大额外显示时间（秒）
        static let maxExtraTime: TimeInterval = 2.0
    }

    // MARK: - 统计配置

    enum Statistics {
        /// 最大Session历史数量
        static let maxSessionCount = 20

        /// 统计缓存有效期（秒）
        static let cacheValidDuration: TimeInterval = 300  // 5分钟

        /// 生成AI洞察的最小Session时长（秒）
        static let minSessionDurationForInsights: TimeInterval = 600  // 10分钟

        /// 生成AI洞察的最小活动数
        static let minActivitiesForInsights = 5

        /// 统计查询最大记录数
        static let maxQueryLimit = 2000
    }

    // MARK: - 性能配置

    enum Performance {
        /// CoreData批量操作大小
        static let batchSize = 100

        /// 后台任务QoS优先级
        static let backgroundQoS: DispatchQoS.QoSClass = .userInteractive

        /// Timer检查间隔（秒）
        static let timerInterval: TimeInterval = 1.0
    }

    // MARK: - 安全配置

    enum Security {
        /// Socket文件权限（八进制）
        static let socketFilePermissions: UInt16 = 0o600

        /// 允许root用户连接
        static let allowRootConnection = true

        /// Socket文件权限检查失败时是否允许连接
        static let allowConnectionOnPermissionCheckFailure = false
    }

    // MARK: - 环境特定配置

    /// 是否启用调试日志
    static var enableDebugLogging: Bool {
        switch environment {
        case .development:
            return true
        case .production:
            return false
        }
    }

    /// 是否启用性能监控
    static var enablePerformanceMonitoring: Bool {
        switch environment {
        case .development:
            return true
        case .production:
            return true  // 生产环境也需要监控
        }
    }

    /// 是否启用崩溃报告
    static var enableCrashReporting: Bool {
        switch environment {
        case .development:
            return false
        case .production:
            return true
        }
    }
}

// MARK: - 向后兼容的常量（从NotificationModel.swift迁移）

enum NotificationConstants {
    static let mergeTimeWindow = AppConfig.Notification.mergeTimeWindow
    static let maxQueueSize = AppConfig.Notification.maxQueueSize
    static let maxHistoryCount = AppConfig.Notification.maxHistoryCount
    static let maxPersistentCount = AppConfig.Notification.maxPersistentCount
    static let defaultPageSize = AppConfig.Notification.defaultPageSize
    static let actionableDuration = AppConfig.Notification.actionableDuration
    static let diffDuration = AppConfig.Notification.diffDuration

    enum MessageLengthImpact {
        static let charactersPerExtraSecond = AppConfig.Notification.charactersPerExtraSecond
        static let maxExtraTime = AppConfig.Notification.maxExtraTime
    }
}

enum StatisticsConstants {
    static let maxSessionCount = AppConfig.Statistics.maxSessionCount
    static let cacheValidDuration = AppConfig.Statistics.cacheValidDuration

    enum InsightThreshold {
        static let minSessionDuration = AppConfig.Statistics.minSessionDurationForInsights
        static let minActivities = AppConfig.Statistics.minActivitiesForInsights
    }
}

// MARK: - Metadata键名规范（集中管理）

enum MetadataKeys {
    static let source = "source"
    static let project = "project"
    static let toolName = "tool_name"
    static let eventType = "event_type"
    static let duration = "duration"
    static let errorMessage = "error_message"
    static let context = "context"
    static let diffPath = "diff_path"
    static let userChoice = "user_choice"
    static let summaryData = "summary_data"
    static let summaryId = "summary_id"
}

// MARK: - 环境配置扩展

extension AppConfig.Environment {
    /// 从环境变量或Info.plist加载
    static func load() -> AppConfig.Environment {
        // 优先从环境变量读取
        if let envStr = ProcessInfo.processInfo.environment["NOTCHNOTI_ENV"],
           let env = AppConfig.Environment(rawValue: envStr) {
            return env
        }

        // 从Info.plist读取（用于Xcode配置）
        if let envStr = Bundle.main.object(forInfoDictionaryKey: "NotchNotiEnvironment") as? String,
           let env = AppConfig.Environment(rawValue: envStr) {
            return env
        }

        // 默认生产环境
        return .production
    }
}
