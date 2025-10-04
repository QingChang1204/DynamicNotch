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

        // 为有意义的session生成AI洞察（异步，不阻塞）
        // 条件：超过10分钟且至少5个活动
        if session.duration > 600 && session.totalActivities >= 5 {
            Task {
                _ = await WorkInsightsAnalyzer.shared.analyzeCurrentSession(session)
            }
        }
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
                .padding(6)  // 适度的点击区域
                .background(Circle().fill(Color.black.opacity(0.01)))  // 透明圆形背景
                .contentShape(Circle())  // 仅圆形区域可点击（避免矩形误触）
        }
        .buttonStyle(PlainButtonStyle())
        .padding(8)
        .zIndex(100)  // 确保在最上层
    }
}

// MARK: - 全局统计数据模型

/// 时间范围选择
enum TimeRange: String, CaseIterable, Identifiable {
    case day = "24h"
    case week = "7天"

    var id: String { rawValue }

    /// 获取起始时间
    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .day:
            return calendar.date(byAdding: .hour, value: -24, to: now) ?? now
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        }
    }

    /// 检查日期是否在范围内
    func contains(_ date: Date) -> Bool {
        let result = date >= startDate
        // 调试日志
        // print("[TimeRange] 检查时间: \(date), 起始: \(startDate), 结果: \(result)")
        return result
    }
}

/// 通知类型分布数据
struct NotificationTypeDistribution: Identifiable {
    let id = UUID()
    let type: NotchNotification.NotificationType
    let count: Int
    let percentage: Double

    // 用于饼图的角度
    var startAngle: Angle = .zero
    var endAngle: Angle = .zero
}

/// 热力图数据点
struct HeatmapCell: Identifiable {
    let id = UUID()
    let day: Int           // 0-6 (周一到周日)
    let timeBlock: Int     // 0-5 (每天6个4小时时段)
    let count: Int         // 通知数量

    /// 热力颜色强度 (0.0-1.0)
    var intensity: Double {
        // 根据通知数量计算强度,最大按30条计算
        return min(Double(count) / 30.0, 1.0)
    }
}

/// 每日活跃度数据
struct DayActivity: Identifiable {
    let id = UUID()
    let date: Date
    let notificationCount: Int
    let errorCount: Int
    let warningCount: Int

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

/// TOP工具使用统计
struct ToolUsage: Identifiable {
    let id = UUID()
    let toolName: String
    let count: Int
    let icon: String
    let color: Color

    /// 用于条形图的等级 (0-10)
    var level: Int {
        // 按比例计算,最大100次为满级
        return min(Int(Double(count) / 10.0), 10)
    }
}

/// 全局统计数据
struct GlobalStatistics {
    let timeRange: TimeRange
    let selectedProject: String?

    // 通知类型分布 (14种)
    let typeDistribution: [NotificationTypeDistribution]

    // 时间热力图数据 (7天×6时段 = 42个单元格)
    let heatmapData: [HeatmapCell]

    // 活跃度曲线 (每日通知数)
    let activityCurve: [DayActivity]

    // TOP工具使用
    let topTools: [ToolUsage]

    // 快速指标
    let totalNotifications: Int
    let errorCount: Int
    let warningCount: Int

