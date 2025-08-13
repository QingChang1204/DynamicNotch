//
//  UnixSocketServerSimple.swift
//  NotchNoti
//
//  Simple Unix Domain Socket server using BSD sockets
//

import Foundation

class UnixSocketServerSimple: ObservableObject {
    static let shared = UnixSocketServerSimple()
    
    // 使用用户的临时目录，避免权限问题
    private lazy var socketPath: String = {
        let tmpDir = NSTemporaryDirectory() // 这会返回应用的临时目录
        let socketFile = (tmpDir as NSString).appendingPathComponent("notch.sock")
        
        // 为了方便访问，创建一个符号链接到用户主目录
        let homeSocketPath = NSHomeDirectory() + "/.notch.sock"
        
        return homeSocketPath
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
            print("[UnixSocket] Failed to create socket")
            return
        }
        
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
            print("[UnixSocket] Failed to bind: \(String(cString: strerror(errno)))")
            close(serverSocket)
            return
        }
        
        // 开始监听
        guard listen(serverSocket, 5) == 0 else {
            print("[UnixSocket] Failed to listen: \(String(cString: strerror(errno)))")
            close(serverSocket)
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
            
            // 在主线程添加通知
            DispatchQueue.main.async {
                NotificationManager.shared.addNotification(notchNotification)
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
}