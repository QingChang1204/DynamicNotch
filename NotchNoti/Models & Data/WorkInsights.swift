//
//  WorkInsights.swift
//  NotchNoti
//
//  AI工作洞察系统 - 基于实际通知数据分析工作习惯
//

import Foundation

// MARK: - 工作洞察数据模型

/// AI生成的工作洞察
struct WorkInsight: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let sessionId: UUID?  // 关联的session

    let type: InsightType
    let summary: String  // 简短总结（1-2句话）
    let details: String?  // 详细说明
    let suggestions: [String]  // 建议列表
    let confidence: Double  // AI的置信度 0-1

    init(type: InsightType, summary: String, details: String? = nil, suggestions: [String] = [], confidence: Double = 0.8, sessionId: UUID? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.sessionId = sessionId
        self.type = type
        self.summary = summary
        self.details = details
        self.suggestions = suggestions
        self.confidence = confidence
    }
}

/// 洞察类型
enum InsightType: String, Codable {
    case workPattern = "工作模式"
    case productivity = "效率分析"
    case breakSuggestion = "休息建议"
    case focusIssue = "专注度问题"
    case achievement = "成就总结"
    case antiPattern = "反模式警告"
}

/// 反模式（不良工作习惯）
enum AntiPattern: String {
    case frequentErrors = "错误频发"
    case longIdleTime = "长时间无操作"
    case rapidContextSwitch = "快速切换任务"
    case lateNightWork = "深夜工作"
}

// MARK: - 基于通知的洞察分析器

class WorkInsightsAnalyzer: ObservableObject {
    static let shared = WorkInsightsAnalyzer()

    @Published var recentInsights: [WorkInsight] = []
    @Published var shouldShowNotification: WorkInsight?

    private let maxInsights = 10
    private let notificationManager = NotificationManager.shared

    private init() {
        loadRecentInsights()
    }

    // MARK: - 核心分析方法（基于通知而非Session）

    /// 分析最近的工作活动（基于通知历史）
    /// 使用规则检测 + LLM增强的混合智能分析
    func analyzeRecentActivity() async -> WorkInsight? {
        let notifications = notificationManager.notificationHistory
        guard !notifications.isEmpty else {
            return nil
        }

        // 分析最近30分钟的通知
        let thirtyMinutesAgo = Date().addingTimeInterval(-1800)
        let recentNotifs = notifications.filter { $0.timestamp >= thirtyMinutesAgo }

        guard recentNotifs.count >= 3 else {
            // 通知太少，无法分析
            return nil
        }

        // 第一步：规则检测工作模式（快速、准确）
        guard var insight = detectWorkPattern(from: recentNotifs) else {
            return nil
        }

        // 第二步：如果LLM已配置，用LLM增强分析（智能、灵活）
        if let enhancedInsight = await enhanceWithLLM(insight, notifications: recentNotifs) {
            insight = enhancedInsight
        }

        await MainActor.run {
            addInsight(insight)
        }

        return insight
    }

    /// 检测长时间工作（基于通知时间间隔）
    func checkContinuousWork() async -> WorkInsight? {
        let notifications = notificationManager.notificationHistory.sorted { $0.timestamp > $1.timestamp }

        guard notifications.count >= 10 else { return nil }

        // 检查最近2小时的通知密度
        let twoHoursAgo = Date().addingTimeInterval(-7200)
        let recentNotifs = notifications.filter { $0.timestamp >= twoHoursAgo }

        // 如果2小时内有20+条通知，说明持续工作
        if recentNotifs.count >= 20 {
            // 检查是否有>15分钟的间隔（可能是休息）
            var hasBreak = false
            for i in 0..<(recentNotifs.count - 1) {
                let interval = recentNotifs[i].timestamp.timeIntervalSince(recentNotifs[i + 1].timestamp)
                if interval > 900 { // 15分钟
                    hasBreak = true
                    break
                }
            }

            if !hasBreak {
                let insight = WorkInsight(
                    type: .breakSuggestion,
                    summary: "检测到持续工作2小时无休息",
                    suggestions: ["建议休息10-15分钟", "站起来走走，远眺放松眼睛"],
                    confidence: 0.95
                )

                await MainActor.run {
                    addInsight(insight)
                    shouldShowNotification = insight
                }

                return insight
            }
        }

        return nil
    }

    /// 检测反模式
    func detectAntiPattern(from notifications: [NotchNotification]) -> AntiPattern? {
        guard notifications.count >= 5 else { return nil }

        // 检测错误频发（最近10条通知中有3+条错误）
        let last10 = Array(notifications.prefix(10))
        let errorCount = last10.filter { $0.type == .error }.count
        if errorCount >= 3 {
            return .frequentErrors
        }

        // 检测长时间无操作（最新通知距现在>30分钟）
        if let latest = notifications.first,
           Date().timeIntervalSince(latest.timestamp) > 1800 {
            return .longIdleTime
        }

        // 检测快速切换（最近1分钟内有5+条不同工具的通知）
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        let veryRecent = notifications.filter { $0.timestamp >= oneMinuteAgo }
        let toolSet = Set(veryRecent.compactMap { $0.metadata?["tool_name"] })
        if toolSet.count >= 5 {
            return .rapidContextSwitch
        }

        // 检测深夜工作（23:00-05:00）
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 23 || hour < 5 {
            return .lateNightWork
        }

        return nil
    }

