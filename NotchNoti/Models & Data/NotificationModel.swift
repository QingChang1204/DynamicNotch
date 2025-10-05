//
//  NotificationModel.swift
//  NotchNoti
//
//  Created for Claude Code Hook Notifications
//

import Foundation
import SwiftUI

struct NotchNotification: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let title: String
    let message: String
    let type: NotificationType
    let priority: Priority
    let icon: String?
    let actions: [NotificationAction]?
    var metadata: [String: String]?  // var 允许修改用户选择等运行时数据

    static func == (lhs: NotchNotification, rhs: NotchNotification) -> Bool {
        lhs.id == rhs.id
    }

    enum NotificationType: String, Codable, CaseIterable {
        case info = "info"
        case success = "success"
        case warning = "warning"
        case error = "error"
        case hook = "hook"
        case toolUse = "tool_use"
        case progress = "progress"
        case celebration = "celebration"
        case reminder = "reminder"
        case download = "download"
        case upload = "upload"
        case security = "security"
        case ai = "ai"
        case sync = "sync"
    }

    enum Priority: Int, Codable {
        case low = 0
        case normal = 1
        case high = 2
        case urgent = 3
    }

    init(
        title: String,
        message: String,
        type: NotificationType = .info,
        priority: Priority = .normal,
        icon: String? = nil,
        actions: [NotificationAction]? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.title = title
        self.message = message
        self.type = type
        self.priority = priority
        self.icon = icon
        self.actions = actions
        self.metadata = metadata
    }

    var color: Color {
        switch type {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        case .hook:
            return .purple
        case .toolUse:
            return .cyan
        case .progress:
            return .gray
        case .celebration:
            return Color(red: 1.0, green: 0.84, blue: 0)  // 金色
        case .reminder:
            return .indigo
        case .download:
            return Color(red: 0, green: 0.8, blue: 0.8)  // 青绿色
        case .upload:
            return Color(red: 0.58, green: 0.0, blue: 0.83)  // 紫罗兰色
        case .security:
            return Color(red: 0.5, green: 0, blue: 0)  // 深红色
        case .ai:
            return .purple  // AI 使用渐变,这里是基础色
        case .sync:
            return Color(red: 0, green: 0.7, blue: 0.7)  // 青绿色
        }
    }

    var systemImage: String {
        switch type {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        case .hook:
            return "link.circle.fill"
        case .toolUse:
            return "wrench.and.screwdriver.fill"
        case .progress:
            return "arrow.trianglehead.clockwise.rotate.90"
        case .celebration:
            return "trophy.fill"
        case .reminder:
            return "bell.badge"
        case .download:
            return "arrow.down.circle.fill"
        case .upload:
            return "arrow.up.circle.fill"
        case .security:
            return "lock.shield.fill"
        case .ai:
            return "brain.head.profile"
        case .sync:
            return "arrow.triangle.2.circlepath"
        }
    }

    /// 生成通知指纹用于去重 (基于类型+标题+消息内容)
    func contentFingerprint() -> String {
        "\(type.rawValue)|\(title)|\(message)"
    }

    /// 类型安全的元数据访问器
    var typedMetadata: NotificationMetadata {
        NotificationMetadata(from: metadata)
    }
}

struct NotificationAction: Codable, Identifiable, Equatable {
    let id: UUID
    let label: String
    let action: String
    let style: ActionStyle

    init(label: String, action: String, style: ActionStyle) {
        self.id = UUID()
        self.label = label
        self.action = action
        self.style = style
    }

    static func == (lhs: NotificationAction, rhs: NotificationAction) -> Bool {
        lhs.id == rhs.id
    }

    enum ActionStyle: String, Codable {
        case normal = "normal"
        case primary = "primary"
        case destructive = "destructive"
    }
}

// MARK: - Notification Request (for JSON decoding from Unix Socket/HTTP)
struct NotificationRequest: Codable {
    let title: String
    let message: String
    let type: String?
    let priority: Int?
    let icon: String?
    let actions: [NotificationActionRequest]?
    let metadata: [String: String]?
}

struct NotificationActionRequest: Codable {
    let label: String
    let action: String
    let style: String?
}

// MARK: - Notification Manager Actor

import Combine
import AppKit

