//
//  Constants.swift
//  NotchNoti
//
//  全局常量定义
//  消除魔法数字,提高代码可读性
//

import Foundation

// MARK: - Notification Constants

enum NotificationConstants {
    /// 内存历史记录最大数量 (UI 显示)
    static let maxHistoryCount = 50

    /// 持久化存储最大数量 (CoreData)
    static let maxPersistentCount = 50_000

    /// 通知队列最大长度
    static let maxQueueSize = 10

    /// 默认分页大小
    static let defaultPageSize = 20

    /// 通知合并时间窗口 (秒)
    static let mergeTimeWindow: TimeInterval = 0.5

    /// 默认显示时长 (秒)
    static let defaultDuration: TimeInterval = 1.0

    /// 优先级对应的显示时长
    enum DurationByPriority {
        static let urgent: TimeInterval = 2.0
        static let high: TimeInterval = 1.5
        static let normal: TimeInterval = 1.0
        static let low: TimeInterval = 0.8
    }

    /// 消息长度影响时长的规则
    enum MessageLengthImpact {
        /// 每 N 个字符增加额外时间
        static let charactersPerExtraSecond = 50

        /// 最多增加的额外时间 (秒)
        static let maxExtraTime: TimeInterval = 2.0
    }

    /// 交互式通知显示时长 (秒)
    static let actionableDuration: TimeInterval = 30.0

    /// Diff 通知显示时长 (秒)
    static let diffDuration: TimeInterval = 2.0

    /// 批量保存防抖延迟 (秒)
    static let batchSaveDebounce: TimeInterval = 0.1
}

// MARK: - Socket Constants

enum SocketConstants {
    /// 最大重试次数
    static let maxRetries = 3

    /// 重试延迟 (秒)
    static let retryDelay: TimeInterval = 2.0

    /// 健康检查间隔 (秒)
    static let healthCheckInterval: TimeInterval = 30.0

    /// 最大请求大小 (bytes)
    static let maxRequestSize = 1_048_576  // 1MB

    /// Socket 路径
    static var socketPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Containers/com.qingchang.notchnoti/Data/.notch.sock"
    }

    /// 接收缓冲区大小 (bytes)
    static let receiveBufferSize = 65_536  // 64KB
}

// MARK: - Statistics Constants

enum StatisticsConstants {
    /// 最大会话历史数量
    static let maxSessionHistory = 20

    /// 工作强度阈值 (操作/分钟)
    enum IntensityThreshold {
        static let intense: Double = 8.0
        static let focused: Double = 4.0
        static let steady: Double = 1.0
    }

    /// 工作模式判断阈值
    enum WorkModeThreshold {
        /// 读取操作 vs 写入操作的倍数阈值 (研究模式)
        static let researchingRatio: Double = 2.0

        /// 执行操作占比阈值 (调试模式)
        static let debuggingRatio: Double = 1.0 / 3.0
    }

    /// 时间范围定义 (小时)
    enum TimeRange {
        static let day = 24
        static let week = 7 * 24
    }

    /// 热力图配置
    enum HeatMap {
        /// 每天的时间块数量
        static let timeBlocksPerDay = 6

        /// 每个时间块的小时数
        static let hoursPerBlock = 4

        /// 最大强度计算基准 (通知数)
        static let maxCountForIntensity = 30
    }

    /// AI洞察分析阈值
    enum InsightThreshold {
        /// 最少活动数量 (触发洞察分析)
        static let minActivities = 5

        /// 最短会话时长 (秒,触发洞察分析)
        static let minSessionDuration: TimeInterval = 600  // 10分钟

        /// 错误率警告阈值 (百分比)
        static let maxErrorRatePercent: Double = 15.0
    }
}

// MARK: - UI Constants

enum UIConstants {
    /// 刘海打开尺寸
    static let notchOpenedSize = CGSize(width: 600, height: 160)

    /// 拖拽检测范围 (points)
    static let dropDetectorRange: CGFloat = 32

    /// 动画参数 (ProMotion 120Hz 优化)
    enum Animation {
        static let mass: Double = 0.7
        static let stiffness: Double = 450
        static let damping: Double = 28
    }

