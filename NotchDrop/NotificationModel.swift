//
//  NotificationModel.swift
//  NotchDrop
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
    let metadata: [String: String]?
    
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

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var notifications: [NotchNotification] = []
    @Published var currentNotification: NotchNotification?
    @Published var showNotification: Bool = false
    @Published var notificationHistory: [NotchNotification] = []
    @Published var pendingNotifications: [NotchNotification] = []  // 通知队列
    @Published var mergedCount: Int = 0  // 合并的通知数量
    
    private let maxHistoryCount = 100
    private let maxQueueSize = 10  // 最大队列长度
    private var displayDuration: TimeInterval = 1.0  // 基础显示时间
    private weak var hideTimer: Timer?  // 使用 weak 避免循环引用
    private weak var closeTimer: Timer?
    private let timerQueue = DispatchQueue(label: "com.notchdrop.timer", qos: .userInteractive)
    
    // 通知合并时间窗口
    private let mergeTimeWindow: TimeInterval = 0.5
    private var lastNotificationTime: Date?
    private var lastNotificationSource: String?
    
    private init() {}
    
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
        
        // 检查是否可以合并通知
        if shouldMergeNotification(notification) {
            mergedCount += 1
            print("[NotificationManager] 合并通知，当前合并数: \(mergedCount)")
            // 更新当前通知的标题显示合并数量
            if var current = currentNotification {
                current = NotchNotification(
                    title: "\(current.title) (\(mergedCount + 1))",
                    message: current.message,
                    type: current.type,
                    priority: current.priority,
                    icon: current.icon,
                    actions: current.actions,
                    metadata: current.metadata
                )
                self.currentNotification = current
            }
        } else {
            // 根据优先级处理通知
            if notification.priority == .urgent {
                // 紧急通知立即显示
                processUrgentNotification(notification)
            } else if showNotification && currentNotification != nil {
                // 如果正在显示通知，将新通知加入队列
                enqueueNotification(notification)
            } else {
                // 直接显示通知
                displayNotification(notification)
            }
        }
        
        // 添加到历史记录（使用 LRU 策略）
        addToHistory(notification)
        
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
            pendingNotifications.insert(current, at: 0)
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
        
        // 根据优先级和内容长度计算显示时间
        let calculatedDuration = duration ?? calculateDisplayDuration(for: notification)
        startHideTimer(duration: calculatedDuration)
    }
    
    private func calculateDisplayDuration(for notification: NotchNotification) -> TimeInterval {
        var duration = displayDuration
        
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
        
        // 根据消息长度调整（每50字符增加0.5秒）
        let extraTime = Double(notification.message.count / 50) * 0.5
        duration += min(extraTime, 2.0) // 最多额外2秒
        
        return duration
    }
    
    private func addToHistory(_ notification: NotchNotification) {
        // LRU缓存策略：移除重复项，添加到最前
        notificationHistory.removeAll { $0.id == notification.id }
        notificationHistory.insert(notification, at: 0)
        
        // 限制历史记录大小
        if notificationHistory.count > maxHistoryCount {
            notificationHistory.removeLast()
        }
    }
    
    private func invalidateTimers() {
        hideTimer?.invalidate()
        hideTimer = nil
        closeTimer?.invalidate()
        closeTimer = nil
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
                // 短暂延迟后显示下一个通知
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.showNextNotification()
                }
            } else {
                // 没有更多通知，关闭刘海
                print("[NotificationManager] 无待处理通知，关闭刘海")
                NotchViewModel.shared?.notchClose()
            }
        }
    }
    
    func clearHistory() {
        notificationHistory.removeAll()
    }
    
    func handleAction(_ action: NotificationAction) {
        print("[NotificationManager] Handling action: \(action.action)")
        // TODO: Implement action handling
    }
}