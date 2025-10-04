//
//  SessionSummary.swift
//  NotchNoti
//
//  Session总结数据模型和管理器
//

import Foundation

// MARK: - Session Summary Model

/// Session总结数据模型
struct SessionSummary: Codable, Identifiable {
    let id: UUID
    let sessionId: UUID  // 关联的WorkSession ID
    let projectName: String
    let startTime: Date
    let endTime: Date
    let createdAt: Date  // 总结生成时间

    // 任务概述
    var taskDescription: String  // 本次session做了什么
    var completedTasks: [String]  // 完成的任务列表
    var pendingTasks: [String]  // 待办事项

    // 文件修改
    var modifiedFiles: [FileModification]

    // 关键决策和问题
    var keyDecisions: [String]  // 重要的技术决策
    var issuesEncountered: [Issue]  // 遇到的问题和解决方案

    // 统计数据（从WorkSession派生）
    var statistics: SessionStatistics

    // AI洞察（可选）
    var aiInsight: WorkInsight?

    init(session: WorkSession, taskDescription: String = "", aiInsight: WorkInsight? = nil) {
        self.id = UUID()
        self.sessionId = session.id
        self.projectName = session.projectName
        self.startTime = session.startTime
        self.endTime = session.endTime ?? Date()
        self.createdAt = Date()

        self.taskDescription = taskDescription
        self.completedTasks = []
        self.pendingTasks = []
        self.modifiedFiles = []
        self.keyDecisions = []
        self.issuesEncountered = []

        self.statistics = SessionStatistics(from: session)
        self.aiInsight = aiInsight
    }

    // 生成Markdown格式
    func toMarkdown() -> String {
        var md = ""

        // Header
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        md += "# Session Summary - \(dateFormatter.string(from: startTime))\n\n"

        // Project Info
        md += "**Project**: \(projectName)\n"
        md += "**Duration**: \(formatDuration(statistics.duration))\n"
        md += "**Work Mode**: \(statistics.workMode)\n"
        md += "**Intensity**: \(statistics.intensity)\n\n"

        md += "---\n\n"

        // AI洞察（如果有）
        if let insight = aiInsight {
            md += "## 🤖 AI 工作洞察\n\n"
            md += "\(insight.summary)\n\n"

            if !insight.suggestions.isEmpty {
                md += "**建议**:\n"
                for (index, suggestion) in insight.suggestions.enumerated() {
                    md += "\(index + 1). \(suggestion)\n"
                }
                md += "\n"
            }

            md += "---\n\n"
        }

        // Task Overview
        md += "## 📋 任务概述\n\n"
        md += taskDescription.isEmpty ? "_未提供描述_\n\n" : "\(taskDescription)\n\n"

        // Completed Tasks
        if !completedTasks.isEmpty {
            md += "## ✅ 完成内容\n\n"
            for task in completedTasks {
                md += "- ✅ \(task)\n"
            }
            md += "\n"
        }

        // Modified Files
        if !modifiedFiles.isEmpty {
            md += "## 📁 文件修改 (\(modifiedFiles.count) files)\n\n"
            for file in modifiedFiles {
                md += "- `\(file.path)` - \(file.modificationType.rawValue)\n"
                if let description = file.description {
                    md += "  > \(description)\n"
                }
            }
            md += "\n"
        }

        // Key Decisions
        if !keyDecisions.isEmpty {
            md += "## 💡 关键决策\n\n"
            for (index, decision) in keyDecisions.enumerated() {
                md += "\(index + 1). \(decision)\n"
            }
            md += "\n"
        }

        // Issues & Solutions
        if !issuesEncountered.isEmpty {
            md += "## 🐛 问题与解决\n\n"
            for issue in issuesEncountered {
                md += "### \(issue.title)\n\n"
                md += "**问题**: \(issue.description)\n\n"
                if let solution = issue.solution {
                    md += "**解决**: \(solution)\n\n"
                } else {
                    md += "**状态**: ⚠️ 未解决\n\n"
                }
            }
        }

        // Statistics
        md += "## 📊 统计数据\n\n"
        md += "- **总操作数**: \(statistics.totalActivities)\n"
        md += "- **工作节奏**: \(String(format: "%.1f", statistics.pace)) ops/min\n"
        md += "- **主要操作**: \(statistics.primaryActivity)\n\n"

        if !statistics.toolUsage.isEmpty {
            md += "**工具使用**:\n"
            let sortedTools = statistics.toolUsage.sorted { $0.value > $1.value }
            for (tool, count) in sortedTools.prefix(5) {
                md += "- \(tool): \(count)次\n"
            }
            md += "\n"
        }

        // Next Steps
        if !pendingTasks.isEmpty {
            md += "## ⏭️ 下一步\n\n"
            for task in pendingTasks {
                md += "- [ ] \(task)\n"
            }
            md += "\n"
        }

        // Footer
        md += "---\n\n"
        md += "_Generated by NotchNoti at \(dateFormatter.string(from: createdAt))_\n"

        return md
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Models

/// 文件修改记录
struct FileModification: Codable {
    let path: String
    let modificationType: ModificationType
    let description: String?  // 可选的修改说明

    enum ModificationType: String, Codable {
        case created = "新建"
        case modified = "修改"
        case deleted = "删除"
        case renamed = "重命名"
    }
}

/// 问题记录
struct Issue: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String
    let solution: String?
    let timestamp: Date

    init(title: String, description: String, solution: String? = nil) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.solution = solution
        self.timestamp = Date()
    }
}

