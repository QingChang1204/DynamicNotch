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

    // 定义工具
    private var tools: [Tool] = []
    private var resources: [Resource] = []
    private var prompts: [Prompt] = []

    private init() {
        setupTools()
        setupResources()
        setupPrompts()
    }

    /// 启动 MCP 服务器
    func start() async throws {
        guard !isRunning else {
            return
        }

        // 创建服务器实例
        server = Server(
            name: "NotchNoti",
            version: "1.0.0",
            capabilities: .init(
                prompts: .init(listChanged: false),
                resources: .init(subscribe: true, listChanged: false),
                tools: .init(listChanged: false)
            )
        )

        guard let server = server else {
            throw MCPError.serverInitFailed
        }

        // 保存副本用于闭包
        let toolsList = tools
        let resourcesList = resources
        let promptsList = prompts

        // 注册工具列表处理器
        await server.withMethodHandler(ListTools.self) { _ in
            return ListTools.Result(tools: toolsList)
        }

        // 注册工具调用处理器
        await server.withMethodHandler(CallTool.self) { @MainActor [weak self] params in
            return try await self?.handleToolCall(params) ?? CallTool.Result(content: [])
        }

        // 注册资源列表处理器
        await server.withMethodHandler(ListResources.self) { _ in
            return ListResources.Result(resources: resourcesList)
        }

        // 注册资源读取处理器
        await server.withMethodHandler(ReadResource.self) { @MainActor [weak self] params in
            return try await self?.handleResourceRead(params) ?? ReadResource.Result(contents: [])
        }

        // 注册提示列表处理器
        await server.withMethodHandler(ListPrompts.self) { _ in
            return ListPrompts.Result(prompts: promptsList)
        }

        // 使用 stdio 传输
        let transport = StdioTransport()

        // 启动服务器
        try await server.start(transport: transport)

        isRunning = true

        // 保持运行
        await server.waitUntilCompleted()
    }

    /// 停止服务器
    func stop() {
        server = nil
        isRunning = false
    }

    // MARK: - Setup Methods

    private func setupTools() {
        // Tool 1: 显示进度通知
        tools.append(Tool(
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
        ))

        // Tool 2: 显示结果通知
        tools.append(Tool(
            name: "notch_show_result",
            description: "Show an operation result notification with rich details",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "title": .object([
                        "type": .string("string"),
                        "description": .string("Notification title")
                    ]),
                    "type": .object([
                        "type": .string("string"),
                        "description": .string("Notification type: success, error, warning, info, celebration")
                    ]),
                    "message": .object([
                        "type": .string("string"),
                        "description": .string("Notification message")
                    ])
                ]),
                "required": .array([.string("title"), .string("type")])
            ])
        ))

        // Tool 3: 请求用户确认
        tools.append(Tool(
            name: "notch_ask_confirmation",
            description: "Ask user for confirmation with custom options",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "question": .object([
                        "type": .string("string"),
                        "description": .string("The question to ask the user")
                    ]),
                    "options": .object([
                        "type": .string("array"),
                        "description": .string("Array of option strings")
                    ])
                ]),
                "required": .array([.string("question"), .string("options")])
            ])
        ))

        // Tool 4: 显示可操作的结果通知（阻塞式交互）
        tools.append(Tool(
            name: "notch_show_actionable_result",
            description: "Show an actionable notification with buttons, waits for user click (max 50s timeout)",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "title": .object([
                        "type": .string("string"),
                        "description": .string("Notification title")
                    ]),
                    "message": .object([
                        "type": .string("string"),
                        "description": .string("Notification message")
                    ]),
                    "type": .object([
                        "type": .string("string"),
                        "description": .string("Notification type: success, error, warning, info")
                    ]),
                    "actions": .object([
                        "type": .string("array"),
                        "description": .string("Array of action button labels (max 3)")
                    ])
                ]),
                "required": .array([.string("title"), .string("message"), .string("actions")])
            ])
        ))
    }

    private func setupResources() {
        // Resource 1: 会话统计
        resources.append(Resource(
            name: "Current Session Statistics",
            uri: "notch://stats/session",
            description: "Real-time statistics about the current work session",
            mimeType: "application/json"
        ))

        // Resource 2: 通知历史
        resources.append(Resource(
            name: "Notification History",
            uri: "notch://notifications/history",
            description: "Recent notification history with metadata",
            mimeType: "application/json"
        ))

        // Resource 3: 待处理的交互式通知
        resources.append(Resource(
            name: "Pending Action Notifications",
            uri: "notch://actions/pending",
            description: "Interactive notifications waiting for user action",
            mimeType: "application/json"
        ))
    }

    private func setupPrompts() {
        // Prompt 1: 工作总结
        prompts.append(Prompt(
            name: "work_summary",
            description: "Generate a summary of the current work session",
            arguments: []
        ))
    }

    // MARK: - Tool Handlers

    private func handleToolCall(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        switch params.name {
        case "notch_show_progress":
            return try await handleShowProgress(params.arguments)

        case "notch_show_result":
            return try await handleShowResult(params.arguments)

        case "notch_ask_confirmation":
            return try await handleAskConfirmation(params.arguments)

        case "notch_show_actionable_result":
            return try await handleShowActionableResult(params.arguments)

        default:
            throw MCPError.unknownTool(params.name)
        }
    }

    private func handleShowProgress(_ arguments: [String: Value]?) async throws -> CallTool.Result {
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

        // 通过 Unix Socket 发送通知到 GUI 进程
        sendNotificationViaSocket(notification)

        return CallTool.Result(
            content: [.text("Progress notification displayed: \(title) at \(Int(progress * 100))%")]
        )
    }

    private func handleShowResult(_ arguments: [String: Value]?) async throws -> CallTool.Result {
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

        sendNotificationViaSocket(notification)

        return CallTool.Result(
            content: [.text("Result notification displayed: \(title)")]
        )
    }

    private func handleAskConfirmation(_ arguments: [String: Value]?) async throws -> CallTool.Result {
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

        sendNotificationViaSocket(notification)

        return CallTool.Result(
            content: [.text("Confirmation prompt displayed. User response: pending")]
        )
    }

    private func handleShowActionableResult(_ arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let args = arguments else {
            throw MCPError.missingArguments
        }

        let title = args["title"]?.stringValue ?? "Action Required"
        let message = args["message"]?.stringValue ?? ""
        let typeStr = args["type"]?.stringValue ?? "info"

        // Extract action labels
        let actionValues = args["actions"]?.arrayValue ?? []
        let actions = actionValues.compactMap { $0.stringValue }

        guard !actions.isEmpty else {
            throw MCPError.invalidArguments
        }

        // Generate unique request ID
        let requestId = UUID().uuidString

        // Store pending action
        await PendingActionStore.shared.create(
            id: requestId,
            title: title,
            message: message,
            type: typeStr,
            actions: actions
        )

        // Map notification type
        let notificationType: NotchNotification.NotificationType = switch typeStr {
        case "success": .success
        case "error": .error
        case "warning": .warning
        default: .info
        }

        // Create notification with action metadata
        let notification = NotchNotification(
            title: title,
            message: message,
            type: notificationType,
            priority: .urgent,
            actions: actions.map { actionLabel in
                NotificationAction(
                    label: actionLabel,
                    action: "mcp_action:\(requestId):\(actionLabel)",
                    style: .normal
                )
            },
            metadata: [
                "source": "mcp",
                "interactive": "true",
                "request_id": requestId,
                "actionable": "true"
            ]
        )

        // Send notification to GUI
        sendNotificationViaSocket(notification)

        // Wait up to 50 seconds for user action (blocking)
        for _ in 0..<50 {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            if let userChoice = await PendingActionStore.shared.getChoice(id: requestId) {
                // User clicked a button!
                await PendingActionStore.shared.remove(id: requestId)

                // Notify resource subscribers about update
                if let server = server {
                    let notification = Message<ResourceUpdatedNotification>(
                        method: ResourceUpdatedNotification.name,
                        params: ResourceUpdatedNotification.Parameters(uri: "notch://actions/pending")
                    )
                    try? await server.notify(notification)
                }

                return CallTool.Result(
                    content: [.text("User selected: \(userChoice)")]
                )
            }
        }

        // Timeout after 50 seconds
        await PendingActionStore.shared.remove(id: requestId)

        return CallTool.Result(
            content: [.text("timeout")],
            isError: false
        )
    }

    // MARK: - Resource Handlers

    private func handleResourceRead(_ params: ReadResource.Parameters) async throws -> ReadResource.Result {
        switch params.uri {
        case "notch://stats/session":
            return try await provideSessionStats()

        case "notch://notifications/history":
            return try await provideNotificationHistory()

        case "notch://actions/pending":
            return try await providePendingActions()

        default:
            throw MCPError.unknownResource(params.uri)
        }
    }

    private func provideSessionStats() async throws -> ReadResource.Result {
        // MCP 模式下无法访问 GUI 进程的统计数据
        // 返回提示信息
        let errorMsg = "{\"error\":\"Statistics only available in GUI process\"}"
        return ReadResource.Result(
            contents: [.text(errorMsg, uri: "notch://stats/session", mimeType: "application/json")]
        )
    }

    private func provideNotificationHistory() async throws -> ReadResource.Result {
        // MCP 模式下无法访问 GUI 进程的通知历史
        // 返回提示信息
        let errorMsg = "{\"error\":\"Notification history only available in GUI process\"}"
        return ReadResource.Result(
            contents: [.text(errorMsg, uri: "notch://notifications/history", mimeType: "application/json")]
        )
    }

    private func providePendingActions() async throws -> ReadResource.Result {
        let pending = await PendingActionStore.shared.getPending()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(pending)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

        return ReadResource.Result(
            contents: [.text(jsonString, uri: "notch://actions/pending", mimeType: "application/json")]
        )
    }

    // MARK: - Unix Socket Helper

    /// 通过 Unix Socket 发送通知到 GUI 进程
    private func sendNotificationViaSocket(_ notification: NotchNotification) {
        // 构建 JSON
        var json: [String: Any] = [
            "title": notification.title,
            "message": notification.message,
            "type": notification.type.rawValue,
            "priority": notification.priority.rawValue
        ]
        if let metadata = notification.metadata {
            json["metadata"] = metadata
        }
        if let actions = notification.actions {
            json["actions"] = actions.map { action in
                [
                    "label": action.label,
                    "action": action.action,
                    "style": action.style.rawValue
                ]
            }
        }

        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let jsonString = String(data: data, encoding: .utf8) else { return }

        // 沙盒路径（与 UnixSocketServerSimple 一致）
        let containerPath = NSHomeDirectory()
        let socketPath = "\(containerPath)/.notch.sock"
        let fullMessage = jsonString + "\n"

        // 使用 nonisolated 函数避免并发问题
        sendToUnixSocket(path: socketPath, message: fullMessage)
    }

    /// 发送消息到 Unix Socket（nonisolated 避免并发安全问题）
    private nonisolated func sendToUnixSocket(path: String, message: String) {
        // 创建 socket
        let sock = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else { return }
        defer { Darwin.close(sock) }

        // 设置 SO_NOSIGPIPE 避免 SIGPIPE 崩溃
        var on: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))

        // 构建地址结构
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        // 复制路径到 sun_path
        let pathCopy = path
        pathCopy.withCString { cString in
            withUnsafeMutableBytes(of: &addr.sun_path) { buffer in
                let len = min(strlen(cString), buffer.count - 1)
                memcpy(buffer.baseAddress, cString, len)
            }
        }

        // 连接
        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.connect(sock, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard result == 0 else { return }

        // 发送数据 (使用 MSG_NOSIGNAL 标志，但 macOS 不支持，用 SO_NOSIGPIPE 代替)
        _ = message.withCString { cString in
            Darwin.send(sock, cString, strlen(cString), 0)
        }
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

// MARK: - Value Extensions

extension Value {
    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    var numberValue: Double? {
        // Handle both int and double cases
        if case .double(let value) = self {
            return value
        }
        if case .int(let value) = self {
            return Double(value)
        }
        return nil
    }

    var arrayValue: [Value]? {
        if case .array(let value) = self {
            return value
        }
        return nil
    }
}