    /// 紧凑视图字体大小
    enum CompactFontSize {
        static let caption: CGFloat = 10
        static let caption2: CGFloat = 8
        static let title: CGFloat = 16
    }

    /// 间距
    enum Spacing {
        static let tight: CGFloat = 4
        static let normal: CGFloat = 8
        static let relaxed: CGFloat = 12
        static let loose: CGFloat = 16
    }

    /// UI延迟时间 (秒)
    enum Delay {
        static let short: TimeInterval = 0.1
        static let medium: TimeInterval = 0.5
        static let long: TimeInterval = 1.0
        static let exitApp: TimeInterval = 2.0
        static let settingsReset: TimeInterval = 2.0
        static let summaryWindow: TimeInterval = 3.0
    }
}

// MARK: - MCP Constants

enum MCPConstants {
    /// MCP 工具超时时间 (秒)
    static let toolTimeout: TimeInterval = 50.0

    /// Pending action 存储路径
    static var pendingActionStorePath: String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("notch_pending_actions.json")
            .path
    }
}

// MARK: - Performance Constants

enum PerformanceConstants {
    /// 分页加载页面大小
    static let defaultPageSize = 20

    /// CoreData 批量操作大小
    static let batchSize = 100

    /// 搜索去抖延迟 (秒)
    static let searchDebounce: TimeInterval = 0.3

    /// 内存警告时清理的对象数量
    static let memoryWarningCleanupCount = 100
}

// MARK: - File Constants

enum FileConstants {
    /// Diff 文件存储路径
    static func diffDirectory(for project: String) -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("NotchNoti")
            .appendingPathComponent("diffs")
            .appendingPathComponent(project)
            .path
    }

    /// PID 文件路径
    static var pidFilePath: String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("notchnoti.pid")
            .path
    }

    /// 最大 diff 文件保留数量
    static let maxDiffFiles = 100

    /// Diff 文件过期时间 (天)
    static let diffExpirationDays = 7
}

// MARK: - Metadata Keys

enum MetadataKeys {
    static let source = "source"
    static let project = "project"
    static let projectPath = "project_path"
    static let eventType = "event_type"
    static let sessionId = "session_id"
    static let toolName = "tool_name"
    static let duration = "duration"
    static let errorMessage = "error_message"
    static let context = "context"
    static let diffPath = "diff_path"
    static let filePath = "file_path"
    static let isPreview = "is_preview"
    static let actionable = "actionable"
    static let requestId = "request_id"
    static let interactive = "interactive"
    static let summaryData = "summary_data"
    static let summaryId = "summary_id"
    static let progress = "progress"
    static let userChoice = "user_choice"
    static let promptType = "prompt_type"
    static let promptText = "prompt_text"
    static let sessionDuration = "session_duration"

    // MARK: - 废弃键名 (仅用于向后兼容)

    /// @deprecated 使用 eventType 代替
    @available(*, deprecated, renamed: "eventType", message: "使用 MetadataKeys.eventType")
    static let event = "event"

    /// @deprecated 使用 toolName 代替
    @available(*, deprecated, renamed: "toolName", message: "使用 MetadataKeys.toolName")
    static let tool = "tool"
}

// MARK: - Dictionary扩展 (元数据访问助手)

extension Dictionary where Key == String, Value == String {

    /// 安全获取事件类型 (兼容旧键名)
    var eventType: String? {
        return self[MetadataKeys.eventType] ?? self["event"]
    }

    /// 安全获取工具名称 (兼容旧键名)
    var toolName: String? {
        return self[MetadataKeys.toolName] ?? self["tool"]
    }

    /// 获取项目名称
    var project: String? {
        return self[MetadataKeys.project]
    }

    /// 获取文件路径
    var filePath: String? {
        return self[MetadataKeys.filePath]
    }

    /// 获取diff路径
    var diffPath: String? {
        return self[MetadataKeys.diffPath]
    }

    /// 获取持续时间
    var duration: TimeInterval? {
        return self[MetadataKeys.duration].flatMap { TimeInterval($0) }
    }
}

// MARK: - Type-Safe Metadata Wrapper

/// 类型安全的元数据包装器
struct NotificationMetadata {
    // 核心字段
    var source: String?
    var project: String?
    var projectPath: String?

    // 事件信息
    var eventType: String?
    var sessionId: String?
    var toolName: String?
    var duration: TimeInterval?

