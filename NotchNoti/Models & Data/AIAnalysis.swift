//
//  AIAnalysis.swift
//  NotchNoti
//
//  AI工作分析功能 - LLM集成
//

import Foundation
import SwiftUI

// MARK: - LLM配置模型

struct LLMConfig: Codable {
    var enabled: Bool
    var baseURL: String
    var model: String
    var apiKey: String
    var temperature: Double

    // AI人设与Prompt定制
    var persona: AIPersona
    var customPrompt: String  // 用户自定义的额外提示词

    init(
        enabled: Bool = false,
        baseURL: String = "",
        model: String = "gpt-4o-mini",
        apiKey: String = "",
        temperature: Double = 0.7,
        persona: AIPersona = .neutral,
        customPrompt: String = ""
    ) {
        self.enabled = enabled
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.temperature = temperature
        self.persona = persona
        self.customPrompt = customPrompt
    }
}

// MARK: - AI人设预设

enum AIPersona: String, Codable, CaseIterable {
    case neutral = "中立助手"
    case girlfriend = "温柔女友"
    case boss = "严厉上司"
    case mentor = "资深导师"
    case friend = "老友搭档"
    case cheerleader = "活力啦啦队"
    case philosopher = "哲学思考者"
    case custom = "自定义"

    var systemPrompt: String {
        switch self {
        case .neutral:
            return "你是一个专业的开发效率顾问，用客观、简洁的语言给出建议。"

        case .girlfriend:
            return """
            你是用户温柔体贴的女友，关心TA的工作状态和身心健康。
            - 用温暖、鼓励的语气说话
            - 关注TA是否太累，适时建议休息
            - 为TA的进展感到开心和骄傲
            - 偶尔撒娇提醒TA注意身体
            - 用"亲爱的"、"宝贝"等称呼
            """

        case .boss:
            return """
            你是用户严格但公正的上司，关注工作效率和产出质量。
            - 用直接、有力的语气说话
            - 指出效率低下的问题，要求改进
            - 认可高效的工作表现
            - 强调时间管理和优先级
            - 追求结果导向
            """

        case .mentor:
            return """
            你是用户经验丰富的技术导师，传授最佳实践和工作智慧。
            - 用启发式的问题引导思考
            - 分享行业经验和模式
            - 建议学习和成长方向
            - 耐心解释背后的原理
            - 鼓励探索和实验
            """

        case .friend:
            return """
            你是用户的老朋友和工作伙伴，轻松但不失专业。
            - 用轻松、幽默的语气交流
            - 像聊天一样给建议
            - 调侃但不刻薄
            - 真诚关心工作状态
            - 偶尔开个小玩笑
            """

        case .cheerleader:
            return """
            你是用户的专属啦啦队，永远充满正能量和鼓励。
            - 用充满活力、激情的语气说话
            - 为每个小进步欢呼
            - 把困难当作挑战的机会
            - 使用emoji和感叹号
            - 相信用户一定能做到
            """

        case .philosopher:
            return """
            你是一位哲学家，从更高维度看待工作和生活的平衡。
            - 用深刻、富有哲理的语言表达
            - 引用名言和思想家的观点
            - 思考工作的本质和意义
            - 关注内心状态和长期价值
            - 提醒保持觉察和反思
            """

        case .custom:
            return ""  // 使用用户的customPrompt
        }
    }

    var icon: String {
        switch self {
        case .neutral: return "person.circle"
        case .girlfriend: return "heart.circle"
        case .boss: return "briefcase.circle"
        case .mentor: return "graduationcap.circle"
        case .friend: return "person.2.circle"
        case .cheerleader: return "flag.circle"
        case .philosopher: return "brain.head.profile"
        case .custom: return "pencil.circle"
        }
    }
}

// MARK: - AI分析管理器

@MainActor
class AIAnalysisManager: ObservableObject {
    static let shared = AIAnalysisManager()

    @Published var isAnalyzing = false
    @Published var lastAnalysis: String?
    @Published var lastError: String?

    // 项目选择
    @Published var availableProjects: [String] = []
    @Published var selectedProject: String? = nil

    private let configKey = "com.notchnoti.llmConfig"

    // 缓存机制：避免重复分析相同会话
    private var analysisCache: [String: String] = [:]  // sessionID -> analysis
    private var cacheTimestamps: [String: Date] = [:]  // sessionID -> timestamp
    private let cacheExpiration: TimeInterval = 300  // 5分钟缓存过期

    private init() {
        updateAvailableProjects()
    }

    // 加载配置
    func loadConfig() -> LLMConfig? {
        guard let data = UserDefaults.standard.data(forKey: configKey),
              let config = try? JSONDecoder().decode(LLMConfig.self, from: data),
              config.enabled,
              !config.baseURL.isEmpty,
              !config.apiKey.isEmpty else {
            return nil
        }
        return config
    }

