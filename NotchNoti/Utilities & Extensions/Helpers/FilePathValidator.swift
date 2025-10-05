//
//  FilePathValidator.swift
//  NotchNoti
//
//  文件路径安全验证工具
//  防止访问敏感系统文件和目录
//

import Foundation

/// 文件路径安全验证器
enum FilePathValidator {

    // MARK: - 黑名单路径（绝对禁止访问）

    /// 敏感系统目录黑名单
    private static let blacklistedDirectories: Set<String> = [
        "/etc",                          // 系统配置文件
        "/var/root",                     // root用户目录
        "/System",                       // macOS系统目录
        "/private/etc",                  // 系统配置（实际路径）
        "/private/var/root",             // root用户目录（实际路径）
        "/.Spotlight-V100",              // Spotlight索引
        "/.fseventsd",                   // 文件系统事件
        "/.DocumentRevisions-V100",      // 文档版本历史
    ]

    /// 敏感文件黑名单（模式匹配）
    private static let blacklistedFilePatterns: [String] = [
        "/etc/passwd",                   // 用户账户信息
        "/etc/shadow",                   // 密码哈希
        "/etc/sudoers",                  // sudo权限配置
        "/etc/ssh/",                     // SSH配置
        ".ssh/id_",                      // SSH私钥
        ".ssh/config",                   // SSH客户端配置
        ".aws/credentials",              // AWS凭证
        ".docker/config.json",           // Docker凭证
        "credentials.json",              // 通用凭证文件
        ".env",                          // 环境变量（可能含密钥）
        ".npmrc",                        // npm配置（可能含token）
        ".pypirc",                       // PyPI配置
        "id_rsa",                        // SSH私钥（旧格式）
        "id_ecdsa",                      // SSH私钥
        "id_ed25519",                    // SSH私钥
        "master.key",                    // Rails master key
        "*.pem",                         // SSL私钥
        "*.key",                         // 通用私钥
        "*.p12",                         // PKCS#12证书
        "*.keychain",                    // macOS钥匙串
    ]

    // MARK: - 验证方法

    /// 验证文件路径是否安全
    /// - Parameter path: 待验证的文件路径
    /// - Returns: 如果路径安全返回true，否则返回false
    static func isPathSafe(_ path: String) -> Bool {
        // 1. 标准化路径（解析符号链接和相对路径）
        let normalizedPath = (path as NSString).standardizingPath

        // 2. 检查是否在黑名单目录中
        for blacklistedDir in blacklistedDirectories {
            if normalizedPath.hasPrefix(blacklistedDir) {
                print("[Security] BLOCKED: Path in blacklisted directory: \(normalizedPath)")
                return false
            }
        }

        // 3. 检查是否匹配黑名单文件模式
        for pattern in blacklistedFilePatterns {
            // 支持通配符匹配
            if pattern.contains("*") {
                let regexPattern = pattern
                    .replacingOccurrences(of: ".", with: "\\.")
                    .replacingOccurrences(of: "*", with: ".*")

                if let regex = try? NSRegularExpression(pattern: regexPattern) {
                    let range = NSRange(normalizedPath.startIndex..., in: normalizedPath)
                    if regex.firstMatch(in: normalizedPath, range: range) != nil {
                        print("[Security] BLOCKED: Path matches pattern '\(pattern)': \(normalizedPath)")
                        return false
                    }
                }
            } else {
                // 精确匹配或包含匹配
                if normalizedPath.contains(pattern) {
                    print("[Security] BLOCKED: Path contains '\(pattern)': \(normalizedPath)")
                    return false
                }
            }
        }

        // 4. 额外检查：不允许访问其他用户的主目录
        let homeDir = NSHomeDirectory()
        let usersDir = "/Users/"

        if normalizedPath.hasPrefix(usersDir) && !normalizedPath.hasPrefix(homeDir) {
            // 路径在 /Users/ 下但不在当前用户主目录
            print("[Security] BLOCKED: Access to other user's home directory: \(normalizedPath)")
            return false
        }

        // 5. 检查文件是否真实存在（可选，防止路径遍历攻击）
        if !FileManager.default.fileExists(atPath: normalizedPath) {
            print("[Security] BLOCKED: File does not exist: \(normalizedPath)")
            return false
        }

        // 通过所有检查
        return true
    }

    /// 安全地读取文件内容
    /// - Parameter path: 文件路径
    /// - Returns: 文件内容，如果路径不安全或读取失败返回nil
    static func safeReadFile(_ path: String) -> String? {
        guard isPathSafe(path) else {
            return nil
        }

        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    /// 验证路径并返回错误描述
    /// - Parameter path: 待验证的文件路径
    /// - Returns: 如果安全返回nil，否则返回错误描述
    static func validatePath(_ path: String) -> String? {
        guard isPathSafe(path) else {
            return "访问被拒绝：该文件路径可能包含敏感信息或不在允许的范围内"
        }
        return nil
    }
}
