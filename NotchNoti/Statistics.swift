//
//  Statistics.swift
//  NotchNoti
//
//  统计功能完整实现 - 包含数据模型、管理器和视图
//

import Foundation
import SwiftUI

// MARK: - 数据模型

struct SessionStats: Codable, Identifiable {
    let id: UUID
    let sessionId: String
    let projectName: String
    let startTime: Date
    var endTime: Date?
    var toolUsage: [String: ToolStats]
    var totalOperations: Int
    var errorCount: Int
    var errors: [ErrorRecord]

    init(sessionId: String, projectName: String) {
        self.id = UUID()
        self.sessionId = sessionId
        self.projectName = projectName
        self.startTime = Date()
        self.endTime = nil
        self.toolUsage = [:]
        self.totalOperations = 0
        self.errorCount = 0
        self.errors = []
    }

    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    var successRate: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(totalOperations - errorCount) / Double(totalOperations)
    }

    var topTools: [(String, ToolStats)] {
        toolUsage.sorted { $0.value.count > $1.value.count }.prefix(5).map { ($0.key, $0.value) }
    }
}

struct ToolStats: Codable {
    var count: Int
    var successCount: Int
    var failureCount: Int
    var totalDuration: TimeInterval
    var minDuration: TimeInterval
    var maxDuration: TimeInterval

    init() {
        self.count = 0
        self.successCount = 0
        self.failureCount = 0
        self.totalDuration = 0
        self.minDuration = .infinity
        self.maxDuration = 0
    }

    var averageDuration: TimeInterval {
        guard count > 0 else { return 0 }
        return totalDuration / Double(count)
    }

    var successRate: Double {
        guard count > 0 else { return 0 }
        return Double(successCount) / Double(count)
    }

    mutating func recordSuccess(duration: TimeInterval) {
        count += 1
        successCount += 1
        totalDuration += duration
        minDuration = min(minDuration, duration)
        maxDuration = max(maxDuration, duration)
    }

    mutating func recordFailure(duration: TimeInterval) {
        count += 1
        failureCount += 1
        totalDuration += duration
        minDuration = min(minDuration, duration)
        maxDuration = max(maxDuration, duration)
    }
}

struct ErrorRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let toolName: String
    let errorMessage: String
    let context: String?
    let metadata: [String: String]?

    init(toolName: String, errorMessage: String, context: String? = nil, metadata: [String: String]? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.toolName = toolName
        self.errorMessage = errorMessage
        self.context = context
        self.metadata = metadata
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// MARK: - 统计管理器

class StatisticsManager: ObservableObject {
    static let shared = StatisticsManager()

    @Published var currentSession: SessionStats?
    @Published var sessionHistory: [SessionStats] = []
    @Published var showStats: Bool = false

    private let maxHistoryCount = 20
    private let persistenceKey = "com.notchnoti.sessionStats"

    private init() {
        loadHistory()
    }

    func startSession(sessionId: String, projectName: String) {
        print("[StatisticsManager] 开始新会话: \(projectName)")
        if var current = currentSession {
            current.endTime = Date()
            addToHistory(current)
        }
        currentSession = SessionStats(sessionId: sessionId, projectName: projectName)
    }

    func endSession() {
        guard var current = currentSession else { return }
        print("[StatisticsManager] 结束会话: \(current.projectName)")
        current.endTime = Date()
        addToHistory(current)
        currentSession = nil
    }

    func recordToolUse(toolName: String, success: Bool, duration: TimeInterval) {
        guard var current = currentSession else { return }
        current.totalOperations += 1
        var stats = current.toolUsage[toolName] ?? ToolStats()
        if success {
            stats.recordSuccess(duration: duration)
        } else {
            stats.recordFailure(duration: duration)
            current.errorCount += 1
        }
        current.toolUsage[toolName] = stats
        currentSession = current
        print("[StatisticsManager] 记录工具使用: \(toolName), 成功: \(success), 耗时: \(String(format: "%.2f", duration))s")
    }

    func recordError(_ error: ErrorRecord) {
        guard var current = currentSession else { return }
        current.errors.append(error)
        currentSession = current
        print("[StatisticsManager] 记录错误: \(error.toolName) - \(error.errorMessage)")
    }

    private func addToHistory(_ session: SessionStats) {
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
              let decoded = try? JSONDecoder().decode([SessionStats].self, from: data) else {
            return
        }
        sessionHistory = decoded
    }

    func getTodayStats() -> [SessionStats] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return sessionHistory.filter { session in
            calendar.isDate(session.startTime, inSameDayAs: today)
        }
    }

    func getTotalToolUsage() -> [String: Int] {
        var usage: [String: Int] = [:]
        for session in sessionHistory {
            for (tool, stats) in session.toolUsage {
                usage[tool, default: 0] += stats.count
            }
        }
        return usage
    }

    func getAverageSuccessRate() -> Double {
        guard !sessionHistory.isEmpty else { return 0 }
        let totalRate = sessionHistory.reduce(0.0) { $0 + $1.successRate }
        return totalRate / Double(sessionHistory.count)
    }
}