    // 保存配置
    func saveConfig(_ config: LLMConfig) {
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: configKey)
        }
    }

    // 分析当前工作会话
    func analyzeCurrentSession() async {
        guard let session = StatisticsManager.shared.currentSession else {
            lastError = "暂无会话数据"
            return
        }

        await analyzeWorkSession(session)
    }

    // 分析工作会话
    func analyzeWorkSession(_ session: WorkSession) async {
        guard let config = loadConfig() else {
            lastError = "请先配置LLM设置"
            return
        }

        // 检查缓存
        let sessionKey = session.id.uuidString
        if let cachedAnalysis = getCachedAnalysis(for: sessionKey) {
            lastAnalysis = cachedAnalysis
            return
        }

        isAnalyzing = true
        lastError = nil

        // 生成隐私安全的统计摘要
        let summary = generatePrivacySafeSummary(session)

        // 调用LLM
        do {
            let response = try await callLLM(
                baseURL: config.baseURL,
                model: config.model,
                apiKey: config.apiKey,
                temperature: config.temperature,
                prompt: buildAnalysisPrompt(summary)
            )

            // 保存到缓存
            cacheAnalysis(response, for: sessionKey)

            lastAnalysis = response
            isAnalyzing = false
        } catch {
            lastError = "分析失败: \(error.localizedDescription)"
            isAnalyzing = false
        }
    }

    // 更新可用项目列表
    func updateAvailableProjects() {
        let notifications = NotificationManager.shared.notificationHistory
        var projects = Set<String>()

        for notification in notifications {
            if let project = notification.metadata?["project"] {
                projects.insert(project)
            }
        }

        availableProjects = Array(projects).sorted()

        // 如果当前没有选中项目，默认选中第一个
        if selectedProject == nil && !availableProjects.isEmpty {
            selectedProject = availableProjects[0]
        }
    }

    // 分析通知统计数据
    func analyzeNotifications(summary: StatsSummary) async {
        // 先更新项目列表
        updateAvailableProjects()

        guard let config = loadConfig() else {
            lastError = "请先配置LLM设置"
            return
        }

        // 生成缓存key（包含项目名）
        let projectKey = selectedProject ?? "all"
        let cacheKey = "notif_\(projectKey)_\(summary.totalCount)_\(summary.startTime.timeIntervalSince1970)"
        if let cachedAnalysis = getCachedAnalysis(for: cacheKey) {
            lastAnalysis = cachedAnalysis
            return
        }

        isAnalyzing = true
        lastError = nil

        // 生成通知统计摘要（传入选中的项目）
        let notifSummary = generateNotificationSummary(summary, projectFilter: selectedProject)

        // 检查是否有足够数据
        if notifSummary.contains("【数据不足】") {
            lastAnalysis = "数据不足：通知历史中缺少项目和文件信息，请使用 Claude Code 进行操作后重试"
            isAnalyzing = false
            return
        }

        // 调用LLM
        do {
            let response = try await callLLM(
                baseURL: config.baseURL,
                model: config.model,
                apiKey: config.apiKey,
                temperature: config.temperature,
                prompt: buildNotificationAnalysisPrompt(notifSummary)
            )

            // 保存到缓存
            cacheAnalysis(response, for: cacheKey)

            lastAnalysis = response
            isAnalyzing = false
        } catch {
            lastError = "分析失败: \(error.localizedDescription)"
            isAnalyzing = false
        }
    }

    // 获取缓存的分析结果
    private func getCachedAnalysis(for sessionKey: String) -> String? {
        guard let timestamp = cacheTimestamps[sessionKey],
              Date().timeIntervalSince(timestamp) < cacheExpiration,
              let cached = analysisCache[sessionKey] else {
            return nil
        }
        return cached
    }

    // 缓存分析结果
    private func cacheAnalysis(_ analysis: String, for sessionKey: String) {
        analysisCache[sessionKey] = analysis
        cacheTimestamps[sessionKey] = Date()

        // 清理过期缓存
        cleanExpiredCache()
    }

    // 清理过期缓存
    private func cleanExpiredCache() {
        let now = Date()
        let expiredKeys = cacheTimestamps.filter { now.timeIntervalSince($0.value) >= cacheExpiration }.map(\.key)
        expiredKeys.forEach { key in
            analysisCache.removeValue(forKey: key)
            cacheTimestamps.removeValue(forKey: key)
        }
    }

    // 生成隐私安全的摘要（不包含代码/文件名等敏感信息）
    private func generatePrivacySafeSummary(_ session: WorkSession) -> String {
        let durationMinutes = Int(session.duration / 60)
        let durationSeconds = Int(session.duration.truncatingRemainder(dividingBy: 60))

        var summary = """
        工作时长: \(durationMinutes)分\(durationSeconds)秒
        总操作: \(session.totalActivities)次
        工作模式: \(session.workMode.rawValue)
        工作强度: \(session.intensity.rawValue)
        操作节奏: \(String(format: "%.1f", session.pace))次/分钟
        """

        if !session.activityDistribution.isEmpty {
            let topActivities = session.activityDistribution
                .sorted { $0.value > $1.value }
                .prefix(3)
                .map { "\($0.key.rawValue) \($0.value)次" }
                .joined(separator: ", ")
            summary += "\n主要活动: \(topActivities)"
        }

        return summary
    }

    // 生成项目工作总结（基于通知历史和 diff 文件）
    private func generateNotificationSummary(_ summary: StatsSummary, projectFilter: String?) -> String {
        let notifications = NotificationManager.shared.notificationHistory

        // 按项目分组通知
        var projectData: [String: ProjectAnalysis] = [:]

        for notification in notifications {
            guard let metadata = notification.metadata,
                  let project = metadata["project"] else {
                continue
            }

            // 如果指定了项目过滤，只处理该项目的通知
            if let filter = projectFilter, filter != project {
                continue
            }

            if projectData[project] == nil {
                projectData[project] = ProjectAnalysis(projectName: project)
            }

            // 收集 diff 路径
            if let diffPath = metadata["diff_path"] {
                projectData[project]?.diffPaths.append(diffPath)
            }

            // 收集文件路径
            if let filePath = metadata["file_path"] {
                let fileName = (filePath as NSString).lastPathComponent
                if !fileName.isEmpty {
                    projectData[project]?.modifiedFiles.insert(fileName)
                }
            }

            // 收集操作类型
            if let toolName = metadata["tool_name"] {
                projectData[project]?.tools[toolName, default: 0] += 1
            }
        }

        // 如果没有任何项目数据
        if projectData.isEmpty {
            return """
            【数据不足】
            通知历史中缺少项目信息。

            建议：使用 Claude Code 进行操作后重新分析。
            """
        }

        // 选择要分析的项目
        let mainProject: ProjectAnalysis
        if let filter = projectFilter, let filtered = projectData[filter] {
            mainProject = filtered
        } else {
            // 如果没有指定过滤，选择最活跃的项目
            guard let active = projectData.max(by: { $0.value.diffPaths.count < $1.value.diffPaths.count })?.value else {
                return "【数据不足】无法识别主要工作项目"
            }
            mainProject = active
        }

        // 读取最近的 diff 内容
        let diffs = loadRecentDiffs(for: mainProject.projectName, limit: 5)

        var text = """
        【项目】\(mainProject.projectName)
        【修改文件】\(mainProject.modifiedFiles.count) 个
        """

        if !diffs.isEmpty {
            text += "\n\n【最近变更】"
            for (index, diff) in diffs.enumerated() {
                let preview = diff.content.prefix(200)
                text += "\n\n\(index + 1). \(diff.fileName)"
                text += "\n+\(diff.stats.added) -\(diff.stats.removed)"
                text += "\n```\n\(preview)\n```"
            }
        }

        return text
    }

    // 项目分析数据结构
    private struct ProjectAnalysis {
        let projectName: String
        var diffPaths: [String] = []
        var modifiedFiles: Set<String> = []
        var tools: [String: Int] = [:]
    }

    // Diff 数据结构
    private struct DiffInfo {
        let fileName: String
        let content: String
        let stats: DiffStats
    }

    private struct DiffStats: Codable {
        let added: Int
        let removed: Int
        let file: String
    }

    // 加载最近的 diff 文件
    private func loadRecentDiffs(for projectName: String, limit: Int) -> [DiffInfo] {
        let diffDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NotchNoti/diffs/\(projectName)")

        guard let files = try? FileManager.default.contentsOfDirectory(at: diffDir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles) else {
            return []
        }

        // 只读取 .preview.diff 文件
        let diffFiles = files
            .filter { $0.lastPathComponent.hasSuffix(".preview.diff") }
            .sorted { (lhs, rhs) in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return lhsDate > rhsDate
            }
            .prefix(limit)

        var results: [DiffInfo] = []
        for diffFile in diffFiles {
            guard let content = try? String(contentsOf: diffFile, encoding: .utf8) else { continue }

            // 读取对应的 stats 文件
            let statsFile = diffFile.deletingPathExtension().appendingPathExtension("stats.json")
            var stats = DiffStats(added: 0, removed: 0, file: "")
            if let statsData = try? Data(contentsOf: statsFile),
               let decoded = try? JSONDecoder().decode(DiffStats.self, from: statsData) {
                stats = decoded
            }

            let fileName = (stats.file as NSString).lastPathComponent
            results.append(DiffInfo(fileName: fileName, content: content, stats: stats))
        }

        return results
    }

    // 构建分析Prompt（优化版v1 - 2025-10-03）
    private func buildAnalysisPrompt(_ summary: String) -> String {
        """
        你是开发效率教练，擅长从统计数据中发现工作模式。

        【统计数据】
        \(summary)

        【任务】
        用一句话（40-60字）回答：
        1. 这次工作的核心特征是什么？
        2. 下一步最该做什么？

        【要求】
        ✓ 直接给建议，不要重复数据
        ✓ 具体可执行（如"专注完成X"，而非"提高效率"）
        ✓ 积极正面的语气
        ✗ 避免："很好"、"继续保持"等空话

        【示例】
        - 好：高强度编辑模式，建议趁热打铁完成核心功能，明天处理重构
        - 差：工作状态很好，建议继续保持

        直接输出你的分析：
        """
    }

    // 构建项目工作总结Prompt（基于代码 diff）
    private func buildNotificationAnalysisPrompt(_ summary: String) -> String {
        """
        你是代码审查助手，根据代码变更总结开发者完成了什么工作。

        \(summary)

        任务：用一句话（30-50字）总结完成的功能或修复的问题。

        要求：
        1. 根据代码变更内容推断功能，而非只看文件名
        2. 提及关键技术点或模块名
        3. 说明是新功能、bug修复、还是重构

        示例：
        - 重构统计系统，用 WorkSession 替代 SessionStats，简化数据模型
        - 修复 socket 通信问题，改用沙盒路径解决跨用户访问
        - 实现 AI 分析功能，集成 LLM 并添加 diff 读取能力

        直接输出总结：
        """
    }

    // 测试连接（用于设置页面）
    func testConnection(
        baseURL: String,
        model: String,
        apiKey: String
    ) async {
        do {
            _ = try await callLLM(
                baseURL: baseURL,
                model: model,
                apiKey: apiKey,
                temperature: 0.7,
                prompt: "Hello"
            )
            lastError = nil
            lastAnalysis = "✅ 连接成功！API配置正常。"
        } catch {
            lastError = "连接失败: \(error.localizedDescription)"
            lastAnalysis = nil
        }
    }

    // 调用LLM API
    private func callLLM(
        baseURL: String,
        model: String,
        apiKey: String,
        temperature: Double,
        prompt: String
    ) async throws -> String {
        // 构建请求URL
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw LLMError.invalidURL
        }

        // 如果baseURL不包含路径，添加标准路径
        if urlComponents.path.isEmpty || urlComponents.path == "/" {
            urlComponents.path = "/v1/chat/completions"
        }

        guard let url = urlComponents.url else {
            throw LLMError.invalidURL
        }

        // 构建请求体
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": temperature,
            "max_tokens": 200
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 30

        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw LLMError.httpError(httpResponse.statusCode)
        }

        // 解析响应
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.parseError
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 错误定义

