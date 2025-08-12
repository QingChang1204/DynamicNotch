//
//  NotificationServer.swift
//  NotchDrop
//
//  Local HTTP Server for receiving Claude Code hook notifications
//

import Foundation
import Network

class NotificationServer: ObservableObject {
    static let shared = NotificationServer()
    
    private var listener: NWListener?
    private let port: UInt16 = 9876
    @Published var isRunning = false
    
    private init() {}
    
    func start() {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        do {
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
            
            listener?.newConnectionHandler = { [weak self] connection in
                print("[NotificationServer] New connection received")
                self?.handleConnection(connection)
            }
            
            listener?.stateUpdateHandler = { state in
                print("[NotificationServer] State updated: \(state)")
                switch state {
                case .ready:
                    print("[NotificationServer] Server is ready on port \(self.port)")
                case .failed(let error):
                    print("[NotificationServer] Server failed with error: \(error)")
                default:
                    break
                }
            }
            
            listener?.start(queue: .global())
            isRunning = true
            print("[NotificationServer] Started on port \(port)")
        } catch {
            print("[NotificationServer] Failed to start: \(error)")
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        print("[NotificationServer] Stopped")
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global())
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                // 使用后台队列处理请求，避免阻塞
                DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                    self?.processRequest(data, connection: connection)
                }
            }
            
            if isComplete {
                connection.cancel()
            } else if let error = error {
                print("[NotificationServer] Connection error: \(error)")
                connection.cancel()
            }
        }
    }
    
    private func processRequest(_ data: Data, connection: NWConnection) {
        guard let request = String(data: data, encoding: .utf8) else { 
            print("[NotificationServer] Failed to decode request")
            return 
        }
        
        print("[NotificationServer] Received request: \(request.prefix(200))...")
        
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { 
            print("[NotificationServer] No first line in request")
            return 
        }
        
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { 
            print("[NotificationServer] Invalid request line: \(firstLine)")
            return 
        }
        
        let method = parts[0]
        let path = parts[1]
        
        print("[NotificationServer] \(method) \(path)")
        
        if method == "POST" && path == "/notify" {
            if let bodyStart = request.range(of: "\r\n\r\n") {
                let bodyData = String(request[bodyStart.upperBound...]).data(using: .utf8) ?? Data()
                handleNotificationRequest(bodyData, connection: connection)
            } else {
                sendResponse(connection: connection, status: 400, body: "{\"error\":\"No body\"}")
            }
        } else if method == "GET" && path == "/health" {
            sendResponse(connection: connection, status: 200, body: "{\"status\":\"ok\"}")
        } else {
            sendResponse(connection: connection, status: 404, body: "{\"error\":\"Not found\"}")
        }
    }
    
    private func handleNotificationRequest(_ data: Data, connection: NWConnection) {
        do {
            let decoder = JSONDecoder()
            let notification = try decoder.decode(NotificationRequest.self, from: data)
            
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
            
            // 使用更高优先级的队列确保快速响应
            DispatchQueue.main.async { [weak self] in
                NotificationManager.shared.addNotification(notchNotification)
                if NotchViewModel.shared?.status != .opened {
                    NotchViewModel.shared?.notchOpen(.drag)
                }
            }
            
            sendResponse(connection: connection, status: 200, body: "{\"success\":true}")
        } catch {
            print("[NotificationServer] Failed to parse notification: \(error)")
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"Invalid request\"}")
        }
    }
    
    private func sendResponse(connection: NWConnection, status: Int, body: String) {
        let statusText = status == 200 ? "OK" : status == 400 ? "Bad Request" : "Not Found"
        let response = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: application/json\r
        Content-Length: \(body.utf8.count)\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: POST, GET, OPTIONS\r
        Access-Control-Allow-Headers: Content-Type\r
        \r
        \(body)
        """
        
        let responseData = response.data(using: .utf8) ?? Data()
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

struct NotificationRequest: Codable {
    let title: String
    let message: String
    let type: String?
    let priority: Int?
    let icon: String?
    let actions: [ActionRequest]?
    let metadata: [String: String]?
}

struct ActionRequest: Codable {
    let label: String
    let action: String
    let style: String?
}

extension NotchViewModel {
    static weak var shared: NotchViewModel?
}