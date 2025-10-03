//
//  NotchCompactViews.swift
//  NotchNoti
//
//  紧凑型刘海视图 - 图形化优先设计
//

import SwiftUI

// MARK: - 通知历史 - 紧凑纵向列表

struct CompactNotificationHistoryView: View {
    @ObservedObject var manager = NotificationManager.shared

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if manager.notificationHistory.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(manager.notificationHistory.prefix(8)) { notification in
                            CompactNotificationRow(notification: notification)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }

            // 右上角关闭按钮
            Button(action: {
                NotchViewModel.shared?.contentType = .normal
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.3))
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.2))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.2))
            Text("暂无通知")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 单行通知 - 极简紧凑
struct CompactNotificationRow: View {
    let notification: NotchNotification

    var body: some View {
        HStack(spacing: 8) {
            // 图标
            ZStack {
                Circle()
                    .fill(notification.color.opacity(0.15))
                    .frame(width: 24, height: 24)

                Image(systemName: notification.systemImage)
                    .font(.system(size: 11))
                    .foregroundColor(notification.color)
            }

            // 文字内容
            VStack(alignment: .leading, spacing: 1) {
                Text(notification.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)

                if !notification.message.isEmpty {
                    Text(notification.message)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            // 时间
            Text(timeAgo(notification.timestamp))
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.3))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        return "\(days)d"
    }
}

// MARK: - 工作统计 - 仪表盘式

struct CompactStatsView: View {
    @ObservedObject var statsManager = StatisticsManager.shared
    @State private var showDetails = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let session = statsManager.currentSession {
                HStack(spacing: 16) {
                    // 左侧：大数字显示
                    VStack(spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatMinutes(session.duration))
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundColor(.cyan)

                            Text("min")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.cyan.opacity(0.6))
                                .padding(.bottom, 8)
                        }

                        Text(session.workMode.rawValue)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(width: 180)

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .frame(height: 100)

                    // 中间：环形进度
                    VStack(spacing: 8) {
                        ZStack {
                            // 背景圆环
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 8)
                                .frame(width: 80, height: 80)

                            // 进度圆环
                            Circle()
                                .trim(from: 0, to: min(CGFloat(session.totalActivities) / 100.0, 1.0))
                                .stroke(
                                    AngularGradient(
                                        colors: [.purple, .pink, .purple],
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(response: 1.0, dampingFraction: 0.8), value: session.totalActivities)

                            // 中心数字
                            VStack(spacing: 2) {
                                Text("\(session.totalActivities)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("操作")
                                    .font(.system(size: 8))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }

                        Text(session.intensity.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange.opacity(0.8))
                    }
                    .frame(width: 100)

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .frame(height: 100)

                    // 右侧：活动分布迷你条形图
                    VStack(alignment: .leading, spacing: 6) {
                        Text("活动")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))

                        let topActivities = session.activityDistribution.sorted { $0.value > $1.value }.prefix(4)

                        ForEach(Array(topActivities), id: \.key) { type, count in
                            HStack(spacing: 6) {
                                Text(type.icon)
                                    .font(.system(size: 10))

                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(
                                            LinearGradient(
                                                colors: [type.color, type.color.opacity(0.6)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: min(CGFloat(count) * 3, geo.size.width))
                                }
                                .frame(height: 4)

                                Text("\(count)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 20, alignment: .trailing)
                            }
                            .frame(height: 16)
                        }
                    }
                    .frame(width: 180)
                }
                .padding(.horizontal, 20)
            } else {
                emptySessionState
            }

            closeButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.2))
    }

    private var emptySessionState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.2))
            Text("开始工作后将显示统计")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
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

    private func formatMinutes(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return "\(minutes)"
    }
}

// MARK: - AI分析 - 卡片式

struct CompactAIAnalysisView: View {
    @ObservedObject var aiManager = AIAnalysisManager.shared
    @ObservedObject var statsManager = StatisticsManager.shared

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if aiManager.isAnalyzing {
                analyzingState
            } else if let error = aiManager.lastError {
                errorState(error)
            } else if let analysis = aiManager.lastAnalysis {
                resultCard(analysis)
            } else {
                initialState
            }

            // 右上角按钮组
            HStack(spacing: 8) {
                Button(action: {
                    AISettingsWindowManager.shared.show()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    NotchViewModel.shared?.contentType = .normal
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.3))
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.2))
    }

    private var analyzingState: some View {
        HStack(spacing: 16) {
            // 左侧：动画图标
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.purple, .pink, .purple],
                            center: .center
                        )
                    )
                    .frame(width: 60, height: 60)
                    .blur(radius: 8)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            .padding(.leading, 24)

            // 右侧：文字
            VStack(alignment: .leading, spacing: 6) {
                Text("AI 分析中")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text("正在分析工作模式和节奏...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))

                ProgressView()
                    .scaleEffect(0.7)
                    .frame(height: 4)
            }

            Spacer()
        }
    }

    private func errorState(_ error: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
                .padding(.leading, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("分析失败")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)

                Button("重试") {
                    Task { await aiManager.analyzeCurrentSession() }
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }

            Spacer()
        }
    }

    private func resultCard(_ analysis: String) -> some View {
        HStack(spacing: 0) {
            // 左侧：装饰性渐变条
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)
                .padding(.leading, 16)

            // 主要内容
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundColor(.purple)

                    Text("AI 洞察")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))

                    Spacer()
                }

                Text(analysis)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Button(action: {
                        Task { await aiManager.analyzeCurrentSession() }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("重新分析")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.purple.opacity(0.8))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 16)
            .padding(.trailing, 50) // 留空间给右上角按钮

            Spacer()
        }
    }

    private var initialState: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundColor(.purple)
            }
            .padding(.leading, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("AI 工作洞察")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                if statsManager.currentSession != nil {
                    Button("开始分析") {
                        Task { await aiManager.analyzeCurrentSession() }
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                } else {
                    Text("开始工作后可分析")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()
        }
    }
}

// MARK: - 辅助扩展

extension ActivityType {
    var icon: String {
        switch self {
        case .read: return "📖"
        case .write: return "📝"
        case .edit: return "✏️"
        case .bash: return "⚡️"
        case .grep: return "🔎"
        case .glob: return "📁"
        case .task: return "🎯"
        case .other: return "📋"
        }
    }

    var color: Color {
        switch self {
        case .read: return .blue
        case .write: return .green
        case .edit: return .orange
        case .bash: return .yellow
        case .grep: return .purple
        case .glob: return .pink
        case .task: return .cyan
        case .other: return .gray
        }
    }
}
