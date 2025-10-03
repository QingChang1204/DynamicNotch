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

    init(
        enabled: Bool = false,
        baseURL: String = "",
        model: String = "gpt-4o-mini",
        apiKey: String = "",
        temperature: Double = 0.7
    ) {
        self.enabled = enabled
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.temperature = temperature
    }
}

// MARK: - AI分析管理器

@MainActor
class AIAnalysisManager: ObservableObject {
    static let shared = AIAnalysisManager()

    @Published var isAnalyzing = false
    @Published var lastAnalysis: String?
    @Published var lastError: String?

    private let configKey = "com.notchnoti.llmConfig"

    // 缓存机制：避免重复分析相同会话
    private var analysisCache: [String: String] = [:]  // sessionID -> analysis
    private var cacheTimestamps: [String: Date] = [:]  // sessionID -> timestamp
    private let cacheExpiration: TimeInterval = 300  // 5分钟缓存过期

    private init() {}

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

    // 分析通知统计数据
    func analyzeNotifications(summary: StatsSummary) async {
        guard let config = loadConfig() else {
            lastError = "请先配置LLM设置"
            return
        }

        // 生成缓存key（使用总数+时间戳哈希）
        let cacheKey = "notif_\(summary.totalCount)_\(summary.startTime.timeIntervalSince1970)"
        if let cachedAnalysis = getCachedAnalysis(for: cacheKey) {
            lastAnalysis = cachedAnalysis
            return
        }

        isAnalyzing = true
        lastError = nil

        // 生成通知统计摘要
        let notifSummary = generateNotificationSummary(summary)

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

    // 生成通知统计摘要（优化版v2）
    private func generateNotificationSummary(_ summary: StatsSummary) -> String {
        let elapsed = Date().timeIntervalSince(summary.startTime)
        let hours = Int(elapsed / 3600)
        let minutes = Int((elapsed.truncatingRemainder(dividingBy: 3600)) / 60)

        var text = """
        【基础数据】
        统计时长: \(hours)小时\(minutes)分钟
        通知总数: \(summary.totalCount)条
        通知频率: \(String(format: "%.1f", summary.avgPerHour))条/小时
        工作节奏: \(summary.timeTrend)
        """

        // TOP3 通知类型
        if !summary.top3Types.isEmpty {
            text += "\n\n【类型分布 TOP3】"
            for (index, item) in summary.top3Types.enumerated() {
                let percentage = Int(Double(item.count) / Double(summary.totalCount) * 100)
                text += "\n\(index + 1). \(item.type.rawValue): \(item.count)条 (\(percentage)%)"
            }
        }

        // 优先级分析
        let ps = summary.priorityStats
        let totalPriority = ps.urgent + ps.high + ps.normal + ps.low
        if totalPriority > 0 {
            text += "\n\n【优先级分布】"
            if ps.urgent > 0 {
                text += "\n紧急: \(ps.urgent)条 (\(Int(Double(ps.urgent) / Double(totalPriority) * 100))%)"
            }
            if ps.high > 0 {
                text += "\n高: \(ps.high)条 (\(Int(Double(ps.high) / Double(totalPriority) * 100))%)"
            }
            text += "\n普通: \(ps.normal)条 (\(Int(Double(ps.normal) / Double(totalPriority) * 100))%)"
            if ps.low > 0 {
                text += "\n低: \(ps.low)条 (\(Int(Double(ps.low) / Double(totalPriority) * 100))%)"
            }
        }

        // 时间段
        if let activeTime = summary.activeTime {
            text += "\n\n【时间特征】"
            text += "\n最活跃时段: \(activeTime.slot.rawValue) (\(activeTime.count)条)"
        }

        // 工具使用 TOP3
        if !summary.topTools.isEmpty {
            text += "\n\n【工具使用 TOP3】"
            for (index, item) in summary.topTools.enumerated() {
                text += "\n\(index + 1). \(item.tool): \(item.count)次"
            }
        }

        // 操作分类
        if !summary.actionSummary.isEmpty {
            text += "\n\n【操作分类】"
            for item in summary.actionSummary {
                let percentage = Int(Double(item.count) / Double(summary.totalCount) * 100)
                text += "\n\(item.action): \(item.count)次 (\(percentage)%)"
            }
        }

        return text
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

    // 构建通知分析Prompt（优化版v3 - 2025-10-03 - 专业化）
    private func buildNotificationAnalysisPrompt(_ summary: String) -> String {
        """
        你是资深开发效率教练，擅长从具体工具使用数据中识别工作模式并给出针对性建议。

        \(summary)

        【分析任务】
        基于上述数据，生成一条专业洞察（40-60字）。

        【分析要点】
        1. **工具使用模式**: 关注具体工具频率（Edit/Bash/Task/Read/Grep等）
           - Edit/Write 主导 → 代码编辑为主
           - Bash 频繁 → 命令执行/自动化测试
           - Task 出现 → Agent任务/复杂操作
           - Read/Grep 为主 → 代码审查/信息查询

        2. **操作类型识别**: 根据操作分类判断工作阶段
           - 文件修改 >60% → 代码迭代阶段
           - 命令执行 >40% → 测试/构建阶段
           - 代码查询 >50% → 学习/审查阶段

        3. **问题识别**: 根据错误率和优先级给出建议
           - Error类型 >30% → 需要排查问题
           - 紧急优先级 >20% → 处于应急模式

        【输出格式】
        [关键词]：具体洞察 + 建议

        关键词示例: 高频编辑 | 命令密集 | 混合开发 | 问题排查 | 信息检索

        【输出要求】
        ✅ 提及具体工具名称（如"Edit工具占65%"）
        ✅ 根据操作分类给出判断（如"文件修改为主，处于迭代阶段"）
        ✅ 给出可执行建议（如"建议完成后进行代码审查"）
        ✅ 专业务实，避免空话
        ❌ 禁止使用emoji表情符号
        ❌ 禁止重复数据（如"通知总数XX条"）
        ❌ 禁止空泛建议（如"继续保持"、"很好"）

        【示例输出】
        ✅ 高频编辑：Edit工具占65%，文件修改为主，当前处于代码迭代阶段，建议完成后进行代码审查
        ✅ 命令密集：Bash执行占40%且错误率低，自动化脚本运行顺畅，可考虑集成CI/CD流程
        ✅ 问题排查：Error类型占35%，Task任务频繁出现，建议优先处理高优先级错误后再开展新功能
        ✅ 混合开发：Read/Edit各占30%，代码查询与修改并重，处于学习新代码并迭代阶段
        ❌ 工作正常，通知频率稳定，建议继续保持

        直接输出你的分析（一行，40-60字）：
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
                    NotchViewModel.shared?.contentType = .normal
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

