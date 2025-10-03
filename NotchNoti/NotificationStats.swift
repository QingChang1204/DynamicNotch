//
//  NotificationStats.swift
//  NotchNoti
//
//  通知统计系统 - 统计所有接收到的通知
//

import Foundation
import SwiftUI

// MARK: - 通知统计管理器

class NotificationStatsManager: ObservableObject {
    static let shared = NotificationStatsManager()

    @Published var stats: NotificationStatistics

    private let persistenceKey = "com.notchnoti.notificationStats"
    private var lastUpdateTime = Date()

    private init() {
        self.stats = NotificationStatsManager.loadStats()
    }

    // 记录新通知
    func recordNotification(_ notification: NotchNotification) {
        stats.totalCount += 1
        stats.lastUpdateTime = Date()

        // 更新类型分布
        stats.typeDistribution[notification.type, default: 0] += 1

        // 更新优先级分布
        stats.priorityDistribution[notification.priority, default: 0] += 1

        // 更新时间段分布
        let hour = Calendar.current.component(.hour, from: Date())
        let timeSlot = getTimeSlot(hour: hour)
        stats.timeDistribution[timeSlot, default: 0] += 1

        // 保存统计数据
        saveStats()
        objectWillChange.send()
    }

    // 重置统计
    func resetStats() {
        stats = NotificationStatistics()
        saveStats()
    }

    // 获取时间段
    private func getTimeSlot(hour: Int) -> TimeSlot {
        switch hour {
        case 0..<6: return .earlyMorning    // 凌晨 0-6
        case 6..<12: return .morning        // 上午 6-12
        case 12..<18: return .afternoon     // 下午 12-18
        case 18..<24: return .evening       // 晚上 18-24
        default: return .morning
        }
    }

    // 获取时间段显示文本
    func getTimeSlotDisplay(_ slot: TimeSlot) -> String {
        switch slot {
        case .earlyMorning: return "凌晨"
        case .morning: return "上午"
        case .afternoon: return "下午"
        case .evening: return "晚上"
        }
    }

    // 保存统计数据
    private func saveStats() {
        if let encoded = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(encoded, forKey: persistenceKey)
        }
    }

    // 加载统计数据
    private static func loadStats() -> NotificationStatistics {
        guard let data = UserDefaults.standard.data(forKey: "com.notchnoti.notificationStats"),
              let decoded = try? JSONDecoder().decode(NotificationStatistics.self, from: data) else {
            return NotificationStatistics()
        }
        return decoded
    }

    // 获取统计摘要
    func getSummary() -> StatsSummary {
        let total = stats.totalCount

        // 找出最常见的通知类型
        let topType = stats.typeDistribution.max(by: { $0.value < $1.value })
        let topTypeInfo = topType.map { (type: $0.key, count: $0.value) }

        // 找出最活跃的时间段
        let activeTime = stats.timeDistribution.max(by: { $0.value < $1.value })
        let activeTimeInfo = activeTime.map { (slot: $0.key, count: $0.value) }

        // 计算平均每小时通知数
        let elapsed = Date().timeIntervalSince(stats.startTime)
        let hours = max(elapsed / 3600.0, 1.0)
        let avgPerHour = Double(total) / hours

        return StatsSummary(
            totalCount: total,
            topType: topTypeInfo,
            activeTime: activeTimeInfo,
            avgPerHour: avgPerHour,
            startTime: stats.startTime
        )
    }
}

// MARK: - 数据模型

struct NotificationStatistics: Codable {
    var totalCount: Int = 0
    var startTime: Date = Date()
    var lastUpdateTime: Date = Date()

    // 类型分布
    var typeDistribution: [NotchNotification.NotificationType: Int] = [:]

    // 优先级分布
    var priorityDistribution: [NotchNotification.Priority: Int] = [:]

    // 时间段分布
    var timeDistribution: [TimeSlot: Int] = [:]
}

enum TimeSlot: String, Codable, CaseIterable {
    case earlyMorning = "凌晨"
    case morning = "上午"
    case afternoon = "下午"
    case evening = "晚上"
}

struct StatsSummary {
    let totalCount: Int
    let topType: (type: NotchNotification.NotificationType, count: Int)?
    let activeTime: (slot: TimeSlot, count: Int)?
    let avgPerHour: Double
    let startTime: Date
}

// MARK: - 紧凑通知统计视图

struct CompactNotificationStatsView: View {
    @ObservedObject var statsManager = NotificationStatsManager.shared