// MARK: - UI 视图 (优化刘海显示)

struct NotchStatsView: View {
    @ObservedObject var statsManager = StatisticsManager.shared
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            // 紧凑标题栏
            HStack {
                // 页面指示器
                HStack(spacing: 4) {
                    Circle()
                        .fill(currentPage == 0 ? Color.cyan : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(currentPage == 1 ? Color.red : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                }

                Spacer()

                Text(currentPage == 0 ? "📊 会话统计" : "❌ 错误记录")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                // 切换和关闭按钮
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation { currentPage = (currentPage + 1) % 2 }
                    }) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.caption)
                            .foregroundColor(.cyan)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        NotchViewModel.shared?.contentType = .normal
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

            // 内容区域 - 手动切换页面
            ZStack {
                if currentPage == 0 {
                    CompactStatsView(session: statsManager.currentSession)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                } else {
                    CompactErrorView(session: statsManager.currentSession)
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
}

// 紧凑型统计视图 - 专为刘海显示优化
struct CompactStatsView: View {
    let session: SessionStats?

    var body: some View {
        if let session = session {
            HStack(spacing: 12) {
                // 左侧: 关键指标
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
                        Text("🔧")
                            .font(.caption2)
                        Text("\(session.totalOperations) 次")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }

                    HStack(spacing: 6) {
                        Text("✅")
                            .font(.caption2)
                        Text(String(format: "%.0f%%", session.successRate * 100))
                            .font(.caption)
                            .foregroundColor(session.successRate > 0.8 ? .green : .orange)
                    }
                }
                .frame(width: 120, alignment: .leading)

                Divider()
                    .frame(height: 80)
                    .opacity(0.3)

                // 右侧: TOP3 工具
                if !session.topTools.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TOP 工具")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))

                        ForEach(session.topTools.prefix(3), id: \.0) { tool, stats in
                            HStack(spacing: 4) {
                                Text(tool)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(1)

                                Spacer()

                                Text("\(stats.count)")
                                    .font(.caption2)
                                    .foregroundColor(.cyan)

                                // 成功率指示器
                                Circle()
                                    .fill(stats.successRate > 0.8 ? Color.green : Color.orange)
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Text("暂无工具使用")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.5))
                Text("暂无会话数据")
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

// 紧凑型错误视图 - 专为刘海显示优化
struct CompactErrorView: View {
    let session: SessionStats?

    var body: some View {
        if let errors = session?.errors, !errors.isEmpty {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(errors.prefix(3)) { error in
                        HStack(alignment: .top, spacing: 8) {
                            Text("❌")
                                .font(.caption2)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(error.toolName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.red.opacity(0.9))

                                    Spacer()

                                    Text(error.formattedTime)
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.4))
                                }

                                Text(error.errorMessage)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(2)
                            }
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 32))
                    .foregroundColor(.green.opacity(0.5))
                Text("暂无错误")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// 以下组件已移除，使用上方的 CompactStatsView 和 CompactErrorView 代替
// 旧版本的 CurrentSessionView, ErrorHistoryView, OverviewView 占用空间过大，不适合刘海显示
