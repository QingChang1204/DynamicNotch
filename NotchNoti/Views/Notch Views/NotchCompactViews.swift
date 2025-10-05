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
    @State private var loadedNotifications: [NotchNotification] = []
    @State private var currentPage = 0
    @State private var isLoading = false
    @State private var hasMore = true
    @State private var totalCount = 0

    private let pageSize = 20  // 每页20条

    // 判断是否在历史视图（只有历史视图才显示搜索和清空按钮）
    private var isHistoryView: Bool {
        NotchViewModel.shared?.contentType == .history
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // 顶部栏：历史视图显示搜索框和清空按钮（有通知时）或关闭按钮（无通知时）
                if isHistoryView {
                    if !manager.notificationHistory.isEmpty {
                        HStack(spacing: 8) {
                            // 搜索栏
                            searchBar

                            // 清除按钮
                            Button(action: {
                                manager.clearHistory()
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("清空历史")

                            // 关闭按钮
                            Button(action: {
                                NotchViewModel.shared?.returnToNormal()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("返回")
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                    } else {
                        // 历史为空时，只显示关闭按钮
                        HStack {
                            Spacer()
                            Button(action: {
                                NotchViewModel.shared?.returnToNormal()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("返回")
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    }
                }

                if loadedNotifications.isEmpty && !isLoading {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 1) {
                            ForEach(loadedNotifications) { notification in
                                CompactNotificationRow(notification: notification)
                                    .onAppear {
                                        // 当滚动到倒数第3个时，触发加载下一页
                                        if notification.id == loadedNotifications[max(0, loadedNotifications.count - 3)].id {
                                            loadNextPage()
                                        }
                                    }
                            }

                            // 加载指示器
                            if isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .progressViewStyle(.circular)
                                        .tint(.white.opacity(0.5))
                                    Text("加载中...")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.5))
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            } else if !hasMore && loadedNotifications.count > 0 {
                                // 已加载全部
                                HStack {
                                    Spacer()
                                    Text("已加载全部 \(totalCount) 条通知")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.35))
                                    Spacer()
                                }
                                .padding(.vertical, 8)
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
        .background(Color.black)
        .onAppear {
            loadFirstPage()
        }
        .onChange(of: searchText) { _ in
            // 搜索文本变化时，重新加载
            resetAndLoad()
        }
    }

    // MARK: - 分页加载逻辑

    /// 加载第一页
    private func loadFirstPage() {
        // 只在历史视图模式下使用持久化存储，其他情况用内存（性能更好）
        if isHistoryView {
            // 历史视图：从持久化存储分页加载（5000条）
            currentPage = 0
            loadedNotifications = []
            hasMore = true
            totalCount = manager.getHistoryCount(searchText: searchText.isEmpty ? nil : searchText)
            loadNextPage()
        } else {
            // 非历史视图：直接用内存中的全部通知（最多50条）
            loadedNotifications = manager.notificationHistory
            hasMore = false
        }
    }

    /// 重置并重新加载（搜索时使用）
    private func resetAndLoad() {
        // 搜索只在历史视图模式下有效
        if isHistoryView {
            loadedNotifications = []
            currentPage = 0
            hasMore = true
            totalCount = manager.getHistoryCount(searchText: searchText.isEmpty ? nil : searchText)
            loadNextPage()
        }
    }

    /// 加载下一页
    private func loadNextPage() {
        guard !isLoading && hasMore else { return }

        isLoading = true

        Task {
            let newNotifications = await manager.loadHistoryPage(
                page: currentPage,
                pageSize: pageSize,
                searchText: searchText.isEmpty ? nil : searchText
            )

            await MainActor.run {
                if !newNotifications.isEmpty {
                    loadedNotifications.append(contentsOf: newNotifications)
                    currentPage += 1
                    hasMore = newNotifications.count == pageSize
                } else {
                    hasMore = false
                }
                isLoading = false
            }
        }
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
        .background(Color.black.opacity(0.3))
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
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        window.title = isPreview ? "改动预览 - \(fileName)" : "文件改动 - \(fileName)"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.95)
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
    @ObservedObject var insightsAnalyzer = WorkInsightsAnalyzer.shared
    @ObservedObject var statsManager = StatisticsManager.shared

    @State private var isAnalyzing = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 主内容区
            if isAnalyzing {
                analyzingState
            } else if let latestInsight = insightsAnalyzer.recentInsights.first {
                insightCardView(latestInsight)
            } else {
                emptyState
            }

            // 右上角关闭按钮
            closeButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.1))
        .onAppear {
            // 视图出现时自动分析（如果还没有洞察）
            if insightsAnalyzer.recentInsights.isEmpty && hasEnoughData {
                Task {
                    await analyzeCurrentSession()
                }
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
                    .frame(width: 40, height: 40)
                    .blur(radius: 6)

                Image(systemName: "sparkles")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("AI 分析中")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                Text("正在分析工作模式...")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))

                ProgressView()
                    .scaleEffect(0.5)
                    .frame(height: 2)
            }

            Spacer()
        }
        .padding(.leading, 16)
    }

    // 洞察卡片 - 横向布局优化刘海显示
    private func insightCardView(_ insight: WorkInsight) -> some View {
        HStack(spacing: 12) {
            // 左侧：图标和类型
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .blur(radius: 8)

                    Image(systemName: iconForInsightType(insight.type))
                        .font(.system(size: 22))
                        .foregroundColor(.purple)
                }

                Text(insight.type.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(width: 80)

            // 中间：洞察内容
            VStack(alignment: .leading, spacing: 6) {
                // 主要描述
                Text(insight.summary)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // 建议（最多显示第一条）
                if let firstSuggestion = insight.suggestions.first {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow.opacity(0.8))

                        Text(firstSuggestion)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                }

                // 底部操作栏
                HStack(spacing: 8) {
                    // 时间戳
                    Text(timeAgo(insight.timestamp))
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.4))

                    Spacer()

                    // 清除按钮
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            insightsAnalyzer.clearInsights()
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "trash")
                                .font(.system(size: 8))
                            Text("清除")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    // 重新分析按钮
                    Button {
                        Task {
                            await analyzeCurrentSession()
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 8))
                            Text("重新分析")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.purple.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.15))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.trailing, 40)  // 为右上角关闭按钮留空间

            Spacer()
        }
        .padding(.leading, 16)
        .padding(.vertical, 12)
    }

    // 空状态
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundColor(.purple.opacity(0.5))

            Text("还没有AI洞察")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            Text("使用Claude Code后会自动生成")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))

            // 检查是否有足够的通知数据（最近30分钟>=3条）
            if hasEnoughData {
                Button {
                    Task {
                        await analyzeCurrentSession()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                        Text("立即分析")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // 检查是否有足够数据进行分析
    private var hasEnoughData: Bool {
        let notifications = NotificationManager.shared.notificationHistory
        guard !notifications.isEmpty else { return false }

        let thirtyMinutesAgo = Date().addingTimeInterval(-1800)
        let recentNotifs = notifications.filter { $0.timestamp >= thirtyMinutesAgo }

        return recentNotifs.count >= 3
    }

    // 辅助方法
    private func iconForInsightType(_ type: InsightType) -> String {
        switch type {
        case .workPattern: return "chart.line.uptrend.xyaxis"
        case .productivity: return "speedometer"
        case .breakSuggestion: return "figure.walk"
        case .focusIssue: return "eye.trianglebadge.exclamationmark"
        case .achievement: return "star.fill"
        case .antiPattern: return "exclamationmark.triangle"
        }
    }

    private func analyzeCurrentSession() async {
        await MainActor.run {
            isAnalyzing = true
        }

        // 基于通知分析，使用规则检测+LLM增强
        _ = await insightsAnalyzer.analyzeRecentActivity()

        await MainActor.run {
            isAnalyzing = false
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)

        if minutes < 1 {
            return "刚刚"
        } else if minutes < 60 {
            return "\(minutes)分钟前"
        } else if minutes < 1440 {
            return "\(minutes / 60)小时前"
        } else {
            return "\(minutes / 1440)天前"
        }
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
