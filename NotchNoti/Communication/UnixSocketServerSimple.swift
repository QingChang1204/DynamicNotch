//
//  UnixSocketServerSimple.swift
//  NotchNoti
//
//  Simple Unix Domain Socket server using BSD sockets
//

import Foundation

class UnixSocketServerSimple: ObservableObject {
    static let shared = UnixSocketServerSimple()
    
    // 沙盒环境下的 socket 路径
    private lazy var socketPath: String = {
        // 沙盒应用的 Data 目录
        let homeDir = NSHomeDirectory()
        let socketFile = (homeDir as NSString).appendingPathComponent(".notch.sock")

        print("[UnixSocket] Socket will be created at: \(socketFile)")
        print("[UnixSocket] This is inside sandbox container")

        return socketFile
    }()
    private var serverSocket: Int32 = -1
    private var isListening = false
    private var listenQueue: DispatchQueue?
    
    @Published var isRunning = false
    
    private init() {}
    
    func start() {
        print("[UnixSocket] Attempting to create socket at: \(socketPath)")
        
        // 清理旧的 socket 文件
        cleanupSocket()
        
        // 创建 socket
        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            print("[UnixSocket] ERROR: Failed to create socket - \(String(cString: strerror(errno)))")
            serverSocket = -1
            return
        }

