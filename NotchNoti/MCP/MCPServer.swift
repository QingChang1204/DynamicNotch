//
//  MCPServer.swift
//  NotchNoti
//
//  MCP (Model Context Protocol) 服务器主类
//  提供与 Claude Code 的双向交互能力
//

import Foundation
import MCP

/// NotchNoti MCP 服务器
/// 通过 stdio 传输与 Claude Code 通信
@MainActor
class NotchMCPServer {
    static let shared = NotchMCPServer()

    private var server: Server?
    private var isRunning = false

    private init() {}

    /// 启动 MCP 服务器
    func start() async throws {
        guard !isRunning else {
            print("[MCP] Server already running")
            return
        }

        print("[MCP] Starting NotchNoti MCP Server...")

        // 创建服务器实例
        server = Server(
            name: "NotchNoti",
            version: "1.0.0",
            capabilities: .init(
                tools: .init(listChanged: false),
                resources: .init(listChanged: false, subscribe: false),
                prompts: .init(listChanged: false)
            )
        )

        guard let server = server else {
            throw MCPError.serverInitFailed
        }

        // 注册工具
        await registerTools(server: server)

        // 注册资源
        await registerResources(server: server)

        // 注册提示
        await registerPrompts(server: server)

        // 使用 stdio 传输
        let transport = StdioTransport()

        // 启动服务器
        try await server.start(transport: transport)

        isRunning = true
        print("[MCP] Server started successfully")

        // 保持运行
        await server.waitUntilCompleted()
    }

    /// 停止服务器
    func stop() {
        server = nil
        isRunning = false
        print("[MCP] Server stopped")
    }

    // MARK: - Tool Registration

