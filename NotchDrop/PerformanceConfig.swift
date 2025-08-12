//
//  PerformanceConfig.swift
//  NotchDrop
//
//  Performance optimization configuration for ProMotion displays
//

import SwiftUI

struct PerformanceConfig {
    // ProMotion 120Hz support
    static let targetFrameRate: Double = 120.0
    static let frameDuration: Double = 1.0 / targetFrameRate
    
    // Animation optimization
    static let highPerformanceAnimation = Animation.interpolatingSpring(
        mass: 1.0,
        stiffness: 500,
        damping: 30,
        initialVelocity: 0
    )
    
    static let smoothSpring = Animation.interpolatingSpring(
        mass: 0.8,
        stiffness: 400,
        damping: 25,
        initialVelocity: 0
    )
    
    // List performance
    static let maxVisibleHistoryItems = 50  // 限制可见项
    static let historyBatchSize = 10  // 分批加载
    
    // Rendering optimization
    static let useMetalRendering = true
    static let enableAsyncRendering = true
}

// 优化的动画修饰符
extension View {
    func highPerformanceAnimation<V: Equatable>(value: V) -> some View {
        self.animation(PerformanceConfig.highPerformanceAnimation, value: value)
    }
    
    func smoothAnimation<V: Equatable>(value: V) -> some View {
        self.animation(PerformanceConfig.smoothSpring, value: value)
    }
}

// 懒加载列表组件
struct LazyNotificationList: View {
    let notifications: [NotchNotification]
    @State private var visibleRange: Range<Int> = 0..<10
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(notifications.enumerated()), id: \.element.id) { index, notification in
                        if visibleRange.contains(index) {
                            NotificationHistoryRow(notification: notification)
                                .id(notification.id)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .bottom).combined(with: .opacity)
                                ))
                        } else {
                            // 占位符，减少渲染开销
                            Color.clear
                                .frame(height: 60)
                                .id(notification.id)
                        }
                    }
                }
                .onAppear {
                    updateVisibleRange()
                }
            }
            .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { _ in
                updateVisibleRange()
            }
        }
    }
    
    private func updateVisibleRange() {
        let start = max(0, visibleRange.lowerBound - 5)
        let end = min(notifications.count, start + PerformanceConfig.maxVisibleHistoryItems)
        visibleRange = start..<end
    }
}

// ScrollView 偏移检测
struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// 优化的通知历史行
struct NotificationHistoryRow: View {
    let notification: NotchNotification
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())
            
            // 内容
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                Text(notification.message)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 时间
            Text(timeString)
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.9)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) {
                isVisible = true
            }
        }
    }
    
    private var iconName: String {
        switch notification.type {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .hook: return "link.circle.fill"
        case .toolUse: return "hammer.circle.fill"
        case .progress: return "arrow.triangle.2.circlepath.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch notification.type {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .hook: return .purple
        case .toolUse: return .cyan
        case .progress: return .gray
        }
    }
    
    private var timeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: notification.timestamp, relativeTo: Date())
    }
}