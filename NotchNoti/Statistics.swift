//
//  Statistics.swift
//  NotchNoti
//
//  工作效率统计 - 专注于Claude Code协作模式分析
//

import Foundation
import SwiftUI

// MARK: - 核心统计模型

/// 工作会话统计
struct WorkSession: Codable, Identifiable {
    let id: UUID
    let projectName: String
    let startTime: Date
    var endTime: Date?
    var activities: [Activity]

    init(projectName: String) {
        self.id = UUID()
        self.projectName = projectName
        self.startTime = Date()
        self.endTime = nil
        self.activities = []
    }

    // 核心指标
    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    var totalActivities: Int {
        activities.count
    }

    // 工作节奏（每分钟操作数）
    var pace: Double {
        guard duration > 0 else { return 0 }
        return Double(totalActivities) / (duration / 60.0)
    }

    // 工作强度
    var intensity: Intensity {
        if pace > 8 { return .intense }      // 高强度：每分钟8+操作
        if pace > 4 { return .focused }      // 专注：每分钟4-8操作
        if pace > 1 { return .steady }       // 稳定：每分钟1-4操作
        return .light                         // 轻度：每分钟<1操作
    }

    enum Intensity: String, Codable {
        case light = "💤 轻度"
        case steady = "🚶 稳定"
        case focused = "🎯 专注"
        case intense = "🔥 高强度"
    }

    // 活动类型分布
    var activityDistribution: [ActivityType: Int] {
        Dictionary(grouping: activities, by: \.type)
            .mapValues { $0.count }
    }

    // 主要工作类型
    var primaryActivity: ActivityType {
        activityDistribution.max(by: { $0.value < $1.value })?.key ?? .other
    }

    // 工作模式判断
    var workMode: WorkMode {
        let dist = activityDistribution
        let writeOps = (dist[.edit] ?? 0) + (dist[.write] ?? 0)
        let readOps = (dist[.read] ?? 0) + (dist[.grep] ?? 0) + (dist[.glob] ?? 0)
        let execOps = dist[.bash] ?? 0

        if writeOps > readOps && writeOps > execOps {
            return .writing  // 编写代码为主
        } else if readOps > writeOps * 2 {
            return .researching  // 阅读研究为主
        } else if execOps > totalActivities / 3 {
            return .debugging  // 调试执行为主
        } else if writeOps > 0 && readOps > 0 {
            return .developing  // 混合开发
        }
        return .exploring  // 探索阶段
    }

    enum WorkMode: String {
        case writing = "✍️ 编写"
        case researching = "🔍 研究"
        case debugging = "🐛 调试"
        case developing = "💻 开发"
        case exploring = "🗺️ 探索"
    }
}

/// 单个活动记录
struct Activity: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let type: ActivityType
    let tool: String
    let duration: TimeInterval

    init(type: ActivityType, tool: String, duration: TimeInterval = 0) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.tool = tool
        self.duration = duration
    }
}

/// 活动类型
enum ActivityType: String, Codable, CaseIterable {
    case read = "📖 阅读"
    case write = "📝 写入"
    case edit = "✏️ 编辑"
    case bash = "⚡️ 执行"
    case grep = "🔎 搜索"
    case glob = "📁 查找"
    case task = "🎯 任务"
    case other = "📋 其他"

    static func from(toolName: String) -> ActivityType {
        switch toolName.lowercased() {
        case "read": return .read
        case "write": return .write
        case "edit": return .edit
        case "bash": return .bash
        case "grep": return .grep
        case "glob": return .glob
        case "task": return .task
        default: return .other
        }
    }
}

// MARK: - 统计管理器

class StatisticsManager: ObservableObject {
    static let shared = StatisticsManager()

    @Published var currentSession: WorkSession?
    @Published var sessionHistory: [WorkSession] = []

    private let maxHistoryCount = 20
    private let persistenceKey = "com.notchnoti.workSessions"

    private init() {
        loadHistory()
    }

    // 开始新会话
    func startSession(projectName: String) {
        endSession()  // 结束当前会话
        currentSession = WorkSession(projectName: projectName)
        print("[Stats] 新会话开始: \(projectName)")
    }

    // 结束会话
    func endSession() {
        guard var session = currentSession else { return }
        session.endTime = Date()
        addToHistory(session)
        currentSession = nil
        print("[Stats] 会话结束: \(session.projectName), 时长: \(Int(session.duration/60))分钟")
    }

