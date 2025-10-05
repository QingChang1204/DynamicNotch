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
        let notifications = await notificationManager.getHistory(page: 0, pageSize: 100)
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
        let notifications = await notificationManager.getHistory(page: 0, pageSize: 100)

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

    /// 从通知检测工作模式（深度分析版）
    private func detectWorkPattern(from notifications: [NotchNotification]) -> WorkInsight? {
        guard notifications.count >= 3 else { return nil }

        // 提取关键信息
        let toolSequence = notifications.compactMap { $0.metadata?["tool_name"] as? String }
        let toolCounts = toolSequence.reduce(into: [:]) { counts, tool in counts[tool, default: 0] += 1 }

        // 提取文件路径（如果有）
        let files = notifications.compactMap { notif -> String? in
            guard let path = notif.metadata?["file_path"] as? String else { return nil }
            return URL(fileURLWithPath: path).lastPathComponent
        }
        let uniqueFiles = Set(files)

        // 统计成功/失败
        let successCount = notifications.filter { $0.type == .success || $0.type == .celebration }.count
        let errorCount = notifications.filter { $0.type == .error }.count

        guard !toolCounts.isEmpty else {
            return WorkInsight(
                type: .workPattern,
                summary: "最近30分钟有\(notifications.count)个操作",
                suggestions: ["继续保持工作节奏"],
                confidence: 0.6
            )
        }

        // 计算时间跨度
        let timeSpan = notifications.last!.timestamp.timeIntervalSince(notifications.first!.timestamp)
        let minutes = Int(timeSpan / 60)

        // 🔍 深度分析：识别工作流模式
        let workflow = identifyWorkflow(toolSequence: toolSequence)

        // 构建深度总结
        let summary: String
        let suggestions: [String]

        switch workflow {
        case .research:
            let searchTools = ["Read", "Grep", "Glob"].filter { toolCounts[$0] != nil }
            let totalSearches = searchTools.reduce(0) { $0 + (toolCounts[$1] ?? 0) }

            if !uniqueFiles.isEmpty {
                summary = "\(minutes)分钟研究了\(uniqueFiles.count)个文件，执行\(totalSearches)次搜索/阅读"
                suggestions = [
                    "📋 涉及文件：\(uniqueFiles.prefix(3).joined(separator: ", "))",
                    "💡 研究清楚后可以开始修改了",
                    uniqueFiles.count > 5 ? "⚠️ 涉及文件较多，建议逐个攻破" : "✅ 范围明确，继续深入"
                ]
            } else {
                summary = "\(minutes)分钟内搜索/阅读了\(totalSearches)次，在定位问题"
                suggestions = ["理解代码结构是关键", "找到关键逻辑后再动手"]
            }

        case .coding:
            let editCount = (toolCounts["Edit"] ?? 0) + (toolCounts["Write"] ?? 0)
            let hasTests = toolCounts["Bash"] != nil || notifications.contains { $0.message.lowercased().contains("test") }

            if !uniqueFiles.isEmpty {
                summary = "\(minutes)分钟修改了\(uniqueFiles.count)个文件，共\(editCount)次编辑"

                if errorCount > 0 && successCount > 0 {
                    suggestions = [
                        "📝 主要文件：\(uniqueFiles.prefix(2).joined(separator: ", "))",
                        "✅ 经过\(errorCount)次失败后成功了",
                        hasTests ? "👍 记得继续测试验证" : "⚠️ 建议运行测试验证修改"
                    ]
                } else if errorCount > 0 {
                    suggestions = [
                        "⚠️ 遇到了\(errorCount)个错误，可能需要调整思路",
                        "💡 考虑回退到上一个可用版本",
                        "🔍 仔细检查：\(uniqueFiles.first ?? "当前文件")"
                    ]
                } else {
                    suggestions = [
                        "✍️ 编码进展顺利，保持节奏",
                        hasTests ? "✅ 已有测试覆盖" : "📋 接下来记得测试",
                        uniqueFiles.count > 3 ? "🎯 改动较大，考虑分批提交" : "继续保持"
                    ]
                }
            } else {
                summary = "\(minutes)分钟编写了\(editCount)个文件"
                suggestions = ["写完记得测试", "考虑提交一个中间版本"]
            }

        case .debugging:
            let bashCount = toolCounts["Bash"] ?? 0
            let readCount = toolCounts["Read"] ?? 0

            summary = "\(minutes)分钟调试：\(bashCount)次命令执行 + \(readCount)次代码检查"

            if errorCount > successCount {
                suggestions = [
                    "🐛 错误率\(errorCount)/\(notifications.count)，建议换个角度",
                    "💡 可能需要加日志输出定位问题",
                    "🤔 或者休息一下再继续"
                ]
            } else if successCount > 0 {
                suggestions = [
                    "✅ 找到问题并修复了！",
                    "🎯 现在可以进入下一个任务",
                    "📝 记得提交修复的代码"
                ]
            } else {
                suggestions = [
                    "🔍 还在定位问题中",
                    "观察输出找线索",
                    "必要时添加更多调试信息"
                ]
            }

        case .integrated:
            summary = "\(minutes)分钟综合工作：研究+编码+测试（\(notifications.count)个操作）"

            let phaseDesc = [
                toolCounts["Read"] != nil || toolCounts["Grep"] != nil ? "✅ 研究" : nil,
                toolCounts["Edit"] != nil || toolCounts["Write"] != nil ? "✅ 编码" : nil,
                toolCounts["Bash"] != nil ? "✅ 测试" : nil
            ].compactMap { $0 }

            if errorCount > 0 && successCount > 0 {
                suggestions = [
                    "🎯 完成阶段：\(phaseDesc.joined(separator: " → "))",
                    "💪 经历\(errorCount)次失败但最终成功了",
                    "📋 建议现在整理提交代码"
                ]
            } else if successCount > 0 {
                suggestions = [
                    "🎯 完成：\(phaseDesc.joined(separator: " → "))",
                    "✅ 进展顺利，继续保持",
                    uniqueFiles.count > 0 ? "涉及\(uniqueFiles.count)个文件" : "标准工作流"
                ]
            } else {
                suggestions = [
                    "正在进行：\(phaseDesc.joined(separator: " → "))",
                    "保持当前节奏",
                    toolCounts["Bash"] == nil ? "💡 记得测试验证" : "继续观察输出"
                ]
            }
        }

        return WorkInsight(
            type: .workPattern,
            summary: summary,
            suggestions: suggestions,
            confidence: 0.90
        )
    }

    /// 识别工作流类型
    private func identifyWorkflow(toolSequence: [String]) -> WorkflowType {
        let toolSet = Set(toolSequence)

        // 研究阶段：主要是 Read/Grep/Glob
        let researchTools = Set(["Read", "Grep", "Glob"])
        if toolSet.isSubset(of: researchTools) || toolSet.intersection(researchTools).count >= toolSet.count * 2 / 3 {
            return .research
        }

        // 编码阶段：主要是 Edit/Write
        let codingTools = Set(["Edit", "Write"])
        if toolSet.isSubset(of: codingTools) || codingTools.intersection(toolSet).count >= 2 {
            return .coding
        }

        // 调试阶段：Bash + Read 混合
        if toolSet.contains("Bash") && (toolSet.contains("Read") || toolSet.contains("Grep")) {
            return .debugging
        }

        // 综合工作：多种工具混合
        if toolSet.count >= 3 {
            return .integrated
        }

        return .coding  // 默认
    }

    /// 工作流类型
    private enum WorkflowType {
        case research    // 研究代码
        case coding      // 编写代码
        case debugging   // 调试测试
        case integrated  // 综合工作
    }

    /// 分析当前session（兼容旧接口）
    func analyzeCurrentSession(_ session: WorkSession) async -> WorkInsight? {
        // 转为基于通知的分析
        return await analyzeRecentActivity()
    }

    /// 分析一周工作模式（基于通知）
    func analyzeWeeklyPattern(sessions: [WorkSession]) async -> WorkInsight? {
        let allNotifications = await notificationManager.getHistory(page: 0, pageSize: 1000)
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        let weekNotifs = allNotifications.filter { $0.timestamp >= weekAgo }

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