    /// 分析反模式并生成洞察
    func analyzeAntiPattern(_ pattern: AntiPattern, notifications: [NotchNotification]) async -> WorkInsight? {
        let insight: WorkInsight

        switch pattern {
        case .frequentErrors:
            let errorTypes = notifications
                .filter { $0.type == .error }
                .prefix(3)
                .compactMap { $0.metadata?["tool_name"] }
                .joined(separator: ", ")

            insight = WorkInsight(
                type: .antiPattern,
                summary: "最近错误频发，主要在: \(errorTypes)",
                suggestions: [
                    "检查是否某个操作方式不对",
                    "考虑换个思路或寻求帮助",
                    "休息一下再回来可能更有效"
                ],
                confidence: 0.9
            )

        case .longIdleTime:
            insight = WorkInsight(
                type: .focusIssue,
                summary: "已经30分钟没有操作了",
                suggestions: [
                    "如果在思考是正常的",
                    "如果卡住了可以换个任务",
                    "或者直接休息一下"
                ],
                confidence: 0.7
            )

        case .rapidContextSwitch:
            insight = WorkInsight(
                type: .antiPattern,
                summary: "1分钟内频繁切换工具，可能影响专注",
                suggestions: [
                    "尝试专注在一个任务上",
                    "完成当前步骤再切换"
                ],
                confidence: 0.85
            )

        case .lateNightWork:
            let hour = Calendar.current.component(.hour, from: Date())
            insight = WorkInsight(
                type: .breakSuggestion,
                summary: "现在是凌晨\(hour)点，该休息了",
                suggestions: [
                    "长期熬夜影响健康和效率",
                    "建议明天精神好的时候再继续"
                ],
                confidence: 1.0
            )
        }

        await MainActor.run {
            addInsight(insight)
            shouldShowNotification = insight
        }

        return insight
    }

    // MARK: - 辅助方法

    /// 从通知检测工作模式
    private func detectWorkPattern(from notifications: [NotchNotification]) -> WorkInsight? {
        guard notifications.count >= 3 else { return nil }

        // 统计工具使用
        let toolCounts = notifications.compactMap { $0.metadata?["tool_name"] as? String }
            .reduce(into: [:]) { counts, tool in counts[tool, default: 0] += 1 }

        guard !toolCounts.isEmpty else {
            // 没有工具信息，使用通用描述
            return WorkInsight(
                type: .workPattern,
                summary: "最近30分钟有\(notifications.count)个操作",
                suggestions: ["继续保持工作节奏"],
                confidence: 0.6
            )
        }

        let topTool = toolCounts.max(by: { $0.value < $1.value })!.key
        let topCount = toolCounts[topTool]!
        let notifCount = notifications.count

        // 计算时间跨度
        let timeSpan = notifications.last!.timestamp.timeIntervalSince(notifications.first!.timestamp)
        let minutes = Int(timeSpan / 60)

        // 基于工具类型和频率生成更有价值的描述
        let summary: String
        let suggestions: [String]

        switch topTool.lowercased() {
        case "read", "grep", "glob":
            summary = "\(minutes)分钟内阅读/搜索了\(topCount)次，在深入研究代码"
            suggestions = ["可以边看边做笔记", "理解清楚后再开始修改"]

        case "edit", "write":
            summary = "\(minutes)分钟写了\(topCount)个文件，编写代码中"
            suggestions = ["写完记得测试", "考虑提交一个中间版本"]

        case "bash":
            summary = "\(minutes)分钟执行了\(topCount)个命令，在调试测试"
            suggestions = ["观察输出找问题", "确认修复后再继续"]

        default:
            // 多种工具混合使用
            if toolCounts.count >= 3 {
                summary = "\(minutes)分钟用了\(toolCounts.count)种工具，综合工作中"
                suggestions = ["保持当前节奏", "注意专注度"]
            } else {
                summary = "\(minutes)分钟主要在用\(topTool)（\(topCount)次）"
                suggestions = ["保持当前节奏"]
            }
        }

        return WorkInsight(
            type: .workPattern,
            summary: summary,
            suggestions: suggestions,
            confidence: 0.85
        )
    }

    /// 分析当前session（兼容旧接口）
    func analyzeCurrentSession(_ session: WorkSession) async -> WorkInsight? {
        // 转为基于通知的分析
        return await analyzeRecentActivity()
    }

    /// 分析一周工作模式（基于通知）
    func analyzeWeeklyPattern(sessions: [WorkSession]) async -> WorkInsight? {
        let notifications = notificationManager.notificationHistory
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        let weekNotifs = notifications.filter { $0.timestamp >= weekAgo }

        guard !weekNotifs.isEmpty else { return nil }

        let totalCount = weekNotifs.count
        let errorCount = weekNotifs.filter { $0.type == .error }.count
        let errorRate = Double(errorCount) / Double(totalCount) * 100

        let insight = WorkInsight(
            type: .productivity,
            summary: "本周共\(totalCount)个操作，错误率\(String(format: "%.1f", errorRate))%",
            suggestions: errorRate > 15 ? ["错误率偏高，注意休息和方法"] : ["保持当前工作质量"],
            confidence: 0.9
        )

        await MainActor.run {
            addInsight(insight)
        }

        return insight
    }