    // 项目统计
    let projectName: String
    let totalDuration: TimeInterval  // 总工作时长
}

// MARK: - 全局统计管理器扩展

extension StatisticsManager {
    /// 加载全局统计数据
    func loadGlobalStatistics(
        range: TimeRange,
        project: String? = nil
    ) -> GlobalStatistics {
        // 从 NotificationManager 获取持久化历史
        let allNotifications = NotificationManager.shared.getPersistentHistory()

        // 定义需要统计的工作相关通知类型
        let statisticsTypes: Set<NotchNotification.NotificationType> = [
            .toolUse, .warning, .info, .success, .error, .hook
        ]

        // 筛选时间范围、项目和通知类型
        let startDate = range.startDate
        let now = Date()

        let filtered = allNotifications.filter { notif in
            let inRange = range.contains(notif.timestamp)
            let inProject = project == nil || notif.metadata?["project"] == project
            let isStatisticsType = statisticsTypes.contains(notif.type)
            return inRange && inProject && isStatisticsType
        }

        // print("[Stats] 📊 筛选结果: \(filtered.count)条 (时间范围:\(range.rawValue), 项目:\(project ?? "全部"))")

        // 1. 计算通知类型分布
        let typeGroups = Dictionary(grouping: filtered, by: \.type)
        let totalCount = filtered.count
        var typeDistribution: [NotificationTypeDistribution] = typeGroups.map { type, notifications in
            let count = notifications.count
            let percentage = totalCount > 0 ? Double(count) / Double(totalCount) : 0
            return NotificationTypeDistribution(
                type: type,
                count: count,
                percentage: percentage
            )
        }
        .sorted { $0.count > $1.count }

        // 计算饼图角度
        var currentAngle: Double = 0
        typeDistribution = typeDistribution.map { var dist = $0
            dist.startAngle = .degrees(currentAngle)
            currentAngle += dist.percentage * 360
            dist.endAngle = .degrees(currentAngle)
            return dist
        }

        // 2. 计算热力图数据 (优化：单次遍历)
        let calendar = Calendar.current
        var heatmapData: [HeatmapCell] = []

        if range == .day {
            // 24h模式：单次遍历计算所有时间块
            let now = Date()
            var blockCounts = [Int](repeating: 0, count: 6)

            for notif in filtered {
                let interval = now.timeIntervalSince(notif.timestamp)
                let hoursAgo = Int(interval / 3600)
                if hoursAgo >= 0 && hoursAgo < 24 {
                    let block = 5 - (hoursAgo / 4)  // 反转：0-3h→block5, 20-23h→block0
                    if block >= 0 && block < 6 {
                        blockCounts[block] += 1
                    }
                }
            }

            for block in 0..<6 {
                heatmapData.append(HeatmapCell(day: 6, timeBlock: block, count: blockCounts[block]))
            }

            // 其他列填充0
            for day in 0..<6 {
                for block in 0..<6 {
                    heatmapData.append(HeatmapCell(day: day, timeBlock: block, count: 0))
                }
            }
        } else {
            // 7天模式：单次遍历计算所有天×时间块
            var dayCounts = [[Int]](repeating: [Int](repeating: 0, count: 6), count: 7)

            for notif in filtered {
                let daysAgo = calendar.dateComponents([.day], from: calendar.startOfDay(for: notif.timestamp), to: calendar.startOfDay(for: Date())).day ?? 0
                if daysAgo >= 0 && daysAgo <= 6 {
                    let day = 6 - daysAgo
                    let hour = calendar.component(.hour, from: notif.timestamp)
                    let block = hour / 4
                    if block < 6 {
                        dayCounts[day][block] += 1
                    }
                }
            }

            for day in 0..<7 {
                for block in 0..<6 {
                    heatmapData.append(HeatmapCell(day: day, timeBlock: block, count: dayCounts[day][block]))
                }
            }
        }

        // 3. 计算活跃度曲线 (根据时间范围调整)
        var activityCurve: [DayActivity] = []

        let dayCount = range == .day ? 1 : 7
        for dayOffset in (0..<dayCount).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }

            let dayNotifications = filtered.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            let errorCount = dayNotifications.filter { $0.type == .error }.count
            let warningCount = dayNotifications.filter { $0.type == .warning }.count

            activityCurve.append(DayActivity(
                date: date,
                notificationCount: dayNotifications.count,
                errorCount: errorCount,
                warningCount: warningCount
            ))
        }

        // 4. 计算TOP工具
        let toolCounts = Dictionary(grouping: filtered.compactMap { $0.metadata?["tool_name"] }, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(5)

        let topTools = toolCounts.map { toolName, count in
            ToolUsage(
                toolName: toolName,
                count: count,
                icon: getToolIcon(toolName),
                color: getToolColor(toolName)
            )
        }

        // 5. 快速指标
        let errorCount = filtered.filter { $0.type == .error }.count
        let warningCount = filtered.filter { $0.type == .warning }.count

        // 6. 项目信息
        let projectName = project ?? filtered.first?.metadata?["project"] ?? "全部项目"

        // 计算总工作时长 (从session历史)
        let totalDuration = sessionHistory
            .filter { session in
                if let proj = project {
                    return session.projectName == proj
                }
                return true
            }
            .reduce(0.0) { $0 + $1.duration }

        return GlobalStatistics(
            timeRange: range,
            selectedProject: project,
            typeDistribution: typeDistribution,
            heatmapData: heatmapData,
            activityCurve: activityCurve,
            topTools: topTools,
            totalNotifications: filtered.count,
            errorCount: errorCount,
            warningCount: warningCount,
            projectName: projectName,
            totalDuration: totalDuration
        )
    }

    /// 获取工具图标
    private func getToolIcon(_ toolName: String) -> String {
        switch toolName.lowercased() {
        case "read": return "📖"
        case "write": return "✍️"
        case "edit": return "✏️"
        case "bash": return "⚡️"
        case "grep": return "🔍"
        case "glob": return "📁"
        case "task": return "🎯"
        case "webfetch": return "🌐"
        case "websearch": return "🔎"
        default: return "🔧"
        }
    }

