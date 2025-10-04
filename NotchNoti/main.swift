//
//  main.swift
//  NotchNoti
//
//  Created by 秋星桥 on 2024/7/7.
//

import Cocoa

// URL定义已移除，不再需要

let bundleIdentifier = Bundle.main.bundleIdentifier!
let appVersion = "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))"

private let availableDirectories = FileManager
    .default
    .urls(for: .documentDirectory, in: .userDomainMask)
let documentsDirectory = availableDirectories[0]
    .appendingPathComponent("NotchNotifier")
let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent(bundleIdentifier)
let pidFile = documentsDirectory.appendingPathComponent("ProcessIdentifier")

try? FileManager.default.createDirectory(
    at: documentsDirectory,
    withIntermediateDirectories: true,
    attributes: nil
)
try? FileManager.default.createDirectory(
    at: temporaryDirectory,
    withIntermediateDirectories: true,
    attributes: nil
)

// 检查是否是 MCP 服务器模式
let arguments = CommandLine.arguments
let isMCPMode = arguments.contains("--mcp")

if isMCPMode {
    // MCP 服务器模式：不启动 GUI,只运行 MCP 服务器
    // 注意：stdio transport 要求 stdout 只能输出 JSON-RPC 消息

    // MCP 服务器将通过 Unix Socket 与 GUI 进程通信
    // 不需要初始化 GUI 相关的管理器

    Task { @MainActor in
        do {
            try await NotchMCPServer.shared.start()
        } catch {
            // 错误输出到 stderr，不影响 stdout
            fputs("[main] MCP server failed to start: \(error)\n", stderr)
            exit(1)
        }
    }

    // 使用简单的 RunLoop 保持运行
    RunLoop.main.run()
} else {
    // 标准 GUI 模式
    try? FileManager.default.removeItem(at: temporaryDirectory)
    try? FileManager.default.createDirectory(
        at: temporaryDirectory,
        withIntermediateDirectories: true,
        attributes: nil
    )

    do {
        let prevIdentifier = try String(contentsOf: pidFile, encoding: .utf8)
        if let prev = Int(prevIdentifier) {
            if let app = NSRunningApplication(processIdentifier: pid_t(prev)) {
                app.terminate()
            }
        }
    } catch {}
    try? FileManager.default.removeItem(at: pidFile)

    do {
        let pid = String(NSRunningApplication.current.processIdentifier)
        try pid.write(to: pidFile, atomically: true, encoding: .utf8)
    } catch {
        NSAlert.popError(error)
        exit(1)
    }

    // 初始化通知系统
    _ = NotificationManager.shared

    // 只启动 Unix Socket 服务器（不占用端口）
    UnixSocketServerSimple.shared.start()
    print("[main] Started Unix Socket server at ~/.notch.sock")

    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}