/// Session统计数据（从WorkSession提取）
struct SessionStatistics: Codable {
    let duration: TimeInterval
    let totalActivities: Int
    let pace: Double
    let intensity: String
    let workMode: String
    let primaryActivity: String
    let toolUsage: [String: Int]  // 工具名 -> 使用次数

    init(from session: WorkSession) {
        self.duration = session.duration
        self.totalActivities = session.totalActivities
        self.pace = session.pace
        self.intensity = session.intensity.rawValue
        self.workMode = session.workMode.rawValue
        self.primaryActivity = session.primaryActivity.rawValue

        // 统计工具使用
        var usage: [String: Int] = [:]
        for activity in session.activities {
            let toolName = activity.type.rawValue
            usage[toolName, default: 0] += 1
        }
        self.toolUsage = usage
    }
}

// MARK: - Summary Manager

/// Session总结管理器
class SessionSummaryManager: ObservableObject {
    static let shared = SessionSummaryManager()

    @Published var recentSummaries: [SessionSummary] = []

    private let storageKey = "SessionSummaries"
    private let maxRecentCount = 5  // 最近5条快捷访问

    private init() {
        loadRecentSummaries()
    }

    // MARK: - Public API

    /// 创建新的session总结
    func createSummary(
        from session: WorkSession,
        taskDescription: String,
        completedTasks: [String] = [],
        pendingTasks: [String] = [],
        modifiedFiles: [FileModification] = [],
        keyDecisions: [String] = [],
        issues: [Issue] = []
    ) -> SessionSummary {
        var summary = SessionSummary(session: session, taskDescription: taskDescription)
        summary.completedTasks = completedTasks
        summary.pendingTasks = pendingTasks
        summary.modifiedFiles = modifiedFiles
        summary.keyDecisions = keyDecisions
        summary.issuesEncountered = issues

        // 添加到最近列表
        addToRecent(summary)

        return summary
    }

    /// 保存总结到文件
    func saveSummary(_ summary: SessionSummary, to url: URL) throws {
        let markdown = summary.toMarkdown()
        try markdown.write(to: url, atomically: true, encoding: .utf8)
    }

    /// 智能检测项目目录并生成默认保存路径
    func suggestSavePath(for summary: SessionSummary, projectPath: String?) -> URL? {
        guard let projectPath = projectPath else { return nil }

        let projectURL = URL(fileURLWithPath: projectPath)
        let docsDir = projectURL.appendingPathComponent("docs/sessions")

        // 生成文件名: session-2025-10-04-1330.md
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmm"
        let timestamp = dateFormatter.string(from: summary.startTime)
        let filename = "session-\(timestamp).md"

        return docsDir.appendingPathComponent(filename)
    }

    /// 确保目录存在
    func ensureDirectoryExists(at url: URL) throws {
        let directory = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Recent Summaries

    private func addToRecent(_ summary: SessionSummary) {
        DispatchQueue.main.async {
            self.recentSummaries.insert(summary, at: 0)
            if self.recentSummaries.count > self.maxRecentCount {
                self.recentSummaries = Array(self.recentSummaries.prefix(self.maxRecentCount))
            }
            self.saveRecentSummaries()
        }
    }

    private func loadRecentSummaries() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let summaries = try? JSONDecoder().decode([SessionSummary].self, from: data) else {
            return
        }
        self.recentSummaries = summaries
    }

    private func saveRecentSummaries() {
        guard let data = try? JSONEncoder().encode(recentSummaries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    /// 获取总结的可读标题
    func getSummaryTitle(_ summary: SessionSummary) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd HH:mm"
        let time = dateFormatter.string(from: summary.startTime)
        return "\(summary.projectName) - \(time)"
    }
}
