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
    @State private var searchText = ""

    // 过滤后的通知列表
    private var filteredNotifications: [NotchNotification] {
        if searchText.isEmpty {
            return Array(manager.notificationHistory.prefix(6))
        } else {
            return manager.notificationHistory.filter { notification in
                notification.title.localizedCaseInsensitiveContains(searchText) ||
                notification.message.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // 顶部栏：关闭按钮 + 搜索框
                if !manager.notificationHistory.isEmpty {
                    HStack(spacing: 8) {
                        // 关闭按钮
                        Button(action: {
                            NotchViewModel.shared?.returnToNormal()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .buttonStyle(PlainButtonStyle())

                        // 搜索栏
                        searchBar
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                } else {
                    // 没有通知时，只显示关闭按钮
                    HStack {
                        Spacer()
                        Button(action: {
                            NotchViewModel.shared?.returnToNormal()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }

                if filteredNotifications.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 1) {
                            ForEach(filteredNotifications) { notification in
                                CompactNotificationRow(notification: notification)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.15))
    }

    // 搜索栏
    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))

            TextField("搜索通知...", text: $searchText)
                .font(.system(size: 11))
                .textFieldStyle(.plain)
                .foregroundColor(.white)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .cornerRadius(8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: searchText.isEmpty ? "bell.slash" : "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.25))
            Text(searchText.isEmpty ? "暂无通知" : "无匹配结果")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// 单行通知 - iOS风格列表设计
struct CompactNotificationRow: View {
    let notification: NotchNotification

    var body: some View {
        HStack(spacing: 10) {
            // 图标 - 更小更精致
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(notification.color.opacity(0.18))
                    .frame(width: 28, height: 28)

                Image(systemName: notification.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(notification.color)
            }

            // 文字内容
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)

                if !notification.message.isEmpty {
                    Text(notification.message)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }

                // 显示用户选择 - 如果有交互式操作
                if let userChoice = getUserChoice() {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.green.opacity(0.7))
                        Text("已选择: \(userChoice)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.green.opacity(0.8))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(4)
                }
            }

            Spacer(minLength: 0)

            // 右侧：Diff/总结按钮 + 时间（时间始终靠右）
            HStack(spacing: 6) {
                // 总结按钮 - 重新打开总结窗口
                if notification.metadata?["summary_id"] != nil {
                    Button(action: {
                        openSummaryWindow()
                    }) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green.opacity(0.9))
                            .frame(width: 20, height: 20)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("重新打开总结")
                }

                // Diff 预览按钮 - 更小更精致
                if notification.metadata?["diff_path"] != nil {
                    Button(action: {
                        openDiffWindow()
                    }) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue.opacity(0.9))
                            .frame(width: 20, height: 20)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("查看文件改动")
                }

                // 时间标签 - 始终在最右边
                Text(timeAgo(notification.timestamp))
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Rectangle()
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

    // 获取用户选择（从 metadata 中提取）
    private func getUserChoice() -> String? {
        // 检查是否是交互式通知
        guard let metadata = notification.metadata,
              metadata["actionable"] == "true",
              let requestId = metadata["request_id"] else {
            return nil
        }

        // 从 actions 中查找被选择的那个
        if let actions = notification.actions {
            for action in actions {
                // action.action 格式: "mcp_action:<requestId>:<choice>"
                if action.action.hasPrefix("mcp_action:\(requestId):") {
                    let components = action.action.components(separatedBy: ":")
                    if components.count == 3 {
                        // 检查该 action 是否被标记为已选择（存储在 metadata 中）
                        if metadata["user_choice"] == action.label {
                            return action.label
                        }
                    }
                }
            }
        }

        return nil
    }

    private func openDiffWindow() {
        guard let diffPath = notification.metadata?["diff_path"],
              let filePath = notification.metadata?["file_path"] else { return }

        let isPreview = notification.metadata?["is_preview"] == "true"

        // 创建新窗口显示 DiffView
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        window.title = isPreview ? "改动预览 - \(fileName)" : "文件改动 - \(fileName)"
        window.center()
        window.setFrameAutosaveName("DiffWindow")

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

    private func openSummaryWindow() {
        guard let summaryIdString = notification.metadata?["summary_id"],
              let summaryId = UUID(uuidString: summaryIdString) else {
            print("[CompactNotificationRow] No summary_id found in metadata")
            return
        }

        // 从 SessionSummaryManager 中查找总结
        guard let summary = SessionSummaryManager.shared.recentSummaries.first(where: { $0.id == summaryId }) else {
            print("[CompactNotificationRow] Summary not found in SessionSummaryManager: \(summaryIdString)")
            return
        }

        // 使用 SummaryWindowController 打开总结窗口
        let projectPath = notification.metadata?["project_path"]
        SummaryWindowController.shared.showSummary(summary, projectPath: projectPath)

        // 打开窗口后收起刘海
        NotchViewModel.shared?.notchClose()
    }
}

// MARK: - 通知统计 - 带智能洞察

struct CompactStatsView: View {
    var body: some View {
        CompactWorkSessionStatsView()  // 使用单页面工作会话统计
    }
}

// MARK: - AI洞察 - LLM分析

struct CompactAIAnalysisView: View {
    @ObservedObject var aiManager = AIAnalysisManager.shared
    @ObservedObject var notifStatsManager = NotificationStatsManager.shared

    var body: some View {
        ZStack(alignment: .topTrailing) {
            let summary = notifStatsManager.getSummary()

            if aiManager.isAnalyzing {
                analyzingState
            } else if let error = aiManager.lastError {
                errorState(error, summary: summary)
            } else if let analysis = aiManager.lastAnalysis {
                resultView(analysis, summary: summary)
            } else {
                initialState(summary: summary)
            }

            closeButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.15))
        .onAppear {
            aiManager.updateAvailableProjects()
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
    private func errorState(_ error: String, summary: StatsSummary) -> some View {
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
                    Task { await aiManager.analyzeNotifications(summary: summary) }
                }
                .font(.system(size: 9))
                .buttonStyle(.borderless)
            }

            Spacer()
        }
        .padding(.leading, 20)
    }

    // 分析结果
    private func resultView(_ analysis: String, summary: StatsSummary) -> some View {
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

                    // 项目选择器
                    if !aiManager.availableProjects.isEmpty {
                        Picker("", selection: Binding(
                            get: { aiManager.selectedProject ?? aiManager.availableProjects.first ?? "" },
                            set: { aiManager.selectedProject = $0 }
                        )) {
                            ForEach(aiManager.availableProjects, id: \.self) { project in
                                Text(project)
                                    .font(.system(size: 9))
                                    .tag(project)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .font(.system(size: 9))
                        .frame(height: 16)
                    }

                    Spacer()
                }

                Text(analysis)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button(action: {
                        Task { await aiManager.analyzeNotifications(summary: summary) }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.clockwise")
                            Text("重新分析 \(aiManager.selectedProject ?? "")")
                                .lineLimit(1)
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

    // 初始状态 - 横向紧凑布局
    private func initialState(summary: StatsSummary) -> some View {
        HStack(spacing: 20) {
            // 左侧图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .blur(radius: 6)

                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(.purple)
            }

            // 右侧内容
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("AI 工作洞察")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)

                    // 项目选择器
                    if !aiManager.availableProjects.isEmpty {
                        Picker("", selection: Binding(
                            get: { aiManager.selectedProject ?? aiManager.availableProjects.first ?? "" },
                            set: { aiManager.selectedProject = $0 }
                        )) {
                            ForEach(aiManager.availableProjects, id: \.self) { project in
                                Text(project)
                                    .font(.system(size: 9))
                                    .tag(project)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .font(.system(size: 9))
                        .frame(height: 18)
                    }
                }

                if summary.totalCount > 0, aiManager.loadConfig() != nil {
                    Button(action: {
                        Task {
                            await aiManager.analyzeNotifications(summary: summary)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 9))
                            Text("分析 \(aiManager.selectedProject ?? "项目")")
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                } else if summary.totalCount == 0 {
                    Text("暂无通知数据")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    Button("配置AI分析") {
                        AISettingsWindowManager.shared.show()
                    }
                    .font(.system(size: 9))
                    .buttonStyle(.borderless)
                }
            }

            Spacer()
        }
        .padding(.leading, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var closeButton: some View {
        Button(action: {
            NotchViewModel.shared?.returnToNormal()
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

// MARK: - Session总结列表 - 紧凑纵向列表

struct CompactSummaryListView: View {
    @ObservedObject var manager = SessionSummaryManager.shared

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // 顶部栏：关闭按钮
                HStack {
                    Spacer()
                    Button(action: {
                        NotchViewModel.shared?.returnToNormal()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                if manager.recentSummaries.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 1) {
                            ForEach(manager.recentSummaries) { summary in
                                CompactSummaryRow(summary: summary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.3))
            Text("暂无总结")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 紧凑总结行

struct CompactSummaryRow: View {
    let summary: SessionSummary

    var body: some View {
        Button(action: {
            // 打开总结窗口
            SummaryWindowController.shared.showSummary(summary, projectPath: nil)

            // 延迟关闭notch，避免与新窗口的渲染冲突
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotchViewModel.shared?.notchClose()
            }
        }) {
            HStack(spacing: 10) {
                // 左侧：图标和项目信息
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)

                        Text(summary.projectName)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }

                    Text(summary.taskDescription.isEmpty ? "无描述" : summary.taskDescription)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                // 右侧：时间和统计
                VStack(alignment: .trailing, spacing: 2) {
                    Text(timeAgo(summary.startTime))
                        .font(.system(size: 9, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.5))

                    HStack(spacing: 4) {
                        if !summary.completedTasks.isEmpty {
                            Text("\(summary.completedTasks.count)✓")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.green)
                        }
                        if !summary.modifiedFiles.isEmpty {
                            Text("\(summary.modifiedFiles.count)📄")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if days > 0 {
            return "\(days)天前"
        } else if hours > 0 {
            return "\(hours)小时前"
        } else if minutes > 0 {
            return "\(minutes)分钟前"
        } else {
            return "刚刚"
        }
    }
}
