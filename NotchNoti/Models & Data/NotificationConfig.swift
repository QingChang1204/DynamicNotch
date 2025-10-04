//
//  NotificationConfig.swift
//  NotchNoti
//
//  统一的通知配置系统
//  支持全局配置、类型配置、静默规则等
//

import Foundation
import SwiftUI

// MARK: - 通知配置管理器
class NotificationConfigManager: ObservableObject {
    static let shared = NotificationConfigManager()

    // MARK: - 全局配置
    @PublishedPersist(key: "notificationConfig.globalEnabled", defaultValue: true)
    var globalEnabled: Bool

    // 声音和触觉使用 ViewModel 的配置（避免重复）
    var globalSoundEnabled: Bool {
        get { NotchViewModel.shared?.notificationSound ?? true }
        set { NotchViewModel.shared?.notificationSound = newValue }
    }

    var globalHapticEnabled: Bool {
        get { NotchViewModel.shared?.hapticFeedback ?? true }
        set { NotchViewModel.shared?.hapticFeedback = newValue }
    }

    @PublishedPersist(key: "notificationConfig.defaultDuration", defaultValue: 1.0)
    var defaultDuration: TimeInterval

    @PublishedPersist(key: "notificationConfig.showInDND", defaultValue: false)
    var showInDoNotDisturb: Bool

    // MARK: - 类型配置（JSON存储）
    @PublishedPersist(key: "notificationConfig.typeConfigs", defaultValue: [:])
    private var typeConfigsStorage: [String: TypeConfig]

    // MARK: - 静默规则
    @PublishedPersist(key: "notificationConfig.silentRules", defaultValue: [])
    var silentRules: [SilentRule]

    // MARK: - 智能合并配置
    @PublishedPersist(key: "notificationConfig.smartMerge", defaultValue: true)
    var smartMergeEnabled: Bool

    @PublishedPersist(key: "notificationConfig.mergeWindow", defaultValue: 0.5)
    var mergeTimeWindow: TimeInterval

    // MARK: - 高级配置
    @PublishedPersist(key: "notificationConfig.maxHistoryCount", defaultValue: 50)
    var maxHistoryCount: Int  // UI 显示的最大历史数量

    @PublishedPersist(key: "notificationConfig.maxPersistentCount", defaultValue: 5000)
    var maxPersistentCount: Int  // 持久化存储的最大数量

    @PublishedPersist(key: "notificationConfig.maxQueueSize", defaultValue: 10)
    var maxQueueSize: Int  // 通知队列最大长度

    private init() {
        // 确保所有类型都有默认配置
        initializeDefaultConfigs()
    }

    // 初始化默认配置
    private func initializeDefaultConfigs() {
        for type in NotchNotification.NotificationType.allCases {
            if typeConfigsStorage[type.rawValue] == nil {
                typeConfigsStorage[type.rawValue] = TypeConfig.default(for: type)
            }
        }
    }

    // MARK: - 预设规则模板
    static func createPresetRule(_ preset: PresetRule) -> SilentRule {
        switch preset {
        case .nightMode:
            return SilentRule(
                name: "夜间免打扰（22:00-07:00）",
                conditions: [
                    .timeRange(start: 22, end: 7),
                    .priority(.low, .lessOrEqual)
                ],
                action: .silence
            )

        case .workHours:
            return SilentRule(
                name: "工作时间静音（09:00-18:00）",
                conditions: [
                    .timeRange(start: 9, end: 18),
                    .type([.info, .hook, .toolUse])
                ],
                action: .muteSound
            )

        case .errorsOnly:
            return SilentRule(
                name: "仅显示错误和警告",
                conditions: [
                    .type([.info, .success, .hook, .toolUse, .progress, .sync])
                ],
                action: .showInQueue
            )

        case .focusMode:
            return SilentRule(
                name: "专注模式（静音所有通知）",
                conditions: [],
                action: .muteSound
            )
        }
    }

    enum PresetRule: String, CaseIterable {
        case nightMode = "夜间免打扰"
        case workHours = "工作时间静音"
        case errorsOnly = "仅显示错误"
        case focusMode = "专注模式"
    }