    private func registerTools(server: Server) async {
        print("[MCP] Registering tools...")

        // Tool 1: 显示进度通知
        let progressTool = Tool(
            name: "notch_show_progress",
            description: "Display a progress notification in the MacBook notch area",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "title": .object([
                        "type": .string("string"),
                        "description": .string("Progress title")
                    ]),
                    "progress": .object([
                        "type": .string("number"),
                        "description": .string("Progress percentage (0.0 to 1.0)")
                    ]),
                    "cancellable": .object([
                        "type": .string("boolean"),
                        "description": .string("Whether the operation can be cancelled")
                    ])
                ]),
                "required": .array([.string("title"), .string("progress")])
            ])
        )

        // Tool 2: 显示结果通知
        let resultTool = Tool(
            name: "notch_show_result",
            description: "Show an operation result notification with rich details",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "title": .string("string"),
                    "type": .string("string"),
                    "message": .string("string"),
                    "stats": .string("object")
                ]),
                "required": .array([.string("title"), .string("type")])
            ])
        )

        // Tool 3: 请求用户确认
        let confirmTool = Tool(
            name: "notch_ask_confirmation",
            description: "Ask user for confirmation with custom options",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "question": .string("string"),
                    "options": .string("array")
                ]),
                "required": .array([.string("question"), .string("options")])
            ])
        )

        await server.withTools([progressTool, resultTool, confirmTool])

        // 注册工具处理器
        await server.withMethodHandler(CallTool.self) { [weak self] params in
            return try await self?.handleToolCall(params) ?? CallTool.Result(content: [])
        }

        print("[MCP] Registered \(3) tools")
    }

    // MARK: - Resource Registration

    private func registerResources(server: Server) async {
        print("[MCP] Registering resources...")

        // Resource 1: 会话统计
        let sessionStatsResource = Resource(
            uri: "notch://stats/session",
            name: "Current Session Statistics",
            description: "Real-time statistics about the current work session",
            mimeType: "application/json"
        )

        // Resource 2: 通知历史
        let historyResource = Resource(
            uri: "notch://notifications/history",
            name: "Notification History",
            description: "Recent notification history with metadata",
            mimeType: "application/json"
        )

        await server.withResources([sessionStatsResource, historyResource])

        // 注册资源处理器
        await server.withMethodHandler(ReadResource.self) { [weak self] params in
            return try await self?.handleResourceRead(params) ?? ReadResource.Result(contents: [])
        }

        print("[MCP] Registered \(2) resources")
    }

    // MARK: - Prompt Registration

    private func registerPrompts(server: Server) async {
        print("[MCP] Registering prompts...")

        // Prompt 1: 工作总结
        let summaryPrompt = Prompt(
            name: "work_summary",
            description: "Generate a summary of the current work session",
            arguments: []
        )

        await server.withPrompts([summaryPrompt])

        print("[MCP] Registered \(1) prompt")
    }

    // MARK: - Tool Handlers

    private func handleToolCall(_ params: CallTool.Params) async throws -> CallTool.Result {
        print("[MCP] Tool called: \(params.name)")

        switch params.name {
        case "notch_show_progress":
            return try await handleShowProgress(params.arguments)

        case "notch_show_result":
            return try await handleShowResult(params.arguments)

        case "notch_ask_confirmation":
            return try await handleAskConfirmation(params.arguments)

        default:
            throw MCPError.unknownTool(params.name)
        }
    }

    private func handleShowProgress(_ arguments: [String: JSONValue]?) async throws -> CallTool.Result {
        guard let args = arguments else {
            throw MCPError.missingArguments
        }

        let title = args["title"]?.stringValue ?? "Progress"
        let progress = args["progress"]?.numberValue ?? 0.0
        let cancellable = args["cancellable"]?.boolValue ?? false

        // 创建进度通知
        let notification = NotchNotification(
            title: title,
            message: "Progress: \(Int(progress * 100))%",
            type: .progress,
            priority: .normal,
            metadata: [
                "progress": "\(progress)",
                "cancellable": "\(cancellable)",
                "source": "mcp"
            ]
        )

        // 显示通知
        NotificationManager.shared.addNotification(notification)

        return CallTool.Result(
            content: [.text("Progress notification displayed: \(title) at \(Int(progress * 100))%")]
        )
    }

    private func handleShowResult(_ arguments: [String: JSONValue]?) async throws -> CallTool.Result {
        guard let args = arguments else {
            throw MCPError.missingArguments
        }

        let title = args["title"]?.stringValue ?? "Result"
        let typeStr = args["type"]?.stringValue ?? "info"
        let message = args["message"]?.stringValue ?? ""

        // 映射类型
        let notificationType: NotchNotification.NotificationType = switch typeStr {
        case "success": .success
        case "error": .error
        case "warning": .warning
        case "celebration": .celebration
        default: .info
        }

        let notification = NotchNotification(
            title: title,
            message: message,
            type: notificationType,
            priority: .high,
            metadata: ["source": "mcp"]
        )

        NotificationManager.shared.addNotification(notification)

        return CallTool.Result(
            content: [.text("Result notification displayed: \(title)")]
        )
    }

    private func handleAskConfirmation(_ arguments: [String: JSONValue]?) async throws -> CallTool.Result {
        guard let args = arguments else {
            throw MCPError.missingArguments
        }

        let question = args["question"]?.stringValue ?? "Confirm?"

        // TODO: 实现真正的用户交互
        // 目前先返回模拟结果

        let notification = NotchNotification(
            title: "Confirmation Required",
            message: question,
            type: .reminder,
            priority: .urgent,
            metadata: ["source": "mcp", "interactive": "true"]
        )

        NotificationManager.shared.addNotification(notification)

        return CallTool.Result(
            content: [.text("Confirmation prompt displayed. User response: pending")]
        )
    }

    // MARK: - Resource Handlers

    private func handleResourceRead(_ params: ReadResource.Params) async throws -> ReadResource.Result {
        print("[MCP] Resource read: \(params.uri)")

        switch params.uri {
        case "notch://stats/session":
            return try await provideSessionStats()

        case "notch://notifications/history":
            return try await provideNotificationHistory()

        default:
            throw MCPError.unknownResource(params.uri)
        }
    }

    private func provideSessionStats() async throws -> ReadResource.Result {
        let manager = StatisticsManager.shared

        guard let currentSession = manager.currentSession else {
            return ReadResource.Result(
                contents: [.text("No active session")]
            )
        }

        let stats: [String: Any] = [
            "project": currentSession.projectName,
            "duration": currentSession.duration,
            "activities": currentSession.totalActivities,
            "pace": currentSession.pace,
            "intensity": currentSession.intensity.rawValue,
            "work_mode": currentSession.workMode.rawValue
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: stats, options: .prettyPrinted)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        return ReadResource.Result(
            contents: [.text(jsonString)]
        )
    }

    private func provideNotificationHistory() async throws -> ReadResource.Result {
        let history = NotificationManager.shared.notificationHistory.prefix(10)

        let historyData = history.map { notification in
            [
                "title": notification.title,
                "message": notification.message,
                "type": notification.type.rawValue,
                "timestamp": ISO8601DateFormatter().string(from: notification.timestamp)
            ]
        }

        let jsonData = try JSONSerialization.data(withJSONObject: historyData, options: .prettyPrinted)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

        return ReadResource.Result(
            contents: [.text(jsonString)]
        )
    }
}

// MARK: - Error Types

enum MCPError: Error {
    case serverInitFailed
    case unknownTool(String)
    case unknownResource(String)
    case missingArguments
    case invalidArguments
}

// MARK: - JSONValue Extensions

extension JSONValue {
    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    var numberValue: Double? {
        if case .number(let value) = self {
            return value
        }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }
}
