//
//  ClaudeCodeSetup.swift
//  NotchNoti
//
//  自动配置Claude Code hooks
//

import Foundation
import AppKit

class ClaudeCodeSetup {
    static let shared = ClaudeCodeSetup()
    
    private init() {}
    
    // Claude Code settings目录
    private var claudeSettingsDir: URL? {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
    }
    
    // 检查Claude Code是否已安装
    func isClaudeCodeInstalled() -> Bool {
        guard let dir = claudeSettingsDir else { return false }
        return FileManager.default.fileExists(atPath: dir.path)
    }
    
    // 获取当前hook二进制文件路径
    private func getHookBinaryPath() -> String {
        // 始终使用 /Applications 下的路径，而不是Xcode DerivedData
        return "/Applications/NotchNoti.app/Contents/MacOS/notch-hook"
    }
    
    // 生成settings.local.json内容
    private func generateSettingsContent() -> String {
        let hookPath = getHookBinaryPath()
        
        return """
        {
          "hooks": {
            "PreToolUse": [
              {
                "matcher": ".*",
                "hooks": [
                  {
                    "type": "command",
                    "command": "\(hookPath)",
                    "timeout": 2
                  }
                ]
              }
            ],
            "PostToolUse": [
              {
                "matcher": ".*",
                "hooks": [
                  {
                    "type": "command",
                    "command": "\(hookPath)",
                    "timeout": 2
                  }
                ]
              }
            ],
            "Stop": [
              {
                "matcher": ".*",
                "hooks": [
                  {
                    "type": "command",
                    "command": "\(hookPath)",
                    "timeout": 2
                  }
                ]
              }
            ],
            "Notification": [
              {
                "matcher": ".*",
                "hooks": [
                  {
                    "type": "command",
                    "command": "\(hookPath)",
                    "timeout": 2
                  }
                ]
              }
            ],
            "PreCompact": [
              {
                "matcher": ".*",
                "hooks": [
                  {
                    "type": "command",
                    "command": "\(hookPath)",
                    "timeout": 2
                  }
                ]
              }
            ]
          }
        }
        """
    }
    
    // 合并hooks配置到现有设置
    private func mergeHooksIntoSettings(_ existingSettings: [String: Any]) -> [String: Any] {
        var settings = existingSettings
        let hookPath = getHookBinaryPath()
        
        // 准备新的hook配置
        let newHookConfig: [String: Any] = [
            "type": "command",
            "command": hookPath,
            "timeout": 2
        ]
        
        // 要添加的hook事件 - 包括所有事件
        let hookEvents = ["PreToolUse", "PostToolUse", "Stop", "Notification", "PreCompact", "SessionStart", "UserPromptSubmit"]
        
        // 获取或创建hooks字典
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        
        for event in hookEvents {
            // 获取或创建该事件的配置数组
            var eventConfigs = hooks[event] as? [[String: Any]] ?? []
            
            // 遍历每个配置，更新或添加hook
            var foundNotchHook = false
            
            for (index, var config) in eventConfigs.enumerated() {
                if var configHooks = config["hooks"] as? [[String: Any]] {
                    // 移除旧的notch-hook（可能是旧路径）
                    configHooks = configHooks.filter { hook in
                        let command = hook["command"] as? String ?? ""
                        return !command.contains("notch-hook")
                    }
                    
                    // 添加新的notch-hook
                    configHooks.append(newHookConfig)
                    config["hooks"] = configHooks
                    eventConfigs[index] = config
                    foundNotchHook = true
                }
            }
            
            // 如果没有找到任何配置，创建一个新的
            if !foundNotchHook {
                let newConfig: [String: Any] = [
                    "matcher": ".*",
                    "hooks": [newHookConfig]
                ]
                eventConfigs.append(newConfig)
            }
            
            hooks[event] = eventConfigs
        }
        
        settings["hooks"] = hooks
        return settings
    }
    
    // 配置Claude Code hooks - 用户选择项目目录
    @discardableResult
    func setupClaudeCodeHooks() -> (success: Bool, message: String) {
        // 检查hook二进制文件是否存在
        let hookPath = getHookBinaryPath()
        guard FileManager.default.fileExists(atPath: hookPath) else {
            return (false, "Hook程序未找到。请确保notch-hook已正确安装。")
        }
        
        // 打开文件选择器让用户选择项目
        let panel = NSOpenPanel()
        panel.title = "选择项目目录"
        panel.message = "选择要配置NotchNoti通知的Claude Code项目"
        panel.prompt = "选择"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        
        guard panel.runModal() == .OK,
              let projectDir = panel.url else {
            return (false, "未选择项目目录")
        }
        
        // 检查或创建.claude目录
        let claudeDir = projectDir.appendingPathComponent(".claude")
        let settingsFile = claudeDir.appendingPathComponent("settings.local.json")
        
        do {
            // 创建.claude目录（如果不存在）
            if !FileManager.default.fileExists(atPath: claudeDir.path) {
                try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
            }
            
            var finalSettings: [String: Any]
            
            // 检查是否已有配置文件
            if FileManager.default.fileExists(atPath: settingsFile.path) {
                // 备份现有配置
                let backupFile = claudeDir.appendingPathComponent("settings.local.backup.json")
                try? FileManager.default.removeItem(at: backupFile)
                try FileManager.default.copyItem(at: settingsFile, to: backupFile)
                
                // 读取现有配置
                let data = try Data(contentsOf: settingsFile)
                let existingSettings = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                
                // 合并配置
                finalSettings = mergeHooksIntoSettings(existingSettings)
            } else {
                finalSettings = try JSONSerialization.jsonObject(
                    with: generateSettingsContent().data(using: .utf8)!
                ) as! [String: Any]
            }
            
            // 写入配置文件 - 不转义斜杠
            let jsonData = try JSONSerialization.data(withJSONObject: finalSettings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            try jsonData.write(to: settingsFile)
            
            // 设置hook执行权限
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/chmod")
            process.arguments = ["+x", hookPath]
            try process.run()
            process.waitUntilExit()
            
            // 保存项目路径，以便查看配置文件
            lastConfiguredProjectPath = projectDir
            
            return (true, """
                ✅ NotchNoti配置成功！
                
                项目：\(projectDir.lastPathComponent)
                配置文件：.claude/settings.local.json
                
                现在可以开始使用Claude Code了！
                """)
        } catch {
            return (false, "配置失败：\(error.localizedDescription)")
        }
    }
    
    // 保存最后配置的项目路径
    private var lastConfiguredProjectPath: URL?
    
    // 显示配置结果
    func showSetupResult(_ result: (success: Bool, message: String)) {
        let alert = NSAlert()
        alert.messageText = result.success ? "配置成功" : "配置失败"
        alert.informativeText = result.message
        alert.alertStyle = result.success ? .informational : .warning
        alert.addButton(withTitle: "确定")
        
        if result.success {
            alert.addButton(withTitle: "查看配置文件")
        }
        
        let response = alert.runModal()
        
        if result.success && response == .alertSecondButtonReturn {
            // 打开配置文件所在目录
            if let projectPath = lastConfiguredProjectPath {
                let claudeDir = projectPath.appendingPathComponent(".claude")
                NSWorkspace.shared.open(claudeDir)
            }
        }
    }
}