    // MARK: - 类型配置访问
    func getTypeConfig(for type: NotchNotification.NotificationType) -> TypeConfig {
        return typeConfigsStorage[type.rawValue] ?? TypeConfig.default(for: type)
    }

    func setTypeConfig(_ config: TypeConfig, for type: NotchNotification.NotificationType) {
        typeConfigsStorage[type.rawValue] = config
    }

    func resetTypeConfig(for type: NotchNotification.NotificationType) {
        typeConfigsStorage[type.rawValue] = TypeConfig.default(for: type)
    }

    // MARK: - 通知检查
    /// 检查通知是否应该显示
    func shouldShowNotification(_ notification: NotchNotification) -> Bool {
        // 全局开关
        guard globalEnabled else { return false }

        // 类型配置
        let typeConfig = getTypeConfig(for: notification.type)
        guard typeConfig.enabled else { return false }

        // 静默规则检查
        for rule in silentRules where rule.enabled {
            if rule.matches(notification) {
                return false
            }
        }

        return true
    }

    /// 检查是否应该播放声音
    func shouldPlaySound(for notification: NotchNotification) -> Bool {
        guard globalSoundEnabled else { return false }

        let typeConfig = getTypeConfig(for: notification.type)
        return typeConfig.soundEnabled
    }

    /// 检查是否应该触发触觉反馈
    func shouldPlayHaptic(for notification: NotchNotification) -> Bool {
        guard globalHapticEnabled else { return false }

        let typeConfig = getTypeConfig(for: notification.type)
        return typeConfig.hapticEnabled
    }

    /// 获取通知的显示时长
    func getDuration(for notification: NotchNotification) -> TimeInterval {
        let typeConfig = getTypeConfig(for: notification.type)

        // 如果类型配置了自定义时长，使用类型时长
        if let customDuration = typeConfig.customDuration {
            return customDuration
        }

        // 否则使用优先级默认时长
        return defaultDuration
    }

    // MARK: - 批量操作
    func resetAllConfigs() {
        for type in NotchNotification.NotificationType.allCases {
            resetTypeConfig(for: type)
        }
    }

    func exportConfig() -> Data? {
        let exportData = ConfigExport(
            globalEnabled: globalEnabled,
            globalSoundEnabled: globalSoundEnabled,  // 从 ViewModel 读取
            globalHapticEnabled: globalHapticEnabled,  // 从 ViewModel 读取
            defaultDuration: defaultDuration,
            typeConfigs: typeConfigsStorage,
            silentRules: silentRules,
            smartMergeEnabled: smartMergeEnabled,
            mergeTimeWindow: mergeTimeWindow
        )

        return try? JSONEncoder().encode(exportData)
    }

    func importConfig(from data: Data) -> Bool {
        guard let imported = try? JSONDecoder().decode(ConfigExport.self, from: data) else {
            return false
        }

        globalEnabled = imported.globalEnabled
        globalSoundEnabled = imported.globalSoundEnabled  // 会写入 ViewModel
        globalHapticEnabled = imported.globalHapticEnabled  // 会写入 ViewModel
        defaultDuration = imported.defaultDuration
        typeConfigsStorage = imported.typeConfigs
        silentRules = imported.silentRules
        smartMergeEnabled = imported.smartMergeEnabled
        mergeTimeWindow = imported.mergeTimeWindow

        return true
    }
}

// MARK: - 类型配置
struct TypeConfig: Codable, Equatable {
    var enabled: Bool
    var soundEnabled: Bool
    var hapticEnabled: Bool
    var customDuration: TimeInterval?  // nil 表示使用默认时长
    var customSoundName: String?       // nil 表示使用类型默认声音

    static func `default`(for type: NotchNotification.NotificationType) -> TypeConfig {
        // 根据类型设置不同的默认值
        switch type {
        case .error, .security:
            return TypeConfig(
                enabled: true,
                soundEnabled: true,
                hapticEnabled: true,
                customDuration: 2.0
            )
        case .warning:
            return TypeConfig(
                enabled: true,
                soundEnabled: true,
                hapticEnabled: true,
                customDuration: 1.5
            )
        case .success, .celebration:
            return TypeConfig(
                enabled: true,
                soundEnabled: true,
                hapticEnabled: false,
                customDuration: 1.0
            )
        case .info, .hook, .toolUse, .progress:
            return TypeConfig(
                enabled: true,
                soundEnabled: false,
                hapticEnabled: false,
                customDuration: nil
            )
        default:
            return TypeConfig(
                enabled: true,
                soundEnabled: true,
                hapticEnabled: true,
                customDuration: nil
            )
        }
    }
}