    /// 获取工具颜色
    private func getToolColor(_ toolName: String) -> Color {
        switch toolName.lowercased() {
        case "read": return .blue
        case "write", "edit": return .green
        case "bash": return .orange
        case "grep", "glob": return .purple
        case "task": return .pink
        case "webfetch", "websearch": return .cyan
        default: return .gray
        }
    }

    /// 获取所有可用的项目列表
    func getAvailableProjects() -> [String] {
        let allNotifications = NotificationManager.shared.getPersistentHistory()
        let projects = Set(allNotifications.compactMap { $0.metadata?["project"] })
        return Array(projects).sorted()
    }
}

// MARK: - 可视化组件

/// 饼图扇形
struct PieSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle - .degrees(90),  // 调整起始角度让0度在顶部
            endAngle: endAngle - .degrees(90),
            clockwise: false
        )
        path.closeSubpath()

        return path
    }
}

/// 24小时横向条形图
struct HourlyBarChart: View {
    let heatmapData: [HeatmapCell]

    var body: some View {
        VStack(spacing: 2) {
            // 从热力图数据中提取最后一列（day=6）的6个时间块
            let blocks = (0..<6).map { block -> (block: Int, count: Int) in
                let cell = heatmapData.first { $0.day == 6 && $0.timeBlock == block }
                return (block, cell?.count ?? 0)
            }

            let maxCount = blocks.map { $0.count }.max() ?? 1

            ForEach(blocks.reversed(), id: \.block) { item in
                HStack(spacing: 4) {
                    // 时间标签
                    Text(timeLabel(for: item.block))
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 30, alignment: .trailing)

                    // 条形
                    GeometryReader { geo in
                        let width = maxCount > 0 ? (CGFloat(item.count) / CGFloat(maxCount)) * geo.size.width : 0
                        RoundedRectangle(cornerRadius: 2)
                            .fill(item.count > 0 ? Color.cyan.opacity(0.7) : Color.white.opacity(0.05))
                            .frame(width: max(width, 2))
                    }

                    // 数量
                    Text("\(item.count)")
                        .font(.system(size: 8))
                        .foregroundColor(.cyan)
                        .frame(width: 20, alignment: .leading)
                }
                .frame(height: 10)
            }
        }
    }

    private func timeLabel(for block: Int) -> String {
        let hoursAgo = (6 - block) * 4
        return "\(hoursAgo)h前"
    }
}

/// 时间热力图
struct HeatmapView: View {
    let data: [HeatmapCell]

    var body: some View {
        VStack(spacing: 2) {
            // 热力图网格 (6行×7列)
            VStack(spacing: 1) {
                ForEach(0..<6) { block in
                    HStack(spacing: 1) {
                        ForEach(0..<7) { day in
                            let cell = data.first { $0.day == day && $0.timeBlock == block }
                            Rectangle()
                                .fill(heatColor(intensity: cell?.intensity ?? 0))
                                .frame(width: 20, height: 12)
                        }
                    }
                }
            }

            // 底部标签：显示相对天数（-6天到今天）
            HStack(spacing: 1) {
                ForEach([-6, -5, -4, -3, -2, -1, 0], id: \.self) { dayOffset in
                    Text(dayOffset == 0 ? "今" : "\(dayOffset)")
                        .font(.system(size: 6))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: 20)
                }
            }
        }
    }

    private func heatColor(intensity: Double) -> Color {
        if intensity == 0 {
            return Color.white.opacity(0.05)
        }
        return Color.cyan.opacity(0.3 + intensity * 0.7)
    }
}

/// 通知类型饼图
struct NotificationTypePieChart: View {
    let distribution: [NotificationTypeDistribution]
    let totalCount: Int

