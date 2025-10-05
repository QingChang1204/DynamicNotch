//
//  NotificationManager_v2.swift
//  NotchNoti
//
//  现代化的通知管理器 - Actor 重构版本
//  替换旧的 NotificationModel.swift 中的 NotificationManager
//
//  使用说明:
//  1. 在 Xcode 中创建 NotchNoti.xcdatamodeld (参考 CoreDataModel.md)
//  2. 将此文件重命名为 NotificationManager.swift
//  3. 删除旧的 NotificationModel.swift 中的 NotificationManager 类
//

import Combine
import Foundation

// MARK: - Notification Manager Actor

@globalActor
actor NotificationManager {
    static let shared = NotificationManager()

    // MARK: - Properties

    private let repository: NotificationRepository
    private let viewModel: NotchViewModel?

    // 当前显示的通知
    private(set) var currentNotification: NotchNotification?

    // 待处理队列 (优先级排序)
    private var pendingQueue: [NotchNotification] = []

    // 内存缓存 (用于 UI 快速访问)
    private var cachedHistory: [NotchNotification] = []

    // 定时器 (弱引用防止循环)
    private var hideTimer: Timer?

    // 合并窗口跟踪
    private var lastNotificationTime: Date?
    private var lastNotificationSource: String?

    // MARK: - Initialization

    private init(repository: NotificationRepository = NotificationRepository()) {
        self.repository = repository
        self.viewModel = NotchViewModel.shared

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
        if notification.priority == .urgent {
            // 紧急通知立即打断
            await displayImmediately(notification)
        } else if currentNotification == nil {
            // 当前无通知,直接显示
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
    func getHistory(page: Int = 0, pageSize: Int = NotificationConstants.maxHistoryCount) async -> [NotchNotification] {
        // 优先从缓存读取
        if page == 0 {
            return Array(cachedHistory.prefix(pageSize))
        }

        // 缓存外的数据从数据库读取
        do {
            return try await repository.fetch(page: page, pageSize: pageSize)
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
    func hideCurrentNotification() async {
        hideTimer?.invalidate()
        hideTimer = nil

        currentNotification = nil

        await MainActor.run {
            viewModel?.returnToNormal()
        }

        // 显示下一个
        await showNextInQueue()
    }

    /// 清理旧数据
    func cleanup() async {
        do {
            try await repository.cleanup(keepRecent: NotificationConstants.maxPersistentCount)
        } catch {
            print("[NotificationManager] Cleanup failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    /// 加载初始缓存
    private func loadInitialCache() async {
        do {
            cachedHistory = try await repository.fetch(page: 0, pageSize: NotificationConstants.maxHistoryCount)
            print("[NotificationManager] Loaded \(cachedHistory.count) cached notifications")
        } catch {
            print("[NotificationManager] Failed to load cache: \(error.localizedDescription)")
        }
    }

    /// 更新缓存
    private func updateCache(with notification: NotchNotification) {
        cachedHistory.insert(notification, at: 0)

        if cachedHistory.count > NotificationConstants.maxHistoryCount {
            cachedHistory.removeLast()
        }
    }

    /// 判断是否应该合并
    private func shouldMerge(_ notification: NotchNotification) -> Bool {
        guard let lastTime = lastNotificationTime,
              let lastSource = lastNotificationSource,
              let currentSource = notification.metadata?[MetadataKeys.source] else {
            return false
        }

        let timeSinceL

ast = Date().timeIntervalSince(lastTime)

        return timeSinceL

ast < NotificationConstants.mergeTimeWindow && lastSource == currentSource
    }

    /// 立即显示通知
    private func displayImmediately(_ notification: NotchNotification) async {
        currentNotification = notification

        await MainActor.run {
            viewModel?.showNotification(notification)
            viewModel?.notchOpen(.notification)
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

        // 限制队列长度
        if pendingQueue.count > NotificationConstants.maxQueueSize {
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
        // 基础时长
        var duration: TimeInterval
        switch notification.priority {
        case .urgent:
            duration = NotificationConstants.DurationByPriority.urgent
        case .high:
            duration = NotificationConstants.DurationByPriority.high
        case .normal:
            duration = NotificationConstants.DurationByPriority.normal
        case .low:
            duration = NotificationConstants.DurationByPriority.low
        }

        // 消息长度影响
        let messageLength = notification.message.count
        let extraTime = Double(messageLength / NotificationConstants.MessageLengthImpact.charactersPerExtraSecond) * 0.5
        duration += min(extraTime, NotificationConstants.MessageLengthImpact.maxExtraTime)

        // 特殊类型
        if notification.metadata?[MetadataKeys.diffPath] != nil {
            duration = NotificationConstants.diffDuration
        }

        if notification.actions != nil {
            duration = NotificationConstants.actionableDuration
        }

        return duration
    }

    /// 设置自动隐藏定时器
    private func scheduleHide(after duration: TimeInterval) {
        hideTimer?.invalidate()

        hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { [weak self] in
                await self?.hideCurrentNotification()
            }
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

// MARK: - ViewModel Integration

extension NotchViewModel {
    func showNotification(_ notification: NotchNotification) {
        currentNotification = notification
    }
}
