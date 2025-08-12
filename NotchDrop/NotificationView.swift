//
//  NotificationView.swift
//  NotchDrop
//
//  Notification display view with Dynamic Island-like animations
//

import SwiftUI

// 动画常量
enum AnimationConstants {
    static let springSmooth = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let notificationExpand = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let notificationHide = Animation.easeInOut(duration: 0.25)
    static let slideIn = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
    static let pulse = Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)
    static let urgentPulse = Animation.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true)
}

struct NotificationView: View, Equatable {
    let notification: NotchNotification
    @State private var isExpanded = false
    @State private var isVisible = false
    @State private var pulseEffect = false
    @State private var urgentScale: CGFloat = 1.0
    @ObservedObject var manager = NotificationManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    // 实现 Equatable 以优化重渲染
    static func == (lhs: NotificationView, rhs: NotificationView) -> Bool {
        lhs.notification.id == rhs.notification.id &&
        lhs.isExpanded == rhs.isExpanded
    }
    
    var body: some View {
        // 使用和 NotificationCenterMainView 一样的布局
        HStack(spacing: 16) {
            // 图标带特效
            ZStack {
                // 紧急通知的脉冲背景
                if notification.priority == .urgent {
                    Circle()
                        .fill(notification.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .scaleEffect(pulseEffect ? 1.3 : 1.0)
                        .opacity(pulseEffect ? 0 : 0.8)
                        .animation(AnimationConstants.pulse, value: pulseEffect)
                }
                
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundColor(notification.color)
                    .scaleEffect(urgentScale)
                    .shadow(color: notification.priority == .urgent ? notification.color.opacity(0.5) : .clear, 
                            radius: notification.priority == .urgent ? 8 : 0)
                    .animation(AnimationConstants.springSmooth, value: manager.mergedCount)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if manager.mergedCount > 0 {
                        Text("(\(manager.mergedCount + 1))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    if !manager.pendingNotifications.isEmpty {
                        Text("• \(manager.pendingNotifications.count) pending")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                            .transition(.opacity)
                    }
                }
                
                Text(notification.message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(isExpanded ? nil : 2)
                    .animation(AnimationConstants.notificationExpand, value: isExpanded)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 添加关闭按钮
            Button(action: {
                withAnimation(AnimationConstants.notificationHide) {
                    manager.hideCurrentNotification()
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(backgroundGradient)
        .scaleEffect(isVisible ? 1 : 0.9)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(AnimationConstants.slideIn) {
                isVisible = true
            }
            // 紧急通知特效
            if notification.priority == .urgent {
                pulseEffect = true
                withAnimation(AnimationConstants.urgentPulse) {
                    urgentScale = 1.1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    urgentScale = 1.0
                }
            }
        }
        .onTapGesture {
            // 点击展开详情（如果消息很长）
            if notification.message.count > 50 {
                withAnimation(AnimationConstants.notificationExpand) {
                    isExpanded.toggle()
                }
            }
        }
    }
    
    // 背景渐变（紧急通知有特殊背景）
    @ViewBuilder
    private var backgroundGradient: some View {
        if notification.priority == .urgent {
            LinearGradient(
                colors: [
                    Color.red.opacity(colorScheme == .dark ? 0.15 : 0.1),
                    Color.orange.opacity(colorScheme == .dark ? 0.1 : 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(12)
        } else {
            Color.clear
        }
    }
    
    private var iconName: String {
        if manager.mergedCount > 0 {
            return "bell.badge.fill"
        } else if notification.priority == .urgent {
            return "bell.badge.circle.fill"
        } else {
            return notification.systemImage
        }
    }
}

struct NotificationActionButton: View {
    let action: NotificationAction
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(action.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(buttonForegroundColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(buttonBackgroundColor)
                )
        }
        .buttonStyle(.plain)
    }
    
    private var buttonForegroundColor: Color {
        switch action.style {
        case .primary:
            return .white
        case .destructive:
            return .white
        case .normal:
            return .primary
        }
    }
    
    private var buttonBackgroundColor: Color {
        switch action.style {
        case .primary:
            return .blue
        case .destructive:
            return .red
        case .normal:
            return .secondary.opacity(0.2)
        }
    }
}

struct NotificationHistoryView: View {
    @ObservedObject var manager = NotificationManager.shared
    @State private var selectedNotification: NotchNotification?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notification History")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Button(action: {
                    manager.clearHistory()
                }) {
                    Text("Clear All")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            ScrollView {
                VStack(spacing: 8) {
                    if manager.notificationHistory.isEmpty {
                        Text("No notifications yet")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        ForEach(manager.notificationHistory) { notification in
                            NotificationHistoryItem(
                                notification: notification,
                                isSelected: selectedNotification?.id == notification.id
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if selectedNotification?.id == notification.id {
                                        selectedNotification = nil
                                    } else {
                                        selectedNotification = notification
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .frame(maxHeight: 400)
    }
}

struct NotificationCenterMainView: View {
    @ObservedObject var manager = NotificationManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            if manager.notificationHistory.isEmpty {
                // 空状态界面
                VStack(spacing: 8) {
                    Image(systemName: "bell.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("通知中心")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("暂无通知")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 显示最近的通知摘要
                HStack(spacing: 16) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if let latest = manager.notificationHistory.first {
                            Text(latest.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text(latest.message)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(manager.notificationHistory.count)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("通知")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct NotificationHistoryItem: View {
    let notification: NotchNotification
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: notification.systemImage)
                    .font(.system(size: 14))
                    .foregroundColor(notification.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(timeAgoString(from: notification.timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if isSelected {
                Text(notification.message)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(isSelected ? 0.15 : 0.08))
        )
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}