    // 记录活动
    func recordActivity(toolName: String, duration: TimeInterval = 0) {
        guard var session = currentSession else { return }
        let type = ActivityType.from(toolName: toolName)
        let activity = Activity(type: type, tool: toolName, duration: duration)
        session.activities.append(activity)
        currentSession = session
    }

    // 保存历史
    private func addToHistory(_ session: WorkSession) {
        sessionHistory.insert(session, at: 0)
        if sessionHistory.count > maxHistoryCount {
            sessionHistory.removeLast()
        }
        saveHistory()
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(sessionHistory) {
            UserDefaults.standard.set(encoded, forKey: persistenceKey)
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let decoded = try? JSONDecoder().decode([WorkSession].self, from: data) else {
            return
        }
        sessionHistory = decoded
    }

    // MARK: - 统计分析

    /// 今日工作总结
    func getTodaySummary() -> DailySummary {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todaySessions = sessionHistory.filter {
            calendar.isDate($0.startTime, inSameDayAs: today)
        }

        let totalDuration = todaySessions.reduce(0.0) { $0 + $1.duration }
        let totalActivities = todaySessions.reduce(0) { $0 + $1.totalActivities }
        let avgPace = todaySessions.isEmpty ? 0 : todaySessions.reduce(0.0) { $0 + $1.pace } / Double(todaySessions.count)

        // 合并所有活动类型
        var allActivities: [ActivityType: Int] = [:]
        for session in todaySessions {
            for (type, count) in session.activityDistribution {
                allActivities[type, default: 0] += count
            }
        }

        return DailySummary(
            date: today,
            sessionCount: todaySessions.count,
            totalDuration: totalDuration,
            totalActivities: totalActivities,
            averagePace: avgPace,
            activityDistribution: allActivities,
            sessions: todaySessions
        )
    }

    /// 最近7天趋势
    func getWeeklyTrend() -> [DailySummary] {
        let calendar = Calendar.current
        var summaries: [DailySummary] = []

        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)

            let daySessions = sessionHistory.filter {
                calendar.isDate($0.startTime, inSameDayAs: startOfDay)
            }

            let totalDuration = daySessions.reduce(0.0) { $0 + $1.duration }
            let totalActivities = daySessions.reduce(0) { $0 + $1.totalActivities }
            let avgPace = daySessions.isEmpty ? 0 : daySessions.reduce(0.0) { $0 + $1.pace } / Double(daySessions.count)

            var allActivities: [ActivityType: Int] = [:]
            for session in daySessions {
                for (type, count) in session.activityDistribution {
                    allActivities[type, default: 0] += count
                }
            }

            summaries.append(DailySummary(
                date: startOfDay,
                sessionCount: daySessions.count,
                totalDuration: totalDuration,
                totalActivities: totalActivities,
                averagePace: avgPace,
                activityDistribution: allActivities,
                sessions: daySessions
            ))
        }

        return summaries.reversed()
    }

    /// 获取项目统计
    func getProjectStats() -> [ProjectSummary] {
        var projectMap: [String: [WorkSession]] = [:]

        for session in sessionHistory {
            projectMap[session.projectName, default: []].append(session)
        }

        return projectMap.map { (name, sessions) in
            let totalDuration = sessions.reduce(0.0) { $0 + $1.duration }
            let totalActivities = sessions.reduce(0) { $0 + $1.totalActivities }

            return ProjectSummary(
                projectName: name,
                sessionCount: sessions.count,
                totalDuration: totalDuration,
                totalActivities: totalActivities,
                lastActive: sessions.map(\.startTime).max() ?? Date()
            )
        }.sorted { $0.lastActive > $1.lastActive }
    }
}

// MARK: - 汇总数据模型

struct DailySummary: Identifiable {
    let id = UUID()
    let date: Date
    let sessionCount: Int
    let totalDuration: TimeInterval
    let totalActivities: Int
    let averagePace: Double
    let activityDistribution: [ActivityType: Int]
    let sessions: [WorkSession]

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }

    var durationHours: Double {
        totalDuration / 3600.0
    }
}

struct ProjectSummary: Identifiable {
    let id = UUID()
    let projectName: String
    let sessionCount: Int
    let totalDuration: TimeInterval
    let totalActivities: Int
    let lastActive: Date