    // MARK: - 存储管理

    private func addInsight(_ insight: WorkInsight) {
        recentInsights.insert(insight, at: 0)
        if recentInsights.count > maxInsights {
            recentInsights = Array(recentInsights.prefix(maxInsights))
        }
        saveInsights()
    }

    private func loadRecentInsights() {
        guard let data = UserDefaults.standard.data(forKey: "WorkInsights"),
              let insights = try? JSONDecoder().decode([WorkInsight].self, from: data) else {
            return
        }
        self.recentInsights = insights
    }

    private func saveInsights() {
        guard let data = try? JSONEncoder().encode(recentInsights) else { return }
        UserDefaults.standard.set(data, forKey: "WorkInsights")
    }

    // MARK: - LLM增强分析

    /// 用LLM增强规则检测的洞察
    /// - Parameters:
    ///   - baseInsight: 规则检测生成的基础洞察
    ///   - notifications: 相关的通知列表
    /// - Returns: LLM增强后的洞察，如果LLM未配置或调用失败则返回nil
    private func enhanceWithLLM(_ baseInsight: WorkInsight, notifications: [NotchNotification]) async -> WorkInsight? {
        // 检查LLM是否已配置
        guard let config = await AIAnalysisManager.shared.loadConfig() else {
            return nil
        }

        // 构建给LLM的上下文
        let toolUsage = notifications
            .compactMap { $0.metadata?["tool_name"] as? String }
            .reduce(into: [:]) { counts, tool in counts[tool, default: 0] += 1 }
            .map { "\($0.key): \($0.value)次" }
            .joined(separator: ", ")

        let timeSpan = Int(notifications.last!.timestamp.timeIntervalSince(notifications.first!.timestamp) / 60)

        // 构建系统Prompt（人设）
        let systemPrompt: String
        if config.persona == .custom && !config.customPrompt.isEmpty {
            systemPrompt = config.customPrompt
        } else {
            systemPrompt = config.persona.systemPrompt
        }

        // 用户Prompt：规则检测结果 + 分析要求
        let userPrompt = """
        请基于以下工作模式分析，用你的风格给出建议。

        **规则检测结果**：
        - 模式类型：\(baseInsight.type.rawValue)
        - 初步分析：\(baseInsight.summary)
        - 时间跨度：\(timeSpan)分钟
        - 工具使用：\(toolUsage)
        - 操作总数：\(notifications.count)次

        **原始建议**：
        \(baseInsight.suggestions.map { "• " + $0 }.joined(separator: "\n"))

        请返回JSON格式：
        {
          "summary": "简短精炼的分析（1句话，包含具体数据，用你的语气）",
          "suggestions": ["建议1（用你的风格表达）", "建议2", "建议3"],
          "confidence": 0.0-1.0
        }

        要求：
        1. summary要保留原有的数据信息（时间、次数），但用你的语气
        2. suggestions要符合你的角色人设
        3. 不要超过3条建议
        4. 保持你的角色特征
        """

        // 调用LLM API
        guard let url = URL(string: "\(config.baseURL)/v1/chat/completions") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // 构建消息数组：system + user
        var messages: [[String: String]] = []

        // 添加系统Prompt（人设）
        if !systemPrompt.isEmpty {
            messages.append(["role": "system", "content": systemPrompt])
        }

        // 添加用户Prompt（分析要求）
        messages.append(["role": "user", "content": userPrompt])

        let requestBody: [String: Any] = [
            "model": config.model,
            "messages": messages,
            "temperature": config.temperature,
            "max_tokens": 300
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            // 解析响应
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {

                // 从LLM返回的JSON中提取信息
                if let contentData = content.data(using: .utf8),
                   let llmResult = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any],
                   let summary = llmResult["summary"] as? String,
                   let suggestions = llmResult["suggestions"] as? [String] {

                    let confidence = llmResult["confidence"] as? Double ?? baseInsight.confidence

                    // 返回LLM增强的洞察
                    return WorkInsight(
                        type: baseInsight.type,
                        summary: summary,
                        details: "LLM增强分析 | 基于\(notifications.count)个操作",
                        suggestions: suggestions,
                        confidence: confidence,
                        sessionId: baseInsight.sessionId
                    )
                }
            }
        } catch {
            print("[WorkInsights] LLM增强失败: \(error.localizedDescription)")
        }

        return nil
    }

    // MARK: - 清除洞察

    /// 清除所有洞察
    func clearInsights() {
        recentInsights.removeAll()
        saveInsights()
    }

    /// 删除特定洞察
    func removeInsight(_ insight: WorkInsight) {
        recentInsights.removeAll { $0.id == insight.id }
        saveInsights()
    }
}