        // 设置 SO_NOSIGPIPE 避免 SIGPIPE 崩溃
        var on: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))

        // 设置 socket 地址
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path.0) { dest in
                _ = strcpy(dest, ptr)
            }
        }

        // 绑定 socket
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(serverSocket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult == 0 else {
            print("[UnixSocket] ERROR: Failed to bind socket - \(String(cString: strerror(errno)))")
            print("[UnixSocket] Socket path: \(socketPath)")
            close(serverSocket)
            serverSocket = -1
            cleanupSocket()  // 清理可能残留的 socket 文件
            return
        }

        // 设置socket文件权限为0600（仅所有者可读写）
        let permissions: mode_t = 0o600
        if chmod(socketPath, permissions) != 0 {
            print("[UnixSocket] WARNING: Failed to set socket permissions to 0600: \(String(cString: strerror(errno)))")
        } else {
            print("[UnixSocket] ✓ Socket permissions set to 0600 (owner-only)")
        }

        // 开始监听
        guard listen(serverSocket, 5) == 0 else {
            print("[UnixSocket] ERROR: Failed to listen - \(String(cString: strerror(errno)))")
            close(serverSocket)
            serverSocket = -1
            cleanupSocket()
            return
        }
        
        isRunning = true
        isListening = true
        print("[UnixSocket] Listening on \(socketPath)")
        
        // 在后台队列接受连接
        listenQueue = DispatchQueue(label: "com.notchnoti.unixsocket", qos: .userInteractive)
        listenQueue?.async { [weak self] in
            self?.acceptConnections()
        }
    }
    
    func stop() {
        isListening = false
        isRunning = false
        
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
        
        cleanupSocket()
        print("[UnixSocket] Stopped")
    }
    
    private func cleanupSocket() {
        try? FileManager.default.removeItem(atPath: socketPath)
    }
    
    private func acceptConnections() {
        while isListening {
            // 检查serverSocket是否有效
            guard serverSocket >= 0 else {
                print("[UnixSocket] Server socket invalid, stopping accept loop")
                break
            }

            var clientAddr = sockaddr_un()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    accept(serverSocket, sockaddrPtr, &clientAddrLen)
                }
            }

            if clientSocket < 0 {
                if isListening {
                    print("[UnixSocket] Accept error: \(String(cString: strerror(errno)))")
                }
                continue
            }
            
            // 处理客户端连接
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                self?.handleClient(clientSocket)
            }
        }
    }
    
    private func handleClient(_ clientSocket: Int32) {
        defer { close(clientSocket) }

        // 权限验证: 检查客户端UID
        if !validateClientPermissions(clientSocket) {
            print("[UnixSocket] SECURITY: Rejected connection from unauthorized client")
            return
        }

        // 设置客户端 socket 的 SO_NOSIGPIPE
        var on: Int32 = 1
        setsockopt(clientSocket, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))

        // 读取数据
        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = recv(clientSocket, &buffer, buffer.count, 0)
        
        guard bytesRead > 0 else {
            print("[UnixSocket] No data received")
            return
        }
        
        let data = Data(bytes: buffer, count: bytesRead)
        
        // 解析 JSON
        do {
            let decoder = JSONDecoder()
            let notification = try decoder.decode(NotificationRequest.self, from: data)

            print("[UnixSocket] Received notification: \(notification.title)")
            print("[UnixSocket] Metadata keys: \(notification.metadata?.keys.joined(separator: ", ") ?? "none")")
            print("[UnixSocket] Actions field: \(notification.actions?.count ?? -1) items (nil if -1)")
            if let summaryData = notification.metadata?["summary_data"] {
                print("[UnixSocket] summary_data length: \(summaryData.count) chars")
            }

            // 创建通知 (确保空actions数组被转换为nil)
            let parsedActions: [NotificationAction]? = {
                guard let requestActions = notification.actions, !requestActions.isEmpty else {
                    return nil
                }
                return requestActions.map { action in
                    NotificationAction(
                        label: action.label,
                        action: action.action,
                        style: NotificationAction.ActionStyle(rawValue: action.style ?? "normal") ?? .normal
                    )
                }
            }()

            let notchNotification = NotchNotification(
                title: notification.title,
                message: notification.message,
                type: NotchNotification.NotificationType(rawValue: notification.type ?? "info") ?? .info,
                priority: NotchNotification.Priority(rawValue: notification.priority ?? 1) ?? .normal,
                icon: notification.icon,
                actions: parsedActions,
                metadata: notification.metadata
            )
            
            // 在主线程添加通知和处理统计
            Task { @MainActor in
                // 处理统计信息
                if let metadata = notification.metadata {
                    self.processStatistics(metadata: metadata)

                    // 处理总结数据
                    if let summaryJSON = metadata[MetadataKeys.summaryData],
                       let summaryData = summaryJSON.data(using: .utf8) {
                        self.processSummaryData(summaryData)
                    }

                    // 处理交互式通知 - 创建 PendingAction
                    if metadata["actionable"] == "true",
                       let requestId = metadata["request_id"],
                       let actions = parsedActions {
                        await PendingActionStore.shared.create(
                            id: requestId,
                            title: notification.title,
                            message: notification.message,
                            type: notification.type ?? "info",
                            actions: actions.map { $0.label }
                        )
                    }
                }

                await NotificationManager.shared.addNotification(notchNotification)
                if NotchViewModel.shared?.status != .opened {
                    NotchViewModel.shared?.notchOpen(.drag)
                }
            }
            
            // 发送成功响应
            let response = "{\"success\":true}"
            _ = response.withCString { ptr in
                send(clientSocket, ptr, strlen(ptr), 0)
            }
            
            print("[UnixSocket] Notification processed successfully")
            
        } catch {
            print("[UnixSocket] Failed to parse JSON: \(error)")
            
            // 发送错误响应
            let response = "{\"success\":false,\"error\":\"Invalid JSON\"}"
            _ = response.withCString { ptr in
                send(clientSocket, ptr, strlen(ptr), 0)
            }
        }
    }
    
    // 获取当前 socket 路径
    func getCurrentSocketPath() -> String? {
        return isRunning ? socketPath : nil
    }

    // 处理统计信息
    private func processStatistics(metadata: [String: String]) {
        // 使用标准化的键名访问（带向后兼容）
        guard let event = metadata.eventType else { return }

        switch event {
        case "session_start":
            if let projectName = metadata.project {
                StatisticsManager.shared.startSession(projectName: projectName)
            }

        case "tool_use", "tool_success", "tool_complete", "PreToolUse", "PostToolUse":
            // 从 metadata 中获取工具名称（带向后兼容）
            if let toolName = metadata.toolName {
                let duration = metadata.duration ?? 0
                StatisticsManager.shared.recordActivity(toolName: toolName, duration: duration)
            }

        case "session_end", "Stop":
            StatisticsManager.shared.endSession()

        default:
            break
        }
    }

    private func processSummaryData(_ data: Data) {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let summary = try decoder.decode(SessionSummary.self, from: data)

            // 添加到SessionSummaryManager
            DispatchQueue.main.async {
                // 检查是否已存在（避免重复）
                if !SessionSummaryManager.shared.recentSummaries.contains(where: { $0.id == summary.id }) {
                    SessionSummaryManager.shared.recentSummaries.insert(summary, at: 0)

                    // 保持最多5条
                    if SessionSummaryManager.shared.recentSummaries.count > 5 {
                        SessionSummaryManager.shared.recentSummaries = Array(SessionSummaryManager.shared.recentSummaries.prefix(5))
                    }

                    print("[UnixSocket] Summary added to manager: \(summary.projectName)")
                }
            }
        } catch {
            print("[UnixSocket] Failed to decode summary data: \(error)")
        }
    }

    // MARK: - Security: Permission Validation

    /// 验证客户端权限 (UID检查)
    /// 严格模式：仅允许同一用户或root用户的进程连接
    private func validateClientPermissions(_ clientSocket: Int32) -> Bool {
        var cred = xucred()
        var credLen = socklen_t(MemoryLayout<xucred>.size)

        // 获取客户端进程的凭证 (UID/GID)
        let result = getsockopt(
            clientSocket,
            0, // SOL_LOCAL
            0x0002, // LOCAL_PEERCRED
            &cred,
            &credLen
        )

        let serverUID = getuid()

        guard result == 0 else {
            // Unix域socket在某些情况下getsockopt会失败，这是正常的
            // errno 57 (ENOTCONN) 特别常见，表示socket未完全建立连接状态
            let errorCode = errno

            print("[UnixSocket] SECURITY: Failed to get peer credentials (errno: \(errorCode))")

            // 对于特定的非致命错误码，检查socket文件权限作为替代验证
            let tolerableErrors: [Int32] = [
                57,  // ENOTCONN - Socket is not connected (常见于本地Unix socket)
                22,  // EINVAL - Invalid argument (某些macOS版本的已知问题)
            ]

            if tolerableErrors.contains(errorCode) {
                print("[UnixSocket] SECURITY: Tolerable error, checking socket file permissions...")

                // 额外验证：检查socket文件权限
                // 如果socket文件只有当前用户可访问，可以容忍凭证获取失败
                if isSocketFileSecure() {
                    print("[UnixSocket] SECURITY: ✓ Socket file permissions verified (0600), allowing connection")
                    return true
                }
            }

            print("[UnixSocket] SECURITY: ⛔️ DENIED - Connection rejected (error: \(errorCode))")
            return false
        }

        let clientUID = cred.cr_uid

        // 允许同一用户或root用户（UID=0）连接
        // root允许连接是因为Claude Code的Hook可能以sudo运行
        if clientUID != serverUID && clientUID != 0 {
            print("[UnixSocket] SECURITY: ⛔️ DENIED - UID mismatch (client:\(clientUID) server:\(serverUID))")
            return false
        }

        // print("[UnixSocket] SECURITY: ✓ Validated client UID: \(clientUID)")
        return true
    }

    /// 验证socket文件权限是否安全（仅当前用户可访问）
    private func isSocketFileSecure() -> Bool {
        guard FileManager.default.fileExists(atPath: socketPath) else {
            print("[UnixSocket] SECURITY: Socket file does not exist")
            return false
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: socketPath)
            guard let posixPermissions = attributes[.posixPermissions] as? NSNumber else {
                print("[UnixSocket] SECURITY: Failed to read socket permissions")
                return false
            }

            // 验证权限：应该是 0600 或 0700（仅所有者可读写/执行）
            let permissions = posixPermissions.uint16Value
            let ownerOnly = (permissions & 0o077) == 0  // 检查组和其他用户没有任何权限

            if !ownerOnly {
                print("[UnixSocket] SECURITY: ⚠️  Insecure permissions: \(String(format: "0%o", permissions)) (expected: 0600 or 0700)")
                return false
            }

            print("[UnixSocket] SECURITY: ✓ Socket permissions OK: \(String(format: "0%o", permissions))")
            return true
        } catch {
            print("[UnixSocket] SECURITY: ⚠️  Failed to check permissions: \(error.localizedDescription)")
            return false
        }
    }
}