    var body: some View {
        ZStack(alignment: .topTrailing) {
            let summary = statsManager.getSummary()

            if summary.totalCount > 0 {
                statsContent(summary)
            } else {
                emptyState
            }

            closeButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.2))
    }

    private func statsContent(_ summary: StatsSummary) -> some View {
        HStack(spacing: 12) {
            // 左侧：总数和频率
            VStack(alignment: .leading, spacing: 8) {
                // 通知总数
                VStack(alignment: .leading, spacing: 2) {
                    Text("通知总数")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .kerning(0.3)

                    Text("\(summary.totalCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                }

                // 频率
                HStack(spacing: 4) {
                    Text("频率")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .kerning(0.3)

                    Text(String(format: "%.1f/h", summary.avgPerHour))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)
                }
            }
            .frame(width: 140, alignment: .leading)

            // 分隔线
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)

            // 中间：类型占比环形图
            VStack(spacing: 4) {
                ZStack {
                    // 背景圆环
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 5)

                    if let topType = summary.topType {
                        // 进度圆环
                        Circle()
                            .trim(from: 0, to: min(Double(topType.count) / Double(summary.totalCount), 1.0))
                            .stroke(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        // 中心内容
                        VStack(spacing: 0) {
                            Text(getTypeIcon(topType.type))
                                .font(.system(size: 16))
                            Text("\(topType.count)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(width: 56, height: 56)

                if let topType = summary.topType {
                    Text(topType.type.rawValue)
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(width: 140)

            // 分隔线
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)

            // 右侧：详细分布（自动填充剩余空间）
            VStack(alignment: .leading, spacing: 6) {
                // 活跃时段
                HStack(spacing: 4) {
                    Text("活跃")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .kerning(0.3)

                    if let activeTime = summary.activeTime {
                        Text(activeTime.slot.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)

                        Text("\(activeTime.count)")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                // 类型分布TOP3
                VStack(alignment: .leading, spacing: 4) {
                    let topTypes = statsManager.stats.typeDistribution
                        .sorted { $0.value > $1.value }
                        .prefix(3)

                    ForEach(Array(topTypes), id: \.key) { type, count in
                        HStack(spacing: 4) {
                            Text(getTypeIcon(type))
                                .font(.system(size: 9))
                            Text(type.rawValue)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.75))
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            Text("\(count)")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.cyan)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 12)
    }

    private func getTypeIcon(_ type: NotchNotification.NotificationType) -> String {
        switch type {
        case .info: return "ℹ️"
        case .success: return "✅"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .hook: return "🔗"
        case .toolUse: return "🔧"
        case .progress: return "⏳"
        case .celebration: return "🎉"
        case .reminder: return "⏰"
        case .download: return "⬇️"
        case .upload: return "⬆️"
        case .security: return "🔒"
        case .ai: return "🤖"
        case .sync: return "🔄"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.2))
            Text("暂无通知统计")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // 智能洞察卡片
    private func insightCard(_ summary: StatsSummary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 9))
                .foregroundColor(.purple)

            Text(generateInsights(summary).first ?? "")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
    }

    // 生成智能洞察
    private func generateInsights(_ summary: StatsSummary) -> [String] {
        var insights: [String] = []

        // 洞察1：频率分析
        if summary.avgPerHour > 10 {
            insights.append("频率较高 \(String(format: "%.0f", summary.avgPerHour))/h，建议筛选重要通知")
        } else if summary.avgPerHour > 5 {
            insights.append("工作节奏适中 \(String(format: "%.0f", summary.avgPerHour))/h")
        } else if summary.totalCount > 0 {
            insights.append("专注工作中，通知频率较低")
        }

        // 洞察2：类型分析
        if let topType = summary.topType {
            let percentage = Int(Double(topType.count) / Double(summary.totalCount) * 100)
            if percentage > 60 {
                insights.append("\(topType.type.rawValue)占比\(percentage)%，检查是否异常")
            } else if topType.count > 5 {
                insights.append("最常见：\(topType.type.rawValue) \(topType.count)条")
            }
        }

        // 洞察3：时间段分析
        if let activeTime = summary.activeTime {
            insights.append("\(activeTime.slot.rawValue)最活跃 \(activeTime.count)条")
        }

        // 如果没有洞察，给一个默认的
        if insights.isEmpty {
            insights.append("继续使用获取更多洞察")
        }

        return insights // 返回所有洞察，只显示第一条
    }

    private var closeButton: some View {
        Button(action: {
            NotchViewModel.shared?.contentType = .normal
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.3))
                .background(Circle().fill(Color.black.opacity(0.5)))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(12)
    }
}