enum LLMError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的API地址"
        case .invalidResponse:
            return "无效的响应"
        case .httpError(let code):
            return "HTTP错误: \(code)"
        case .parseError:
            return "响应解析失败"
        }
    }
}

// MARK: - AI分析视图

struct AIAnalysisView: View {
    @ObservedObject var aiManager = AIAnalysisManager.shared
    @ObservedObject var statsManager = StatisticsManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("💡 AI工作洞察")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Button(action: {
                    AISettingsWindowManager.shared.show()
                }) {
                    Image(systemName: "gearshape")
                        .font(.caption)
                        .foregroundColor(.gray)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().opacity(0.3)

            // 内容区域
            aiAnalysisContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.2))
    }

    @ViewBuilder
    private var aiAnalysisContent: some View {
        if aiManager.isAnalyzing {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("🤔 AI分析中...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = aiManager.lastError {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundColor(.orange.opacity(0.5))
                Text(error)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)

                Button("重试") {
                    Task {
                        await aiManager.analyzeCurrentSession()
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else if let analysis = aiManager.lastAnalysis {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(analysis)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Button(action: {
                            Task {
                                await aiManager.analyzeCurrentSession()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("再问一次")
                            }
                            .font(.caption2)
                        }
                        .buttonStyle(.borderless)

                        Spacer()
                    }
                }
                .padding(12)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(.purple.opacity(0.5))
                Text("点击分析获取AI工作洞察")
                    .font(.caption)
                    .foregroundColor(.gray)

                if statsManager.currentSession != nil {
                    Button("开始分析") {
                        Task {
                            await aiManager.analyzeCurrentSession()
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                // 自动分析一次
                if aiManager.lastAnalysis == nil,
                   statsManager.currentSession != nil,
                   aiManager.loadConfig() != nil {
                    Task {
                        await aiManager.analyzeCurrentSession()
                    }
                }
            }
        }
    }
}