@globalActor
actor NotificationManager {
    static let shared = NotificationManager()

    // MARK: - Properties

    private let repository: NotificationRepository

    /// 动态获取 ViewModel（避免初始化顺序问题）
    /// nonisolated: 允许从任何上下文访问（包括 MainActor）
    private nonisolated var viewModel: NotchViewModel? {
        NotchViewModel.shared
    }

    private let config: NotificationConfigManager

    // 当前显示的通知
    private(set) var currentNotification: NotchNotification?

    // 待处理队列 (优先级排序)
    private var pendingQueue: [NotchNotification] = []

    // 内存缓存 (用于 UI 快速访问)
    private var cachedHistory: [NotchNotification] = []

    // 自动隐藏任务
    private var hideTask: Task<Void, Never>?

    // 合并窗口跟踪
    private var lastNotificationTime: Date?
    private var lastNotificationSource: String?

    // 内容指纹去重 (最近5分钟内的通知指纹)
    private var recentFingerprints: [(fingerprint: String, timestamp: Date)] = []
    private let fingerprintWindow: TimeInterval = 300  // 5分钟

    // MARK: - Initialization

    private init(repository: NotificationRepository = NotificationRepository()) {
        self.repository = repository
        self.config = NotificationConfigManager.shared

        // 启动时加载缓存
        Task {
            await loadInitialCache()
        }
    }

    // MARK: - Public API

    /// 添加新通知
    func addNotification(_ notification: NotchNotification) async {
        // 1. 检查合并
        if shouldMerge(notification) {
            print("[NotificationManager] Merged duplicate notification")
            return
        }

        // 2. 持久化保存
        do {
            try await repository.save(notification)
        } catch {
            print("[NotificationManager] Failed to save: \(error.localizedDescription)")
        }

        // 3. 更新缓存
        updateCache(with: notification)

        // 4. 决定显示策略
        if currentNotification == nil {
            // 当前无通知,直接显示
            await displayImmediately(notification)
        } else if shouldInterrupt(current: currentNotification!, new: notification) {
            // 新通知优先级更高,打断当前通知
            // 将当前通知放回队列头部
            if let current = currentNotification {
                pendingQueue.insert(current, at: 0)
            }
            await displayImmediately(notification)
        } else {
            // 加入队列
            enqueue(notification)
        }

        // 5. 播放声音和触觉
        await playFeedback(for: notification)

        // 6. 更新合并窗口
        lastNotificationTime = Date()
        lastNotificationSource = notification.metadata?[MetadataKeys.source]
    }

    /// 获取历史记录 (分页)
    func getHistory(page: Int = 0, pageSize: Int? = nil) async -> [NotchNotification] {
        // 使用用户配置的历史数量或传入的页面大小
        let effectivePageSize = pageSize ?? config.maxHistoryCount

        // 优先从缓存读取
        if page == 0 {
            return Array(cachedHistory.prefix(effectivePageSize))
        }

        // 缓存外的数据从数据库读取
        do {
            return try await repository.fetch(page: page, pageSize: effectivePageSize)
        } catch {
            print("[NotificationManager] Failed to fetch history: \(error.localizedDescription)")
            return []
        }
    }

    /// 搜索通知
    func search(query: String, page: Int = 0) async -> [NotchNotification] {
        do {
            return try await repository.search(query: query, page: page, pageSize: 20)
        } catch {
            print("[NotificationManager] Search failed: \(error.localizedDescription)")
            return []
        }
    }

    /// 组合查询: 时间 + 类型 + 项目 (优化查询,数据库层过滤)
    func getHistory(
        from startDate: Date,
        to endDate: Date,
        types: [NotchNotification.NotificationType],
        project: String? = nil,
        limit: Int = 2000
    ) async -> [NotchNotification] {
        do {
            return try await repository.fetch(
                from: startDate,
                to: endDate,
                types: types,
                project: project,
                pageSize: limit
            )
        } catch {
            print("[NotificationManager] Filtered query failed: \(error.localizedDescription)")
            return []
        }
    }

    /// 获取统计数据
    func getStatistics() async -> (total: Int, byType: [NotchNotification.NotificationType: Int]) {
        do {
            let total = try await repository.count()

            var byType: [NotchNotification.NotificationType: Int] = [:]
            for type in NotchNotification.NotificationType.allCases {
                let count = try await repository.count(types: [type])
                byType[type] = count
            }

            return (total, byType)
        } catch {
            print("[NotificationManager] Stats failed: \(error.localizedDescription)")
            return (0, [:])
        }
    }

    /// 关闭当前通知
    /// - Parameter showNext: 是否自动显示下一个通知（true=自动超时关闭，false=手动点X关闭）
    func hideCurrentNotification(showNext: Bool = true) async {
        print("[NotificationManager] hideCurrentNotification called - showNext:\(showNext), queueSize:\(pendingQueue.count)")

        // 取消自动隐藏任务
        hideTask?.cancel()
        hideTask = nil

        currentNotification = nil

        // 决定如何关闭
        if showNext && !pendingQueue.isEmpty {
            // 有待处理的通知，显示下一个
            print("[NotificationManager] → Showing next notification from queue")
            await showNextInQueue()
        } else {
            // 没有更多通知，完全关闭刘海
            print("[NotificationManager] → Closing notch completely (no more notifications)")
            await MainActor.run {
                viewModel?.notchClose()
                print("[NotificationManager] → notchClose() called, status should be: \(String(describing: viewModel?.status))")
            }
        }
    }

    /// 清理旧数据
    func cleanup() async {
        do {
            // 使用用户配置的持久化存储上限
            try await repository.cleanup(keepRecent: config.maxPersistentCount)
        } catch {
            print("[NotificationManager] Cleanup failed: \(error.localizedDescription)")
        }
    }

    /// 清除历史记录
    func clearHistory() async {
        do {
            try await repository.clear()
            cachedHistory.removeAll()
            print("[NotificationManager] History cleared")
        } catch {
            print("[NotificationManager] Failed to clear history: \(error.localizedDescription)")
        }
    }

    /// 获取历史记录数量
    func getHistoryCount(searchText: String? = nil) async -> Int {
        do {
            if let query = searchText {
                // For search, we need to fetch and count
                let results = try await repository.search(query: query, page: 0, pageSize: Int.max)
                return results.count
            } else {
                return try await repository.count()
            }
        } catch {
            print("[NotificationManager] Failed to get history count: \(error.localizedDescription)")
            return 0
        }
    }

    /// 分页加载历史记录
    func loadHistoryPage(page: Int, pageSize: Int, searchText: String? = nil) async -> [NotchNotification] {
        if let query = searchText {
            return await search(query: query, page: page)
        } else {
            return await getHistory(page: page, pageSize: pageSize)
        }
    }

    /// 取消隐藏任务
    func cancelHideTimer() {
        hideTask?.cancel()
        hideTask = nil
    }

    /// 重启隐藏定时器
    func restartHideTimer() {
        guard let current = currentNotification else { return }
        let duration = calculateDuration(for: current)
        scheduleHide(after: duration)
    }

    /// 记录用户选择
    func recordUserChoice(for notificationId: UUID, choice: String) {
        // 更新缓存中的通知
        if let index = cachedHistory.firstIndex(where: { $0.id == notificationId }) {
            var notification = cachedHistory[index]
            if notification.metadata == nil {
                notification.metadata = [:]
            }
            notification.metadata?[MetadataKeys.userChoice] = choice
            cachedHistory[index] = notification
        }

        // 更新当前通知
        if currentNotification?.id == notificationId {
            var notification = currentNotification!
            if notification.metadata == nil {
                notification.metadata = [:]
            }
            notification.metadata?[MetadataKeys.userChoice] = choice
            currentNotification = notification
        }
    }

    /// 获取当前是否正在显示通知
    var showNotification: Bool {
        currentNotification != nil
    }

    /// 获取待处理通知列表
    var pendingNotifications: [NotchNotification] {
        pendingQueue
    }

    /// 获取合并计数
    var mergedCount: Int {
        // 简化实现：返回0（实际合并逻辑在shouldMerge中）
        0
    }

    // MARK: - Private Methods

    /// 加载初始缓存
    private func loadInitialCache() async {
        do {
            // 使用用户配置的历史数量
            cachedHistory = try await repository.fetch(page: 0, pageSize: config.maxHistoryCount)
            print("[NotificationManager] Loaded \(cachedHistory.count) cached notifications")
        } catch {
            print("[NotificationManager] Failed to load cache: \(error.localizedDescription)")
        }
    }

    /// 更新缓存
    private func updateCache(with notification: NotchNotification) {
        cachedHistory.insert(notification, at: 0)

        // 使用用户配置的历史数量限制缓存大小
        if cachedHistory.count > config.maxHistoryCount {
            cachedHistory.removeLast()
        }
    }

    /// 判断是否应该合并
    private func shouldMerge(_ notification: NotchNotification) -> Bool {
        // 策略1: 基于时间窗口 + source (快速去重,0.5秒窗口)
        if let lastTime = lastNotificationTime,
           let lastSource = lastNotificationSource,
           let currentSource = notification.metadata?[MetadataKeys.source] {
            let timeSinceLast = Date().timeIntervalSince(lastTime)
            if timeSinceLast < NotificationConstants.mergeTimeWindow && lastSource == currentSource {
                return true
            }
        }

        // 策略2: 基于内容指纹 (智能去重,5分钟窗口)
        let fingerprint = notification.contentFingerprint()
        let now = Date()

        // 清理过期指纹 (5分钟前的)
        recentFingerprints = recentFingerprints.filter {
            now.timeIntervalSince($0.timestamp) < fingerprintWindow
        }

        // 检查是否存在相同指纹
        if recentFingerprints.contains(where: { $0.fingerprint == fingerprint }) {
            print("[NotificationManager] Merged duplicate by fingerprint: \(fingerprint)")
            return true
        }

        // 记录新指纹
        recentFingerprints.append((fingerprint, now))

        return false
    }

    /// 判断新通知是否应该打断当前通知
    private func shouldInterrupt(current: NotchNotification, new: NotchNotification) -> Bool {
        // 紧急通知（priority=3）总是打断
        if new.priority == .urgent {
            return true
        }

        // 高优先级（priority=2）可以打断普通和低优先级
        if new.priority == .high && (current.priority == .normal || current.priority == .low) {
            return true
        }

        // 其他情况不打断
        return false
    }

    /// 立即显示通知
    private func displayImmediately(_ notification: NotchNotification) async {
        currentNotification = notification

        await MainActor.run {
            viewModel?.notchOpen(.click)
        }

        // 设置自动隐藏定时器
        let duration = calculateDuration(for: notification)
        scheduleHide(after: duration)
    }

    /// 加入队列
    private func enqueue(_ notification: NotchNotification) {
        // 优先级排序插入
        if let index = pendingQueue.firstIndex(where: { $0.priority.rawValue < notification.priority.rawValue }) {
            pendingQueue.insert(notification, at: index)
        } else {
            pendingQueue.append(notification)
        }

        // 使用用户配置的队列大小限制
        if pendingQueue.count > config.maxQueueSize {
            pendingQueue.removeLast()
        }
    }

    /// 显示队列中下一个
    private func showNextInQueue() async {
        guard !pendingQueue.isEmpty else { return }

        let next = pendingQueue.removeFirst()
        await displayImmediately(next)
    }

    /// 计算显示时长
    private func calculateDuration(for notification: NotchNotification) -> TimeInterval {
        // 1. 检查是否有 actions（交互式通知）
        if notification.actions != nil {
            return NotificationConstants.actionableDuration  // 30秒，用于交互
        }

        // 2. 检查是否是 diff 通知
        if notification.metadata?[MetadataKeys.diffPath] != nil {
            return NotificationConstants.diffDuration  // 2秒，diff预览
        }

        // 3. 使用用户配置的默认时长（或类型特定时长）
        var duration = config.getDuration(for: notification)

        // 4. 根据消息长度动态调整（可选：如果消息很长，稍微延长显示时间）
        let messageLength = notification.message.count
        if messageLength > NotificationConstants.MessageLengthImpact.charactersPerExtraSecond {
            let extraTime = Double(messageLength / NotificationConstants.MessageLengthImpact.charactersPerExtraSecond) * 0.5
            duration += min(extraTime, NotificationConstants.MessageLengthImpact.maxExtraTime)
        }

        return duration
    }

    /// 设置自动隐藏定时器
    private func scheduleHide(after duration: TimeInterval) {
        // 取消之前的任务
        hideTask?.cancel()

        // 创建新的延迟任务
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

            // 检查任务是否被取消
            guard !Task.isCancelled else { return }

            // 自动超时关闭，允许显示下一个通知
            await self?.hideCurrentNotification(showNext: true)
        }
    }

    /// 播放反馈
    private func playFeedback(for notification: NotchNotification) async {
        await MainActor.run {
            // 声音
            if viewModel?.notificationSound == true {
                notification.playSound()
            }

            // 触觉
            if viewModel?.hapticFeedback == true {
                viewModel?.hapticSender.send()
            }
        }
    }
}

// MARK: - Notification Extension

extension NotchNotification {
    func playSound() {
        // 根据类型播放不同声音
        let soundName: String
        switch type {
        case .error, .security:
            soundName = "Basso"
        case .warning:
            soundName = "Funk"
        case .success, .celebration:
            soundName = "Glass"
        default:
            soundName = "Tink"
        }

        if let sound = NSSound(named: soundName) {
            sound.play()
        }
    }
}