    var durationHours: Double {
        totalDuration / 3600.0
    }
}

// MARK: - 紧凑型统计视图

struct NotchStatsView: View {
    @ObservedObject var statsManager = StatisticsManager.shared
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            // 紧凑标题栏
            HStack {
                // 页面指示器
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(currentPage == index ? Color.cyan : Color.white.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer()

                Text(pageTitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                // 切换和关闭按钮
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation { currentPage = (currentPage + 1) % 3 }
                    }) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.caption)
                            .foregroundColor(.cyan)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        NotchViewModel.shared?.returnToNormal()
                    }) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().opacity(0.3)

            // 内容区域
            ZStack {
                if currentPage == 0 {
                    CurrentSessionView(session: statsManager.currentSession)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                } else if currentPage == 1 {
                    TodayOverviewView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    WeeklyTrendView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: currentPage)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.2))
    }

    private var pageTitle: String {
        switch currentPage {
        case 0: return "🎯 当前会话"
        case 1: return "📊 今日总结"
        case 2: return "📈 本周趋势"
        default: return ""
        }
    }
}

// MARK: - 当前会话视图

struct CurrentSessionView: View {
    let session: WorkSession?

    var body: some View {
        if let session = session {
            HStack(spacing: 12) {
                // 左侧：核心指标
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("⏱️")
                            .font(.caption2)
                        Text(formatDuration(session.duration))
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.cyan)
                    }

                    HStack(spacing: 6) {
                        Text("🎯")
                            .font(.caption2)
                        Text("\(session.totalActivities) 次")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }

                    HStack(spacing: 6) {
                        Text(session.intensity.rawValue)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .frame(width: 120, alignment: .leading)

                Divider()
                    .frame(height: 80)
                    .opacity(0.3)

                // 右侧：工作模式
                VStack(alignment: .leading, spacing: 6) {
                    Text("工作模式")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))

                    Text(session.workMode.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.cyan)

                    Text("节奏")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 4)

                    Text(String(format: "%.1f/min", session.pace))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.5))
                Text("暂无会话")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - 今日概览视图

struct TodayOverviewView: View {
    @ObservedObject var statsManager = StatisticsManager.shared

    var body: some View {
        let summary = statsManager.getTodaySummary()

        if summary.sessionCount > 0 {
            HStack(spacing: 12) {
                // 左侧：时间和会话数
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("⏰")
                            .font(.caption2)
                        Text(String(format: "%.1fh", summary.durationHours))
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }

                    HStack(spacing: 6) {
                        Text("📝")
                            .font(.caption2)
                        Text("\(summary.sessionCount) 会话")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }

                    HStack(spacing: 6) {
                        Text("⚡️")
                            .font(.caption2)
                        Text("\(summary.totalActivities) 操作")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .frame(width: 120, alignment: .leading)

                Divider()
                    .frame(height: 80)
                    .opacity(0.3)

                // 右侧：活动分布
                VStack(alignment: .leading, spacing: 4) {
                    Text("活动分布")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))

                    ForEach(summary.activityDistribution.sorted(by: { $0.value > $1.value }).prefix(3), id: \.key) { type, count in
                        HStack(spacing: 4) {
                            Text(type.rawValue)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))

                            Spacer()

                            Text("\(count)")
                                .font(.caption2)
                                .foregroundColor(.cyan)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.5))
                Text("今日暂无数据")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - 本周趋势视图

struct WeeklyTrendView: View {
    @ObservedObject var statsManager = StatisticsManager.shared

    var body: some View {
        let trend = statsManager.getWeeklyTrend().suffix(7)

        if !trend.isEmpty && trend.contains(where: { $0.sessionCount > 0 }) {
            HStack(spacing: 8) {
                ForEach(trend, id: \.id) { day in
                    VStack(spacing: 2) {
                        Text(day.dateString)
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.5))

                        // 简化柱状图
                        RoundedRectangle(cornerRadius: 2)
                            .fill(day.sessionCount > 0 ? Color.cyan : Color.white.opacity(0.1))
                            .frame(width: 12, height: max(CGFloat(day.durationHours) * 20, 4))

                        Text(day.sessionCount > 0 ? "\(day.sessionCount)" : "")
                            .font(.system(size: 8))
                            .foregroundColor(.cyan)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.5))
                Text("本周暂无数据")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - 单页面紧凑型统计视图（600×160 优化）

struct CompactWorkSessionStatsView: View {
    @ObservedObject var statsManager = StatisticsManager.shared

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let session = statsManager.currentSession {
                // 有会话时的布局
                activeSessionLayout(session: session)
            } else {
                // 空闲时的紧凑布局
                idleLayout
            }

            // 关闭按钮
            closeButton
        }
        .frame(height: 160)
    }