    var body: some View {
        ZStack {
            // 饼图
            ForEach(distribution) { segment in
                PieSlice(
                    startAngle: segment.startAngle,
                    endAngle: segment.endAngle
                )
                .fill(getTypeColor(segment.type))
            }
            .frame(width: 100, height: 100)

            // 中心圆圈 + 总数
            Circle()
                .fill(Color.black.opacity(0.3))
                .frame(width: 50, height: 50)

            VStack(spacing: 2) {
                Text("\(totalCount)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("通知")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private func getTypeColor(_ type: NotchNotification.NotificationType) -> Color {
        // 创建一个临时通知实例来获取颜色
        let notification = NotchNotification(title: "", message: "", type: type)
        return notification.color
    }
}

/// 紧凑型图例(颜色点+数量)
struct CompactLegendItem: View {
    let color: Color
    let icon: String
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(icon)
                .font(.system(size: 8))
            Text("\(count)")
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}
/// 24小时紧凑曲线（基于热力图数据）
struct Compact24hCurve: View {
    let heatmapData: [HeatmapCell]

    var body: some View {
        GeometryReader { geo in
            let blocks = (0..<6).map { block -> Int in
                heatmapData.first { $0.day == 6 && $0.timeBlock == block }?.count ?? 0
            }.reversed()

            let maxCount = blocks.max() ?? 1
            let points = blocks.enumerated().map { index, count -> CGPoint in
                let x = CGFloat(index) / 5.0 * geo.size.width
                let y = maxCount > 0 ? geo.size.height * (1 - CGFloat(count) / CGFloat(maxCount)) : geo.size.height
                return CGPoint(x: x, y: y)
            }

            // 渐变填充区域
            Path { path in
                guard !points.isEmpty else { return }
                path.move(to: CGPoint(x: points[0].x, y: geo.size.height))
                for point in points {
                    path.addLine(to: point)
                }
                path.addLine(to: CGPoint(x: points.last!.x, y: geo.size.height))
                path.closeSubpath()
            }
            .fill(LinearGradient(
                colors: [Color.cyan.opacity(0.3), Color.cyan.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            ))

            // 曲线
            Path { path in
                guard !points.isEmpty else { return }
                path.move(to: points[0])
                for i in 1..<points.count {
                    path.addLine(to: points[i])
                }
            }
            .stroke(Color.cyan, lineWidth: 2)

            // 数据点
            ForEach(points.indices, id: \.self) { index in
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 4, height: 4)
                    .position(points[index])
            }
        }
    }
}

/// 活跃度曲线图
struct ActivityCurveView: View {
    let data: [DayActivity]

    var body: some View {
        GeometryReader { geometry in
            let maxCount = max(data.map { $0.notificationCount }.max() ?? 1, 1)
            let points = data.enumerated().map { index, activity -> CGPoint in
                let x = geometry.size.width * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                let y = geometry.size.height * (1 - CGFloat(activity.notificationCount) / CGFloat(maxCount))
                return CGPoint(x: x, y: y)
            }

            ZStack(alignment: .bottom) {
                // 渐变填充区域
                Path { path in
                    guard !points.isEmpty else { return }
                    path.move(to: CGPoint(x: points[0].x, y: geometry.size.height))
                    path.addLine(to: points[0])
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    path.addLine(to: CGPoint(x: points.last!.x, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.3), Color.cyan.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // 曲线
                Path { path in
                    guard !points.isEmpty else { return }
                    path.move(to: points[0])
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(Color.cyan, lineWidth: 2)

                // 数据点
                ForEach(data.indices, id: \.self) { index in
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 4, height: 4)
                        .position(points[index])
                }
            }
        }
    }
}

/// TOP工具条形图（迷你版）
struct MiniToolBarChart: View {
    let tool: ToolUsage

    var body: some View {
        HStack(spacing: 4) {
            Text(tool.icon)
                .font(.system(size: 10))
                .frame(width: 16)

            // 条形图
            HStack(spacing: 0) {
                ForEach(0..<10) { i in
                    Rectangle()
                        .fill(i < tool.level ? tool.color.opacity(0.8) : Color.white.opacity(0.08))
                        .frame(width: 10, height: 10)
                        .cornerRadius(1)
                }
            }

            Text("\(tool.count)")
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 24, alignment: .trailing)
        }
    }
}

/// 快速指标卡片
struct QuickStatCard: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

// MARK: - 全局统计主视图

/// 全局统计仪表盘视图 (600×130内容区)
struct GlobalStatsView: View {
    @ObservedObject var statsManager = StatisticsManager.shared
    @State private var timeRange: TimeRange = .week
    @State private var selectedProject: String? = nil
    @State private var stats: GlobalStatistics?
    @State private var availableProjects: [String] = []

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let stats = stats {
                VStack(spacing: 0) {
                    // 顶部筛选器（增加top padding避开刘海）
                    filterBar
                        .frame(height: 24)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)

                    // 主内容区 (三栏布局)
                    HStack(spacing: 12) {
                        // 左栏: 热力图 + 快速指标 (180px)
                        leftColumn(stats: stats)
                            .frame(width: 180)

                        // 中栏: 通知类型饼图 + 图例 (200px)
                        centerColumn(stats: stats)
                            .frame(width: 200)

                        // 右栏: 活跃度曲线 + TOP工具 (220px)
                        rightColumn(stats: stats)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            } else {
                // 加载中或无数据
                emptyState
            }

            // 关闭按钮
            closeButton
        }
        .frame(height: 160)
        .onAppear {
            availableProjects = statsManager.getAvailableProjects()
            loadData()
        }
        .onChange(of: timeRange) { _ in
            loadData()
        }
        .onChange(of: selectedProject) { _ in
            loadData()
        }
    }

    // MARK: - 筛选栏

    private var filterBar: some View {
        HStack(spacing: 8) {
            // 时间范围选择器
            Picker("", selection: $timeRange) {
                ForEach(TimeRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            .zIndex(10)  // 提高层级

            Spacer()
                .allowsHitTesting(false)  // 空白区域不响应点击

            // 项目筛选菜单（紧凑图标设计）
            Menu {
                Button("全部项目") {
                    selectedProject = nil
                }

                Divider()

                ForEach(availableProjects, id: \.self) { project in
                    Button(project) {
                        selectedProject = project
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.cyan.opacity(0.7))

                    Text((stats?.projectName ?? "全部").prefix(3))  // 限制最多3个字符
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)

                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
            .zIndex(10)  // 提高层级

            // 右侧间距，避免与关闭按钮重叠
            Spacer()
                .frame(width: 40)  // 为关闭按钮留出空间
                .allowsHitTesting(false)
        }
    }

    // MARK: - 左栏

    private func leftColumn(stats: GlobalStatistics) -> some View {
        VStack(spacing: 6) {
            if stats.timeRange == .day {
                // 24h模式：横向条形图
                HourlyBarChart(heatmapData: stats.heatmapData)
                    .frame(height: 80)
            } else {
                // 7天模式：热力图
                HeatmapView(data: stats.heatmapData)
                    .frame(height: 80)
            }

            // 快速指标
            HStack(spacing: 12) {
                QuickStatCard(
                    icon: "bell.fill",
                    value: "\(stats.totalNotifications)",
                    color: .cyan
                )
                QuickStatCard(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(stats.errorCount)",
                    color: .red
                )
            }
            .frame(height: 20)
        }
    }

    // MARK: - 中栏

    private func centerColumn(stats: GlobalStatistics) -> some View {
        HStack(spacing: 8) {
            // 饼图
            NotificationTypePieChart(
                distribution: stats.typeDistribution,
                totalCount: stats.totalNotifications
            )
            .frame(width: 100, height: 100)

            // 图例 (TOP 6类型)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(stats.typeDistribution.prefix(6))) { dist in
                    let notification = NotchNotification(title: "", message: "", type: dist.type)
                    CompactLegendItem(
                        color: notification.color,
                        icon: typeIcon(dist.type),
                        count: dist.count
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 右栏

    private func rightColumn(stats: GlobalStatistics) -> some View {
        VStack(spacing: 6) {
            if stats.timeRange == .day {
                // 24h模式：显示小时级分布（使用条形图数据）
                Compact24hCurve(heatmapData: stats.heatmapData)
                    .frame(height: 50)
            } else {
                // 7天模式：显示天级活跃度曲线
                ActivityCurveView(data: stats.activityCurve)
                    .frame(height: 50)
            }

            // TOP工具 (显示TOP 3)
            VStack(spacing: 3) {
                ForEach(stats.topTools.prefix(3)) { tool in
                    MiniToolBarChart(tool: tool)
                }
            }
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            Text("暂无统计数据")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 关闭按钮

    private var closeButton: some View {
        Button(action: {
            NotchViewModel.shared?.returnToNormal()
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.3))
                .padding(6)  // 适度的点击区域
                .background(Circle().fill(Color.black.opacity(0.01)))  // 透明圆形背景
                .contentShape(Circle())  // 仅圆形区域可点击（避免矩形误触）
        }
        .buttonStyle(PlainButtonStyle())
        .padding(8)
        .zIndex(100)  // 确保在最上层
    }

    // MARK: - 辅助方法

    private func loadData() {
        stats = statsManager.loadGlobalStatistics(range: timeRange, project: selectedProject)
    }

    private func typeIcon(_ type: NotchNotification.NotificationType) -> String {
        switch type {
        case .success: return "✓"
        case .error: return "✗"
        case .warning: return "⚠"
        case .info: return "ℹ"
        case .hook: return "🪝"
        case .toolUse: return "🔧"
        case .progress: return "⏳"
        case .celebration: return "🎉"
        case .reminder: return "🔔"
        case .download: return "↓"
        case .upload: return "↑"
        case .security: return "🔒"
        case .ai: return "🤖"
        case .sync: return "🔄"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return String(format: "%dh%02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}