// MARK: - 静默规则
struct SilentRule: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var enabled: Bool
    var conditions: [RuleCondition]
    var action: RuleAction

    init(name: String, enabled: Bool = true, conditions: [RuleCondition], action: RuleAction = .silence) {
        self.id = UUID()
        self.name = name
        self.enabled = enabled
        self.conditions = conditions
        self.action = action
    }

    func matches(_ notification: NotchNotification) -> Bool {
        guard enabled else { return false }

        // 所有条件都满足才匹配
        return conditions.allSatisfy { $0.matches(notification) }
    }

    enum RuleAction: String, Codable {
        case silence        // 完全静默
        case muteSound      // 只静音
        case muteHaptic     // 只禁用触觉
        case showInQueue    // 显示但不打断当前通知
    }
}

// MARK: - 规则条件
enum RuleCondition: Codable, Equatable {
    case type([NotchNotification.NotificationType])
    case priority(NotchNotification.Priority, ComparisonOperator)
    case source(String)  // metadata.source 匹配
    case titleContains(String)
    case messageContains(String)
    case timeRange(start: Int, end: Int)  // 24小时制，如 22-7 表示晚上10点到早上7点

    enum ComparisonOperator: String, Codable {
        case equal = "=="
        case lessThan = "<"
        case lessOrEqual = "<="
        case greaterThan = ">"
        case greaterOrEqual = ">="
    }

    func matches(_ notification: NotchNotification) -> Bool {
        switch self {
        case .type(let types):
            return types.contains(notification.type)

        case .priority(let priority, let op):
            let notifPriority = notification.priority.rawValue
            let targetPriority = priority.rawValue
            switch op {
            case .equal: return notifPriority == targetPriority
            case .lessThan: return notifPriority < targetPriority
            case .lessOrEqual: return notifPriority <= targetPriority
            case .greaterThan: return notifPriority > targetPriority
            case .greaterOrEqual: return notifPriority >= targetPriority
            }

        case .source(let source):
            return notification.metadata?["source"] == source

        case .titleContains(let text):
            return notification.title.localizedCaseInsensitiveContains(text)

        case .messageContains(let text):
            return notification.message.localizedCaseInsensitiveContains(text)

        case .timeRange(let start, let end):
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: notification.timestamp)

            if start < end {
                return hour >= start && hour < end
            } else {
                // 跨夜情况，如 22-7
                return hour >= start || hour < end
            }
        }
    }
}

// MARK: - 配置导出/导入
struct ConfigExport: Codable {
    let globalEnabled: Bool
    let globalSoundEnabled: Bool
    let globalHapticEnabled: Bool
    let defaultDuration: TimeInterval
    let typeConfigs: [String: TypeConfig]
    let silentRules: [SilentRule]
    let smartMergeEnabled: Bool
    let mergeTimeWindow: TimeInterval
}

// MARK: - NotificationType Extension
extension NotchNotification.NotificationType: CaseIterable {
    public static var allCases: [NotchNotification.NotificationType] {
        return [
            .info, .success, .warning, .error,
            .hook, .toolUse, .progress, .celebration,
            .reminder, .download, .upload, .security,
            .ai, .sync
        ]
    }

    var localizedName: String {
        switch self {
        case .info: return "信息"
        case .success: return "成功"
        case .warning: return "警告"
        case .error: return "错误"
        case .hook: return "Hook"
        case .toolUse: return "工具使用"
        case .progress: return "进度"
        case .celebration: return "庆祝"
        case .reminder: return "提醒"
        case .download: return "下载"
        case .upload: return "上传"
        case .security: return "安全"
        case .ai: return "AI"
        case .sync: return "同步"
        }
    }
}
