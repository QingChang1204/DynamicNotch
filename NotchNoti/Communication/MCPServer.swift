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
/// 注意：不使用 @MainActor 避免 50 秒轮询阻塞后续调用
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
        // Tool 1: 交互式通知 - 显示按钮并等待用户选择
        tools.append(Tool(
            name: "notch_show_actionable_result",
            description: """
            🎯 异步获取用户反馈 - 当用户可能不在终端时使用

            **使用场景：**
            1. 📋 **规划确认** - 你有多个实现方案，需要用户选择最合适的
            2. ⚠️ **重要操作确认** - 删除文件、修改配置等危险操作前
            3. 🔀 **分支决策** - 遇到问题有多种解决方案，让用户决定

            **为什么用这个而不是直接问？**
            - 用户可能切换到浏览器/其他应用，看不到终端
            - 刘海通知非侵入式，用户可以在任何时候看到并响应
            - 你的问题会被归档，用户可以稍后查看历史

            **何时使用：**
            - ✅ 当你需要规划并等待用户确认方案时
            - ✅ 当操作有风险，需要明确确认时
            - ✅ 当有多个选项，用户需要做决策时
            - ❌ 不要用于简单的进度通知（用 Hook 就够了）

            **返回值：** 用户点击的按钮文本，或 "timeout"（50秒超时）
            """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "title": .object([
                        "type": .string("string"),
                        "description": .string("Short notification title (e.g., 'Confirm Action', 'Choose Option')")
                    ]),
                    "message": .object([
                        "type": .string("string"),
                        "description": .string("Brief message explaining what user needs to choose (1-2 sentences)")
                    ]),
                    "type": .object([
                        "type": .string("string"),
                        "description": .string("Visual style: 'success', 'error', 'warning', or 'info'")
                    ]),
                    "actions": .object([
                        "type": .string("array"),
                        "description": .string("Array of button labels (max 3). Use clear, actionable text like '确认', '取消', '查看详情'")
                    ])
                ]),
                "required": .array([.string("title"), .string("message"), .string("actions")])
            ])
        ))

        // Tool 2: Session总结 - 生成并显示工作总结
        tools.append(Tool(
            name: "notch_show_summary",
            description: """
            📝 自动归档工作总结 - 完成代码后主动发送，避免信息丢失

            **核心价值：**
            终端输出会被刷掉、聊天记录难查找，但刘海总结会被持久化保存！

            **何时使用（主动触发）：**
            1. ✅ **完成重要功能** - 写了3个以上文件，实现了完整功能
            2. ✅ **修复复杂bug** - 涉及多个文件的问题定位和修复
            3. ✅ **重构代码** - 改动较大，需要记录架构决策
            4. ✅ **用户明确要求** - 用户说"总结一下"、"归档"

            **不要等用户问才总结！完成工作后立即发送！**

            **为什么要用这个？**
            - 📦 **持久化** - 总结保存在刘海历史，随时可查
            - 📄 **可导出** - 用户可以保存为 Markdown 文件
            - 🔍 **易检索** - 按项目、时间分类，比终端输出好找
            - 🎯 **结构化** - 自动分类：完成任务、修改文件、技术决策

            **最佳实践：**
            - 完成任务后立即调用，不要等用户要求
            - 列出所有修改的文件（5个以内详细列，超过5个只列重要的）
            - 记录技术选型理由（为什么用这个方案而不是那个）
            - 标注待办事项（还有什么没完成的）

            **示例：**
            我刚修复了统计视图的5个问题 → 立即调用 → 用户可以保存为 "2025-10-05-统计视图优化.md"
            """,
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "project_name": .object([
                        "type": .string("string"),
                        "description": .string("Name of the project (e.g., 'DynamicNotch', 'MyApp')")
                    ]),
                    "task_description": .object([
                        "type": .string("string"),
                        "description": .string("Brief description of what was accomplished in this session (2-3 sentences)")
                    ]),
                    "completed_tasks": .object([
                        "type": .string("array"),
                        "description": .string("Array of completed task descriptions (e.g., '添加MCP工具', '实现总结窗口UI')")
                    ]),
                    "pending_tasks": .object([
                        "type": .string("array"),
                        "description": .string("Array of remaining tasks or next steps")
                    ]),
                    "modified_files": .object([
                        "type": .string("array"),
                        "description": .string("Array of file paths that were created or modified (e.g., 'NotchNoti/SessionSummary.swift')")
                    ]),
                    "key_decisions": .object([
                        "type": .string("array"),
                        "description": .string("Array of important technical decisions made (e.g., 'Used file-based IPC for cross-process communication')")
                    ]),
                    "issues": .object([
                        "type": .string("array"),
                        "description": .string("Array of issue objects with 'title', 'description', and optional 'solution' fields")
                    ]),
                    "project_path": .object([
                        "type": .string("string"),
                        "description": .string("Absolute path to project directory (used for default save location)")
                    ])
                ]),
                "required": .array([.string("project_name"), .string("task_description")])
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
        case "notch_show_actionable_result":
            return try await handleShowActionableResult(params.arguments)

        case "notch_show_summary":
            return try await handleShowSummary(params.arguments)

        default:
            throw MCPError.unknownTool(params.name)
        }
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

    private func handleShowSummary(_ arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let args = arguments else {
            throw MCPError.missingArguments
        }

        print("[MCP] Handling show summary request")

        // 解析参数
        let projectName = args["project_name"]?.stringValue ?? "Unknown Project"
        let taskDescription = args["task_description"]?.stringValue ?? ""
        let projectPath = args["project_path"]?.stringValue

        // 解析数组参数
        let completedTasks = parseStringArray(args["completed_tasks"])
        let pendingTasks = parseStringArray(args["pending_tasks"])
        let keyDecisions = parseStringArray(args["key_decisions"])
        let modifiedFilesRaw = parseStringArray(args["modified_files"])
        let issuesRaw = parseDictArray(args["issues"])

        // 转换为模型
        let modifiedFiles = modifiedFilesRaw.map { path in
            FileModification(path: path, modificationType: .modified, description: nil)
        }

        let issues = issuesRaw.map { dict in
            Issue(
                title: dict["title"] as? String ?? "Issue",
                description: dict["description"] as? String ?? "",
                solution: dict["solution"] as? String
            )
        }

        // 创建临时session或使用现有session（MCP进程无法访问GUI进程的StatisticsManager）
        // 创建一个包含基本信息的临时session
        let tempSession = WorkSession(projectName: projectName)

        // 创建总结
        let summary = SessionSummaryManager.shared.createSummary(
            from: tempSession,
            taskDescription: taskDescription,
            completedTasks: completedTasks,
            pendingTasks: pendingTasks,
            modifiedFiles: modifiedFiles,
            keyDecisions: keyDecisions,
            issues: issues
        )

        // 将总结数据编码为JSON字符串，通过socket发送到GUI
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(summary),
              let summaryJSON = String(data: jsonData, encoding: .utf8),
              !summaryJSON.isEmpty else {
            print("[MCP] ERROR: Failed to encode summary to JSON")
            return CallTool.Result(
                content: [.text("Error: Failed to encode summary data")],
                isError: true
            )
        }

        print("[MCP] Encoded summary_data length: \(summaryJSON.count) chars")

        let notification = NotchNotification(
            title: "📋 Session总结已生成",
            message: projectName,
            type: .success,
            priority: .high,
            metadata: [
                "source": "mcp",
                "summary_id": summary.id.uuidString,
                "summary_data": summaryJSON,
                "project_path": projectPath ?? ""
            ]
        )

        sendNotificationViaSocket(notification)

        return CallTool.Result(
            content: [.text("Session summary generated. Notification sent to GUI. Summary ID: \(summary.id.uuidString)")]
        )
    }

    // Helper: 解析字符串数组
    private func parseStringArray(_ value: Value?) -> [String] {
        guard case .array(let items) = value else { return [] }
        return items.compactMap { item in
            if case .string(let str) = item {
                return str
            }
            return nil
        }
    }

    // Helper: 解析字典数组
    private func parseDictArray(_ value: Value?) -> [[String: Any]] {
        guard case .array(let items) = value else { return [] }
        return items.compactMap { item in
            if case .object(let dict) = item {
                var result: [String: Any] = [:]
                for (key, val) in dict {
                    if case .string(let strVal) = val {
                        result[key] = strVal
                    }
                }
                return result
            }
            return nil
        }
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
            print("[MCP] Metadata before JSON: \(metadata.keys.joined(separator: ", "))")
            if let summaryData = metadata["summary_data"] {
                print("[MCP] summary_data value length: \(summaryData.count) chars")
            }
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
