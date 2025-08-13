//
//  NotificationView.swift
//  NotchNoti
//
//  Notification display view with Dynamic Island-like animations
//

import SwiftUI

// 动画常量 - 优化支持 ProMotion 120Hz
enum AnimationConstants {
    static let springSmooth = Animation.interpolatingSpring(
        mass: 0.6, stiffness: 400, damping: 22, initialVelocity: 0
    )
    static let notificationExpand = Animation.interpolatingSpring(
        mass: 0.7, stiffness: 450, damping: 25, initialVelocity: 0
    )
    static let notificationHide = Animation.interpolatingSpring(
        mass: 0.5, stiffness: 500, damping: 30, initialVelocity: 0
    )
    static let slideIn = Animation.interpolatingSpring(
        mass: 0.8, stiffness: 350, damping: 20, initialVelocity: 0.5
    )
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
        ZStack {
            // 特殊背景效果
            if notification.hasSpecialBackground {
                GradientBackgroundView(type: notification.type)
            }
            
            // 粒子效果（仅 celebration 类型）
            if notification.hasParticleEffect {
                ParticleEffectView()
                    .allowsHitTesting(false)
            }
            
            HStack(spacing: 16) {
                // 图标带特效
                ZStack {
                    // 光晕效果
                    if notification.hasGlowEffect {
                        GlowEffectView(color: notification.color, intensity: 0.8)
                            .frame(width: 50, height: 50)
                    }
                    
                    // 紧急通知的脉冲背景
                    if notification.priority == .urgent {
                        Circle()
                            .fill(notification.color.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .scaleEffect(pulseEffect ? 1.3 : 1.0)
                            .opacity(pulseEffect ? 0 : 0.8)
                            .animation(AnimationConstants.pulse, value: pulseEffect)
                    }
                    
                    // 使用动画图标或普通图标
                    if notification.hasAnimatedIcon {
                        AnimatedIconView(
                            type: notification.type,
                            systemImage: iconName,
                            color: notification.color
                        )
                    } else {
                        Image(systemName: iconName)
                            .font(.system(size: 24))
                            .foregroundColor(notification.color)
                            .scaleEffect(urgentScale)
                            .shadow(color: notification.priority == .urgent ? notification.color.opacity(0.5) : .clear,
                                    radius: notification.priority == .urgent ? 8 : 0)
                            .animation(AnimationConstants.springSmooth, value: manager.mergedCount)
                    }
                    
                    // 进度指示器（用于上传/下载）
                    if let progress = notification.progressValue,
                       (notification.type == .download || notification.type == .upload) {
                        CircularProgressView(progress: progress, color: notification.color)
                            .frame(width: 35, height: 35)
                    }
                }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // 如果有改动统计，显示在标题旁边
                    if let metadata = notification.metadata,
                       metadata["diff_path"] != nil,
                       notification.message.contains("+") && notification.message.contains("-") {
                        let message = notification.message
                        if let startIndex = message.firstIndex(of: "("),
                           let endIndex = message.firstIndex(of: ")") {
                            let stats = String(message[message.index(after: startIndex)..<endIndex])
                            // 解析 "预计 +1 -1" 格式
                            let components = stats.components(separatedBy: " ")
                            HStack(spacing: 2) {
                                if components.count >= 3 {
                                    // 跳过 "预计"，显示美化的数字
                                    let addNum = components[1].replacingOccurrences(of: "+", with: "")
                                    let delNum = components[2].replacingOccurrences(of: "-", with: "")
                                    
                                    Text("+\(addNum)")
                                        .foregroundColor(.blue)
                                        .fontWeight(.medium)
                                    Text("-\(delNum)")
                                        .foregroundColor(.red)
                                        .fontWeight(.medium)
                                } else if components.count >= 2 {
                                    // 兼容其他格式
                                    Text(components[0])
                                        .foregroundColor(.blue)
                                    Text(components[1])
                                        .foregroundColor(.red)
                                }
                            }
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.2))
                            )
                        }
                    }
                    
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
            
