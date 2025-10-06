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

    // 文件锁路径
    private nonisolated let lockURL: URL = {
        let containerPath = NSHomeDirectory()
        return URL(fileURLWithPath: containerPath).appendingPathComponent(".notch_pending_actions.lock")
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

    private init() {
        // 确保锁文件存在
        if !FileManager.default.fileExists(atPath: lockURL.path) {
            FileManager.default.createFile(atPath: lockURL.path, contents: nil)
        }
    }

    // MARK: - File-based Storage with Locking

    /// 获取文件锁（阻塞直到获取成功）
    private func acquireLock() -> FileHandle? {
        guard let fileHandle = try? FileHandle(forUpdating: lockURL) else {
            print("[PendingActionStore] ⚠️ Failed to open lock file")
            return nil
        }

        // 使用 flock 进行文件锁定（LOCK_EX = 独占锁）
        let fd = fileHandle.fileDescriptor
        if flock(fd, LOCK_EX) != 0 {
            print("[PendingActionStore] ⚠️ Failed to acquire lock: \(String(cString: strerror(errno)))")
            try? fileHandle.close()
            return nil
        }

        return fileHandle
    }

    /// 释放文件锁
    private func releaseLock(_ fileHandle: FileHandle) {
        let fd = fileHandle.fileDescriptor
        flock(fd, LOCK_UN)
        try? fileHandle.close()
    }

    private func load() -> [String: PendingAction] {
        // 获取文件锁
        guard let lockHandle = acquireLock() else {
            print("[PendingActionStore] ⚠️ Load without lock (fallback)")
            return loadUnsafe()
        }
        defer { releaseLock(lockHandle) }

        return loadUnsafe()
    }

    private func loadUnsafe() -> [String: PendingAction] {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return [:]
        }

        guard let data = try? Data(contentsOf: storageURL),
              let actions = try? JSONDecoder().decode([String: PendingAction].self, from: data) else {
            print("[PendingActionStore] ⚠️ Failed to decode JSON, returning empty dict")
            return [:]
        }

        return actions
    }

    private func save(_ actions: [String: PendingAction]) {
        // 获取文件锁
        guard let lockHandle = acquireLock() else {
            print("[PendingActionStore] ⚠️ Save without lock (unsafe)")
            saveUnsafe(actions)
            return
        }
        defer { releaseLock(lockHandle) }

        saveUnsafe(actions)
    }

    private func saveUnsafe(_ actions: [String: PendingAction]) {
        guard let data = try? JSONEncoder().encode(actions) else {
            print("[PendingActionStore] ❌ Failed to encode actions")
            return
        }

        do {
            // 不使用 .atomic 以确保文件监控器能检测到变化
            // .atomic 会导致文件被 rename 替换，使得原文件描述符失效
            try data.write(to: storageURL, options: [])
        } catch {
            print("[PendingActionStore] ❌ Failed to write file: \(error.localizedDescription)")
        }
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

        // 如果记录不存在，创建一个新的（通过Unix Socket发送的交互式通知可能没有先create）
        if pendingActions[id] == nil {
            print("[PendingActionStore] ⚠️  No pending action found for id '\(id)', creating placeholder")
            pendingActions[id] = PendingAction(
                id: id,
                title: "User Action",
                message: "User made a choice",
                type: "info",
                actions: [choice],
                timestamp: Date(),
                userChoice: choice
            )
        } else {
            // 更新现有记录
            pendingActions[id]?.userChoice = choice
        }

        save(pendingActions)
        print("[PendingActionStore] ✅ Saved choice '\(choice)' for request_id '\(id)'")
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
