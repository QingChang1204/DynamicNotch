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