            // 如果有 diff 信息，显示查看改动按钮
            if notification.metadata?["diff_path"] != nil {
                Button(action: {
                    openDiffWindow()
                    // 点击查看 diff 时，取消自动隐藏
                    manager.cancelHideTimer()
                }) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("查看文件改动")
            }
            
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
        }
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
        .onHover { hovering in
            if hovering {
                // 鼠标悬停时取消自动隐藏
                manager.cancelHideTimer()
            } else {
                // 鼠标离开时重新开始计时（如果通知还在显示）
                if manager.showNotification {
                    manager.restartHideTimer()
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
    
    private func openDiffWindow() {
        guard let diffPath = notification.metadata?["diff_path"],
              let filePath = notification.metadata?["file_path"] else { return }
        
        // 创建新窗口显示 DiffView
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        let isPreview = notification.metadata?["is_preview"] == "true"
        window.title = isPreview ? "改动预览 - \(fileName)" : "文件改动 - \(fileName)"
        window.center()
        window.setFrameAutosaveName("DiffWindow")
        
        // 创建一个状态绑定用于关闭窗口
        let isPresented = Binding<Bool>(
            get: { window.isVisible },
            set: { if !$0 { window.close() } }
        )
        
        window.contentView = NSHostingView(
            rootView: DiffView(diffPath: diffPath, filePath: filePath, isPresented: isPresented)
        )
        
        window.makeKeyAndOrderFront(nil)
        
        // 打开窗口后收起刘海
        NotchViewModel.shared?.notchClose()
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
                Text("通知历史")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Button(action: {
                    manager.clearHistory()
                }) {
                    Text("清除全部")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            ScrollView {
                LazyVStack(spacing: 8) {  // 改用 LazyVStack 提升性能
                    if manager.notificationHistory.isEmpty {
                    Text("暂无通知记录")
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
                                withAnimation(.interpolatingSpring(
                                    mass: 0.7,
                                    stiffness: 400,
                                    damping: 25,
                                    initialVelocity: 0
                                )) {
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
    @State private var selectedNotification: NotchNotification?
    
    var body: some View {
        if manager.notificationHistory.isEmpty {
            // 空状态界面
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "bell.slash")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.3))
                
                Text("暂无通知")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // 直接显示可滑动的历史记录
            ScrollView {
                VStack(spacing: 6) {
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 250)
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
                    HStack(spacing: 4) {
                        Text(notification.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                        
                        // 如果消息中包含改动统计，显示标签
                        if notification.message.contains("+") && notification.message.contains("-") {
                            let message = notification.message
                            let components = message.components(separatedBy: "(")
                            if components.count > 1,
                               let stats = components.last?.dropLast() { // 移除最后的 )
                                Text(stats)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(
                                        Capsule()
                                            .fill(Color.blue.opacity(0.8))
                                    )
                            }
                        }
                    }
                    
                    Text(timeAgoString(from: notification.timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 如果有 diff 信息，显示图标
                if let diffPath = notification.metadata?["diff_path"],
                   let filePath = notification.metadata?["file_path"] {
                    Button(action: {
                        openDiffWindow(diffPath: diffPath, filePath: filePath)
                    }) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(.blue.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
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
    
    private func openDiffWindow(diffPath: String, filePath: String) {
        // 创建新窗口显示 DiffView
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        // 历史记录中的 diff 通常是已完成的，不是预览
        window.title = "文件改动 - \(fileName)"
        window.center()
        window.setFrameAutosaveName("DiffWindow")
        
        // 创建一个状态绑定用于关闭窗口
        let isPresented = Binding<Bool>(
            get: { window.isVisible },
            set: { if !$0 { window.close() } }
        )
        
        window.contentView = NSHostingView(
            rootView: DiffView(diffPath: diffPath, filePath: filePath, isPresented: isPresented)
        )
        
        window.makeKeyAndOrderFront(nil)
        
        // 打开窗口后收起刘海
        NotchViewModel.shared?.notchClose()
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) 分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) 小时前"
        } else {
            let days = Int(interval / 86400)
            return "\(days) 天前"
        }
    }
}