    // MARK: - 活跃会话布局
    private func activeSessionLayout(session: WorkSession) -> some View {
        HStack(spacing: 16) {
            // 左侧：环形进度 + 核心指标
            sessionCircleView(session: session)
                .frame(width: 140)

            // 中间：工具使用迷你条形图
            toolMiniChartView(session: session)
                .frame(width: 200)

            // 右侧：今日汇总卡片
            todayCompactCard
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 空闲布局
    private var idleLayout: some View {
        HStack(spacing: 20) {
            // 左侧：空闲状态
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 3)
                        .frame(width: 60, height: 60)

                    Image(systemName: "moon.stars")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.4))
                }

                Text("空闲中")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 100)
                .opacity(0.1)

            // 右侧：今日汇总（即使空闲也显示）
            todayCompactCard
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 环形进度视图
    private func sessionCircleView(session: WorkSession) -> some View {
        VStack(spacing: 6) {
            ZStack {
                // 背景圆环
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 8)
                    .frame(width: 90, height: 90)

                // 进度圆环（基于时长）
                Circle()
                    .trim(from: 0, to: min(session.duration / 3600, 1.0)) // 1小时为满
                    .stroke(
                        AngularGradient(
                            colors: [.cyan, .blue, .purple, .cyan],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))

                // 中心内容
                VStack(spacing: 2) {
                    Text(formatDuration(session.duration))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(session.projectName)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                        .frame(width: 70)
                }
            }

            // 底部标签
            HStack(spacing: 8) {
                Label("\(session.totalActivities)", systemImage: "bolt.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.orange)

                Text(session.workMode.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.purple.opacity(0.8))
            }
        }
    }

    // MARK: - 工具迷你图表
    private func toolMiniChartView(session: WorkSession) -> some View {
        let toolStats = Dictionary(grouping: session.activities, by: { $0.tool })
            .map { (tool: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(6)

        return VStack(alignment: .leading, spacing: 4) {
            Text("工具使用")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .textCase(.uppercase)

            if !toolStats.isEmpty {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(toolStats.enumerated()), id: \.element.tool) { index, stat in
                        VStack(spacing: 3) {
                            // 柱状图
                            let maxCount = toolStats.first?.count ?? 1
                            let height = CGFloat(stat.count) / CGFloat(maxCount) * 70 + 10

                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [getToolColor(stat.tool), getToolColor(stat.tool).opacity(0.6)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 24, height: height)
                                .overlay(
                                    Text("\(stat.count)")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.5), radius: 1)
                                )

                            // 工具名
                            Text(stat.tool)
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                                .frame(width: 28)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - 今日汇总卡片
    private var todayCompactCard: some View {
        let summary = statsManager.getTodaySummary()

        return VStack(alignment: .leading, spacing: 8) {
            Text("今日")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .textCase(.uppercase)

            if summary.sessionCount > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    // 时长卡片
                    HStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 32, height: 32)

                            Image(systemName: "clock.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            Text(String(format: "%.1fh", summary.durationHours))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("\(summary.sessionCount) 会话")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    // 操作数条
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                            .frame(width: 20)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.05))

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        LinearGradient(
                                            colors: [.orange, .red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: min(CGFloat(summary.totalActivities) / 100 * geo.size.width, geo.size.width))
                            }
                        }
                        .frame(height: 8)

                        Text("\(summary.totalActivities)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.orange)
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 20))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("暂无数据")
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - 辅助方法

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return String(format: "%dh%02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }

    private func getToolColor(_ tool: String) -> Color {
        switch tool.lowercased() {
        case "read": return .blue
        case "edit", "write": return .green
        case "bash": return .orange
        case "grep", "glob": return .purple
        case "task": return .pink
        default: return .cyan
        }
    }

    private var closeButton: some View {
        Button(action: {
            NotchViewModel.shared?.returnToNormal()
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.3))
                .background(Circle().fill(Color.black.opacity(0.3)))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(10)
    }
}
