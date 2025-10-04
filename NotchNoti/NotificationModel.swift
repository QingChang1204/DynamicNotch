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
    
    enum NotificationType: String, Codable {
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
            return .purple  // AI 使用渐变，这里是基础色
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

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var notifications: [NotchNotification] = []
    @Published var currentNotification: NotchNotification?
    @Published var showNotification: Bool = false
    @Published var notificationHistory: [NotchNotification] = []  // 内存层：UI显示用的热数据（50条）
    @Published var pendingNotifications: [NotchNotification] = []  // 通知队列
    @Published var mergedCount: Int = 0  // 合并的通知数量

    // 双层存储配置
    private let maxHistoryCount = 50  // 内存层：UI显示的最大数量（避免卡顿）
    private let maxPersistentCount = 1000  // 持久层：完整历史记录数量（用于统计分析）
    private let maxQueueSize = 10  // 最大队列长度
    private var displayDuration: TimeInterval = 1.0  // 基础显示时间
    private weak var hideTimer: Timer?  // 使用 weak 避免循环引用
    private let timerQueue = DispatchQueue(label: "com.notchdrop.timer", qos: .userInteractive)

    // 持久层存储键
    private let persistentStorageKey = "com.notchnoti.fullHistory"
    
    // 通知合并时间窗口
    private let mergeTimeWindow: TimeInterval = 0.5
    private var lastNotificationTime: Date?
    private var lastNotificationSource: String?

    private init() {}

    deinit {
        print("[NotificationManager] Deinit - 清理资源")
        invalidateTimers()
        // 注意：由于这是单例，deinit 在正常情况下不会被调用
        // 但添加这个方法作为安全保障，防止未来架构调整时出现内存泄漏
    }

    func addNotification(_ notification: NotchNotification) {
        // 确保在主线程执行
        if Thread.isMainThread {
            addNotificationOnMainThread(notification)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.addNotificationOnMainThread(notification)
            }
        }
    }
    
    private func addNotificationOnMainThread(_ notification: NotchNotification) {
        print("[NotificationManager] 收到新通知: \(notification.title)")

        // 先添加到历史记录和统计（确保不会丢失任何通知）
        addToHistory(notification)
        NotificationStatsManager.shared.recordNotification(notification)

        // 检查用户是否正在浏览其他页面（非主页内容）
        let userIsViewingOtherContent = NotchViewModel.shared?.contentType != .normal &&
                                        NotchViewModel.shared?.contentType != .menu

        // 检查是否可以合并通知
        if shouldMergeNotification(notification) {
            mergedCount += 1
            print("[NotificationManager] 合并通知，当前合并数: \(mergedCount)")

            // 更新当前通知的标题显示合并数量（使用正则替换避免重复添加括号）
            if let current = currentNotification {
                var updatedTitle = current.title

                // 检查标题是否已包含合并计数
                if let range = updatedTitle.range(of: #"\s*\(\d+\)$"#, options: .regularExpression) {
                    // 已有计数，替换数字
                    updatedTitle.removeSubrange(range)
                }

                // 添加新的计数（总共合并了 mergedCount + 1 个通知：原始 + 合并的）
                updatedTitle = "\(updatedTitle) (\(mergedCount + 1))"

                // 创建更新后的通知（保持所有其他属性不变）
                let updatedNotification = NotchNotification(
                    title: updatedTitle,
                    message: current.message,
                    type: current.type,
                    priority: current.priority,
                    icon: current.icon,
                    actions: current.actions,
                    metadata: current.metadata
                )

                self.currentNotification = updatedNotification
                print("[NotificationManager] 更新标题为: \(updatedTitle)")
            }
        } else {
            // 重置合并计数（新的通知序列开始）
            mergedCount = 0

            // 如果用户正在浏览其他页面（统计/AI分析/设置等），非紧急通知直接入队列
            if userIsViewingOtherContent && notification.priority != .urgent {
                print("[NotificationManager] 用户正在浏览其他内容，通知入队列: \(notification.title)")
                enqueueNotification(notification)
            } else {
                // 根据优先级处理通知
                if notification.priority == .urgent {
                    // 紧急通知立即显示（即使用户在看其他内容）
                    processUrgentNotification(notification)
                } else if showNotification && currentNotification != nil {
                    // 如果正在显示通知，将新通知加入队列
                    enqueueNotification(notification)
                } else {
                    // 直接显示通知
                    displayNotification(notification)
                }
            }
        }

        // 更新最后通知信息用于合并判断
        lastNotificationTime = Date()
        lastNotificationSource = notification.metadata?["source"] ?? notification.title
    }
    
    private func shouldMergeNotification(_ notification: NotchNotification) -> Bool {
        guard let lastTime = lastNotificationTime,
              let lastSource = lastNotificationSource,
              let currentSource = notification.metadata?["source"] ?? Optional(notification.title) else {
            return false
        }
        
        let timeDiff = Date().timeIntervalSince(lastTime)
        return timeDiff < mergeTimeWindow && lastSource == currentSource && showNotification
    }
    
    private func processUrgentNotification(_ notification: NotchNotification) {
        print("[NotificationManager] 处理紧急通知")

        // 如果有正在显示的通知，将其加入队列前端
        if let current = currentNotification, current.priority != .urgent {
            // 检查队列是否已满
            if pendingNotifications.count >= maxQueueSize {
                // 队列已满，移除优先级最低的通知为当前通知腾出空间
                if let lowestPriorityIndex = pendingNotifications.indices.min(by: {
                    pendingNotifications[$0].priority.rawValue < pendingNotifications[$1].priority.rawValue
                }) {
                    let removed = pendingNotifications.remove(at: lowestPriorityIndex)
                    print("[NotificationManager] 队列已满，移除低优先级通知: \(removed.title)")
                }
            }

            // 将当前通知插入队列前端（保证被打断的通知优先显示）
            pendingNotifications.insert(current, at: 0)
            print("[NotificationManager] 当前通知已保存到队列，队列长度: \(pendingNotifications.count)")
        }

        displayNotification(notification, duration: 2.0) // 紧急通知显示更久
    }
    
    private func enqueueNotification(_ notification: NotchNotification) {
        print("[NotificationManager] 将通知加入队列")
        
        // 按优先级插入队列
        let insertIndex = pendingNotifications.firstIndex { $0.priority.rawValue < notification.priority.rawValue } ?? pendingNotifications.count
        pendingNotifications.insert(notification, at: insertIndex)
        
        // 限制队列大小
        if pendingNotifications.count > maxQueueSize {
            pendingNotifications.removeLast()
        }
    }
    
    private func displayNotification(_ notification: NotchNotification, duration: TimeInterval? = nil) {
        print("[NotificationManager] 显示通知: \(notification.title)")
        
        // 取消现有计时器
        invalidateTimers()
        
        // 设置当前通知
        self.currentNotification = notification
        self.showNotification = true
        self.mergedCount = 0
        
        // 确保刘海是打开的
        if NotchViewModel.shared?.status != .opened {
            NotchViewModel.shared?.notchOpen(.drag)
        }
        
        // 播放通知声音
        if NotchViewModel.shared?.notificationSound == true {
            playNotificationSound(for: notification)
        }
        
        // 根据优先级和内容长度计算显示时间
        let calculatedDuration = duration ?? calculateDisplayDuration(for: notification)
        startHideTimer(duration: calculatedDuration)
    }
    
    private func playNotificationSound(for notification: NotchNotification) {
        // 根据通知类型播放不同的系统声音
        let soundName: NSSound.Name? = switch notification.type {
        case .success:
            NSSound.Name("Glass")
        case .error:
            NSSound.Name("Basso")
        case .warning:
            NSSound.Name("Blow")
        case .celebration:
            NSSound.Name("Glass")  // 庆祝声音
        case .reminder:
            NSSound.Name("Ping")  // 提醒声音
        case .security:
            NSSound.Name("Sosumi")  // 安全警告声音
        case .ai:
            NSSound.Name("Hero")  // AI 处理声音
        case .sync, .download, .upload:
            NSSound.Name("Tink")  // 同步/传输声音
        case .info, .hook, .toolUse, .progress:
            NSSound.Name("Pop")
        }
        
        if let soundName = soundName {
            NSSound(named: soundName)?.play()
        }
    }
    
    private func calculateDisplayDuration(for notification: NotchNotification) -> TimeInterval {
        var duration = displayDuration
        
        // 如果有 diff 信息，延长显示时间
        if notification.metadata?["diff_path"] != nil {
            duration = 2.0  // diff 通知显示更久
        } else {
            // 根据优先级调整
            switch notification.priority {
            case .urgent:
                duration = 2.0
            case .high:
                duration = 1.5
            case .normal:
                duration = 1.0
            case .low:
                duration = 0.8
            }
        }
        
        // 根据消息长度调整（每50字符增加0.5秒）
        let extraTime = Double(notification.message.count / 50) * 0.5
        duration += min(extraTime, 2.0) // 最多额外2秒
        
        return duration
    }
    
    private func addToHistory(_ notification: NotchNotification) {
        // 内存层：LRU缓存策略（UI显示用，50条）
        notificationHistory.removeAll { $0.id == notification.id }
        notificationHistory.insert(notification, at: 0)

        // 限制内存历史记录大小（避免UI卡顿）
        if notificationHistory.count > maxHistoryCount {
            notificationHistory.removeLast()
        }

        // 持久层：完整历史记录（统计分析用，1000条）
        saveToPersistentStorage(notification)
    }

    // 保存到持久层存储
    private func saveToPersistentStorage(_ notification: NotchNotification) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            var fullHistory = self.loadFullHistory()

            // 添加新通知到持久层
            fullHistory.removeAll { $0.id == notification.id }
            fullHistory.insert(notification, at: 0)

            // 限制持久层大小（1000条）
            if fullHistory.count > self.maxPersistentCount {
                fullHistory = Array(fullHistory.prefix(self.maxPersistentCount))
            }

            // 保存到 UserDefaults
            if let encoded = try? JSONEncoder().encode(fullHistory) {
                UserDefaults.standard.set(encoded, forKey: self.persistentStorageKey)
            }
        }
    }

    // 从持久层加载完整历史
    func loadFullHistory() -> [NotchNotification] {
        guard let data = UserDefaults.standard.data(forKey: persistentStorageKey),
              let history = try? JSONDecoder().decode([NotchNotification].self, from: data) else {
            return []
        }
        return history
    }

    // 获取完整历史记录（用于统计分析）
    func getFullHistoryForAnalysis() -> [NotchNotification] {
        return loadFullHistory()
    }

    // 获取过滤后的历史记录（支持日期范围、类型过滤等）
    func getFilteredHistory(
        startDate: Date? = nil,
        endDate: Date? = nil,
        types: [NotchNotification.NotificationType]? = nil,
        priorities: [NotchNotification.Priority]? = nil
    ) -> [NotchNotification] {
        var history = loadFullHistory()

        if let start = startDate {
            history = history.filter { $0.timestamp >= start }
        }

        if let end = endDate {
            history = history.filter { $0.timestamp <= end }
        }

        if let filterTypes = types {
            history = history.filter { filterTypes.contains($0.type) }
        }

        if let filterPriorities = priorities {
            history = history.filter { filterPriorities.contains($0.priority) }
        }

        return history
    }

    // 清除持久层历史记录
    func clearPersistentHistory() {
        UserDefaults.standard.removeObject(forKey: persistentStorageKey)
    }
    
    private func invalidateTimers() {
        hideTimer?.invalidate()
        hideTimer = nil
    }
    
    func cancelHideTimer() {
        print("[NotificationManager] 取消自动隐藏")
        hideTimer?.invalidate()
        hideTimer = nil
    }
    
    func restartHideTimer() {
        print("[NotificationManager] 重新开始计时")
        startHideTimer(duration: 1.0)
    }
    
    private func startHideTimer(duration: TimeInterval = 1.0) {
        timerQueue.async { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.hideTimer?.invalidate()
                self?.hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                    print("[NotificationManager] 计时器触发，准备隐藏通知")
                    self?.hideCurrentNotification()
                }
                if let timer = self?.hideTimer {
                    RunLoop.main.add(timer, forMode: .common)
                }
            }
        }
    }
    
    private func showNextNotification() {
        guard !pendingNotifications.isEmpty else {
            // 没有待处理的通知，关闭刘海
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                if self?.showNotification == false {
                    NotchViewModel.shared?.notchClose()
                }
            }
            return
        }
        
        // 显示下一个通知
        let nextNotification = pendingNotifications.removeFirst()
        displayNotification(nextNotification)
    }
    
    func hideCurrentNotification() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("[NotificationManager] 隐藏当前通知")
            self.showNotification = false
            self.currentNotification = nil
            self.mergedCount = 0
            
            // 检查是否有待处理的通知
            if !self.pendingNotifications.isEmpty {
                // 检查用户是否正在浏览其他页面
                let userIsViewingOtherContent = NotchViewModel.shared?.contentType != .normal &&
                                                NotchViewModel.shared?.contentType != .menu

                if userIsViewingOtherContent {
                    // 用户正在浏览其他内容，暂时不显示队列中的通知
                    print("[NotificationManager] 用户正在浏览其他内容，暂不显示队列通知")
                } else {
                    // 短暂延迟后显示下一个通知
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.showNextNotification()
                    }
                }
            } else {
                // 没有更多通知，检查用户是否在浏览其他内容
                let userIsViewingOtherContent = NotchViewModel.shared?.contentType != .normal &&
                                                NotchViewModel.shared?.contentType != .menu

                if !userIsViewingOtherContent {
                    // 只有在主页面时才关闭刘海
                    print("[NotificationManager] 无待处理通知，关闭刘海")
                    NotchViewModel.shared?.notchClose()
                } else {
                    print("[NotificationManager] 用户正在浏览其他内容，保持刘海打开")
                }
            }
        }
    }
    
    func clearHistory() {
        notificationHistory.removeAll()
    }

    /// 记录用户对交互式通知的选择
    func recordUserChoice(for notificationId: UUID, choice: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 在历史记录中找到对应的通知并更新
            if let index = self.notificationHistory.firstIndex(where: { $0.id == notificationId }) {
                // 直接修改 metadata（现在 metadata 是 var 了）
                if self.notificationHistory[index].metadata != nil {
                    self.notificationHistory[index].metadata?["user_choice"] = choice
                } else {
                    self.notificationHistory[index].metadata = ["user_choice": choice]
                }

                print("[NotificationManager] 记录用户选择: \(choice) for \(notificationId)")

                // 同时更新持久化存储
                self.updatePersistentStorageUserChoice(notificationId: notificationId, choice: choice)
            }
        }
    }

    private func updatePersistentStorageUserChoice(notificationId: UUID, choice: String) {
        var fullHistory = loadFullHistory()
        if let index = fullHistory.firstIndex(where: { $0.id == notificationId }) {
            // 直接修改 metadata
            if fullHistory[index].metadata != nil {
                fullHistory[index].metadata?["user_choice"] = choice
            } else {
                fullHistory[index].metadata = ["user_choice": choice]
            }

            if let data = try? JSONEncoder().encode(fullHistory) {
                UserDefaults.standard.set(data, forKey: persistentStorageKey)
            }
        }
    }

    /// 当用户返回主页面时，检查并显示待处理的通知
    func checkAndShowPendingNotifications() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 只有在没有正在显示的通知时，才显示队列中的通知
            if !self.showNotification && !self.pendingNotifications.isEmpty {
                print("[NotificationManager] 用户返回主页，显示队列中的通知")
                self.showNextNotification()
            }
        }
    }

    func handleAction(_ action: NotificationAction) {
        print("[NotificationManager] Handling action: \(action.action)")
        // TODO: Implement action handling
    }
}