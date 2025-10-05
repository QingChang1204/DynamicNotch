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
            if let summaryData = notification.metadata?["summary_data"] {
                print("[UnixSocket] summary_data length: \(summaryData.count) chars")
            }

            // 创建通知
            let notchNotification = NotchNotification(
                title: notification.title,
                message: notification.message,
                type: NotchNotification.NotificationType(rawValue: notification.type ?? "info") ?? .info,
                priority: NotchNotification.Priority(rawValue: notification.priority ?? 1) ?? .normal,
                icon: notification.icon,
                actions: notification.actions?.map { action in
                    NotificationAction(
                        label: action.label,
                        action: action.action,
                        style: NotificationAction.ActionStyle(rawValue: action.style ?? "normal") ?? .normal
                    )
                },
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
    /// 只允许同一用户的进程连接
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

        guard result == 0 else {
            print("[UnixSocket] SECURITY: Failed to get peer credentials: \(String(cString: strerror(errno)))")
            return false
        }

        let clientUID = cred.cr_uid
        let serverUID = getuid()

        // 只允许同一用户的进程
        if clientUID != serverUID {
            print("[UnixSocket] SECURITY: UID mismatch - client:\(clientUID) server:\(serverUID)")
            return false
        }

        // print("[UnixSocket] SECURITY: ✓ Validated client UID: \(clientUID)")
        return true
    }
}