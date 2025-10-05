//
//  PendingActionStore.swift
//  NotchNoti
//
//  Shared store for MCP actionable notifications
//  Uses file-based storage for cross-process communication
//

import Foundation

/// Pending action request waiting for user interaction
/// Uses file system for IPC between GUI and MCP processes
actor PendingActionStore {
    static let shared = PendingActionStore()

    // 存储文件路径（使用 NSHomeDirectory 确保跨进程共享）
    // 使用 nonisolated 暴露给文件监控器使用
    nonisolated let storageURL: URL = {
        let containerPath = NSHomeDirectory()
        return URL(fileURLWithPath: containerPath).appendingPathComponent(".notch_pending_actions.json")
    }()

    struct PendingAction: Codable {
        let id: String
        let title: String
        let message: String
        let type: String
        let actions: [String]
        let timestamp: Date
        var userChoice: String?
    }

    private init() {}

    // MARK: - File-based Storage

    private func load() -> [String: PendingAction] {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return [:]
        }

        guard let data = try? Data(contentsOf: storageURL),
              let actions = try? JSONDecoder().decode([String: PendingAction].self, from: data) else {
            return [:]
        }

        return actions
    }

    private func save(_ actions: [String: PendingAction]) {
        guard let data = try? JSONEncoder().encode(actions) else { return }
        // 不使用 .atomic 以确保文件监控器能检测到变化
        // .atomic 会导致文件被 rename 替换，使得原文件描述符失效
        try? data.write(to: storageURL, options: [])
    }

    // MARK: - Public API

    func create(id: String, title: String, message: String, type: String, actions: [String]) {
        var pendingActions = load()
        pendingActions[id] = PendingAction(
            id: id,
            title: title,
            message: message,
            type: type,
            actions: actions,
            timestamp: Date(),
            userChoice: nil
        )
        save(pendingActions)
    }

    func setChoice(id: String, choice: String) {
        var pendingActions = load()
        pendingActions[id]?.userChoice = choice
        save(pendingActions)
    }

    func getChoice(id: String) -> String? {
        let pendingActions = load()
        return pendingActions[id]?.userChoice
    }

    func remove(id: String) {
        var pendingActions = load()
        pendingActions.removeValue(forKey: id)
        save(pendingActions)
    }

    func getPending() -> [PendingAction] {
        let pendingActions = load()
        return Array(pendingActions.values).sorted { $0.timestamp > $1.timestamp }
    }
}
