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

    // 存储文件路径（在沙盒 tmp 目录）
    // 使用 nonisolated 暴露给文件监控器使用
    nonisolated let storageURL: URL = {
        let tmpDir = FileManager.default.temporaryDirectory
        return tmpDir.appendingPathComponent("notch_pending_actions.json")
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
        try? data.write(to: storageURL, options: .atomic)
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
