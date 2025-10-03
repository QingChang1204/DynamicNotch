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
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(manager.notificationHistory.prefix(6)) { notification in
                            CompactNotificationRow(notification: notification)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                }
            }

            // 右上角关闭按钮
            Button(action: {
                NotchViewModel.shared?.contentType = .normal
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.4))
                    .background(Circle().fill(Color.black.opacity(0.3)))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.2))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.2))
            Text("暂无通知")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 单行通知 - 卡片式设计
struct CompactNotificationRow: View {
    let notification: NotchNotification

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(notification.color.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: notification.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(notification.color)
            }

            // 文字内容
            VStack(alignment: .leading, spacing: 3) {
                Text(notification.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)

                if !notification.message.isEmpty {
                    Text(notification.message)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            // 时间标签
            Text(timeAgo(notification.timestamp))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
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

// MARK: - 通知统计 - 带智能洞察

struct CompactStatsView: View {
    var body: some View {
        CompactNotificationStatsView()
    }
}

// MARK: - AI洞察 - LLM分析

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
                resultView(analysis)
            } else {
                initialState
            }

            closeButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.2))
        .onAppear {
            // 自动分析一次
            if aiManager.lastAnalysis == nil,
               statsManager.currentSession != nil,
               aiManager.loadConfig() != nil {
                Task { await aiManager.analyzeCurrentSession() }
            }
        }
    }

    // 分析中状态
    private var analyzingState: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.purple, .pink, .purple],
                            center: .center
                        )
                    )
                    .frame(width: 48, height: 48)
                    .blur(radius: 6)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("AI 分析中")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Text("正在分析工作模式...")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))

                ProgressView()
                    .scaleEffect(0.6)
                    .frame(height: 3)
            }

            Spacer()
        }
        .padding(.leading, 20)
    }

    // 错误状态
    private func errorState(_ error: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 6) {
                Text("分析失败")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                Text(error)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)

                Button("重试") {
                    Task { await aiManager.analyzeCurrentSession() }
                }
                .font(.system(size: 9))
                .buttonStyle(.borderless)
            }

            Spacer()
        }
        .padding(.leading, 20)
    }

    // 分析结果
    private func resultView(_ analysis: String) -> some View {
        HStack(spacing: 0) {
            // 左侧：装饰性渐变条
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .padding(.leading, 12)

            // 主要内容
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)

                    Text("AI 洞察")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))

                    Spacer()
                }

                Text(analysis)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button(action: {
                        Task { await aiManager.analyzeCurrentSession() }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.clockwise")
                            Text("重新分析")
                        }
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.purple.opacity(0.8))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        AISettingsWindowManager.shared.show()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "gearshape")
                            Text("设置")
                        }
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
            .padding(.leading, 10)
            .padding(.vertical, 12)
            .padding(.trailing, 40)

            Spacer()
        }
    }

    // 初始状态
    private var initialState: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: "sparkles")
                    .font(.system(size: 22))
                    .foregroundColor(.purple)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("AI 工作洞察")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                if statsManager.currentSession != nil {
                    Button("开始分析") {
                        Task { await aiManager.analyzeCurrentSession() }
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.borderless)
                } else {
                    Text("开始工作后可分析")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }

                Button("配置LLM") {
                    AISettingsWindowManager.shared.show()
                }
                .font(.system(size: 9))
                .buttonStyle(.borderless)
            }

            Spacer()
        }
        .padding(.leading, 20)
    }

    private var closeButton: some View {
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