    // 错误信息
    var errorMessage: String?
    var context: String?

    // 文件信息
    var diffPath: String?
    var filePath: String?
    var isPreview: Bool?

    // 交互信息
    var actionable: Bool?
    var requestId: String?
    var interactive: Bool?

    // 总结和进度
    var summaryData: String?
    var summaryId: String?
    var progress: Double?

    // 用户选择
    var userChoice: String?

    // 从字典构造
    init(from dict: [String: String]?) {
        guard let dict = dict else { return }

        self.source = dict[MetadataKeys.source]
        self.project = dict[MetadataKeys.project]
        self.projectPath = dict[MetadataKeys.projectPath]

        self.eventType = dict[MetadataKeys.eventType]
        self.sessionId = dict[MetadataKeys.sessionId]
        self.toolName = dict[MetadataKeys.toolName]
        self.duration = dict[MetadataKeys.duration].flatMap { TimeInterval($0) }

        self.errorMessage = dict[MetadataKeys.errorMessage]
        self.context = dict[MetadataKeys.context]

        self.diffPath = dict[MetadataKeys.diffPath]
        self.filePath = dict[MetadataKeys.filePath]
        self.isPreview = dict[MetadataKeys.isPreview] == "true"

        self.actionable = dict[MetadataKeys.actionable] == "true"
        self.requestId = dict[MetadataKeys.requestId]
        self.interactive = dict[MetadataKeys.interactive] == "true"

        self.summaryData = dict[MetadataKeys.summaryData]
        self.summaryId = dict[MetadataKeys.summaryId]
        self.progress = dict[MetadataKeys.progress].flatMap { Double($0) }

        self.userChoice = dict[MetadataKeys.userChoice]
    }

    // 转换为字典
    func toDictionary() -> [String: String] {
        var dict: [String: String] = [:]

        if let source = source { dict[MetadataKeys.source] = source }
        if let project = project { dict[MetadataKeys.project] = project }
        if let projectPath = projectPath { dict[MetadataKeys.projectPath] = projectPath }

        if let eventType = eventType { dict[MetadataKeys.eventType] = eventType }
        if let sessionId = sessionId { dict[MetadataKeys.sessionId] = sessionId }
        if let toolName = toolName { dict[MetadataKeys.toolName] = toolName }
        if let duration = duration { dict[MetadataKeys.duration] = String(duration) }

        if let errorMessage = errorMessage { dict[MetadataKeys.errorMessage] = errorMessage }
        if let context = context { dict[MetadataKeys.context] = context }

        if let diffPath = diffPath { dict[MetadataKeys.diffPath] = diffPath }
        if let filePath = filePath { dict[MetadataKeys.filePath] = filePath }
        if let isPreview = isPreview { dict[MetadataKeys.isPreview] = isPreview ? "true" : "false" }

        if let actionable = actionable { dict[MetadataKeys.actionable] = actionable ? "true" : "false" }
        if let requestId = requestId { dict[MetadataKeys.requestId] = requestId }
        if let interactive = interactive { dict[MetadataKeys.interactive] = interactive ? "true" : "false" }

        if let summaryData = summaryData { dict[MetadataKeys.summaryData] = summaryData }
        if let summaryId = summaryId { dict[MetadataKeys.summaryId] = summaryId }
        if let progress = progress { dict[MetadataKeys.progress] = String(progress) }

        if let userChoice = userChoice { dict[MetadataKeys.userChoice] = userChoice }

        return dict
    }
}

// MARK: - Environment Variables

enum EnvironmentVariables {
    /// Socket 路径覆盖
    static var socketPath: String? {
        ProcessInfo.processInfo.environment["NOTCH_SOCKET_PATH"]
    }

    /// 项目目录
    static var projectDirectory: String? {
        ProcessInfo.processInfo.environment["CLAUDE_PROJECT_DIR"]
    }

    /// 是否为测试模式
    static var isTestMode: Bool {
        ProcessInfo.processInfo.environment["NOTCH_TEST_MODE"] == "1"
    }

    /// 日志级别
    static var logLevel: String {
        ProcessInfo.processInfo.environment["NOTCH_LOG_LEVEL"] ?? "info"
    }
}
