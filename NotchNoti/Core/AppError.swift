//
//  AppError.swift
//  NotchNoti
//
//  统一的错误处理系统
//  提供类型安全的错误传播和用户友好的错误消息
//

import Foundation

/// 应用程序顶层错误类型
enum AppError: LocalizedError {
    case storage(StorageError)
    case network(NetworkError)
    case validation(ValidationError)
    case resource(ResourceError)
    case system(SystemError)

    var errorDescription: String? {
        switch self {
        case .storage(let error):
            return "存储错误: \(error.localizedDescription)"
        case .network(let error):
            return "网络错误: \(error.localizedDescription)"
        case .validation(let error):
            return "验证失败: \(error.localizedDescription)"
        case .resource(let error):
            return "资源错误: \(error.localizedDescription)"
        case .system(let error):
            return "系统错误: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .storage(let error):
            return error.recoverySuggestion
        case .network(let error):
            return error.recoverySuggestion
        case .validation(let error):
            return error.recoverySuggestion
        case .resource(let error):
            return error.recoverySuggestion
        case .system(let error):
            return error.recoverySuggestion
        }
    }

    /// 错误是否可恢复
    var isRecoverable: Bool {
        switch self {
        case .storage(let error):
            return error.isRecoverable
        case .network(let error):
            return error.isRecoverable
        case .validation:
            return true
        case .resource(let error):
            return error.isRecoverable
        case .system(let error):
            return error.isRecoverable
        }
    }

    /// 错误严重程度
    var severity: Severity {
        switch self {
        case .storage(.corruptedData), .system(.coreDataFailed):
            return .critical
        case .storage(.diskFull), .network(.timeout):
            return .warning
        default:
            return .error
        }
    }

    enum Severity {
        case warning
        case error
        case critical
    }
}

// MARK: - Storage Errors

enum StorageError: LocalizedError {
    case diskFull
    case corruptedData
    case migrationFailed(reason: String)
    case entityNotFound(String)
    case saveFailed(underlying: Error)
    case fetchFailed(underlying: Error)
    case decodingFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .diskFull:
            return "磁盘空间不足"
        case .corruptedData:
            return "数据已损坏"
        case .migrationFailed(let reason):
            return "数据迁移失败: \(reason)"
        case .entityNotFound(let name):
            return "未找到实体: \(name)"
        case .saveFailed(let error):
            return "保存失败: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "查询失败: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "解码失败: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .diskFull:
            return "请清理磁盘空间后重试"
        case .corruptedData:
            return "建议重置应用数据"
        case .migrationFailed:
            return "请联系开发者获取帮助"
        case .saveFailed, .fetchFailed:
            return "请重试操作"
        case .decodingFailed:
            return "数据格式可能已过时,建议更新应用"
        default:
            return nil
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .diskFull, .saveFailed, .fetchFailed:
            return true
        case .corruptedData, .migrationFailed:
            return false
        default:
            return true
        }
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case timeout
    case connectionLost
    case socketBindFailed(reason: String)
    case socketAcceptFailed
    case invalidRequest(reason: String)
    case requestTooLarge(size: Int, limit: Int)

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "连接超时"
        case .connectionLost:
            return "连接已断开"
        case .socketBindFailed(let reason):
            return "Socket 绑定失败: \(reason)"
        case .socketAcceptFailed:
            return "无法接受客户端连接"
        case .invalidRequest(let reason):
            return "无效请求: \(reason)"
        case .requestTooLarge(let size, let limit):
            return "请求过大: \(size) bytes (限制: \(limit) bytes)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .timeout, .connectionLost:
            return "请检查网络连接后重试"
        case .socketBindFailed:
            return "请确保应用未重复运行"
        case .invalidRequest:
            return "请检查客户端配置"
        case .requestTooLarge:
            return "请减小请求大小"
        default:
            return nil
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .timeout, .connectionLost:
            return true
        default:
            return false
        }
    }
}

// MARK: - Validation Errors

enum ValidationError: LocalizedError {
    case emptyField(fieldName: String)
    case invalidFormat(fieldName: String, expected: String)
    case outOfRange(fieldName: String, range: String)
    case custom(message: String)

    var errorDescription: String? {
        switch self {
        case .emptyField(let field):
            return "\(field) 不能为空"
        case .invalidFormat(let field, let expected):
            return "\(field) 格式错误,期望: \(expected)"
        case .outOfRange(let field, let range):
            return "\(field) 超出范围,有效范围: \(range)"
        case .custom(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        return "请检查输入并重试"
    }
}

// MARK: - Resource Errors

enum ResourceError: LocalizedError {
    case notFound(resource: String)
    case fileWatcherFailed(path: String)
    case cannotOpenFile(path: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .notFound(let resource):
            return "未找到资源: \(resource)"
        case .fileWatcherFailed(let path):
            return "文件监控失败: \(path)"
        case .cannotOpenFile(let path, let reason):
            return "无法打开文件 \(path): \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notFound:
            return "请确保资源存在"
        case .fileWatcherFailed, .cannotOpenFile:
            return "请检查文件权限"
        }
    }

    var isRecoverable: Bool {
        return false
    }
}

// MARK: - System Errors

enum SystemError: LocalizedError {
    case coreDataFailed(reason: String)
    case actorIsolationViolation
    case unexpectedNil(variable: String)

    var errorDescription: String? {
        switch self {
        case .coreDataFailed(let reason):
            return "CoreData 错误: \(reason)"
        case .actorIsolationViolation:
            return "并发隔离违规"
        case .unexpectedNil(let variable):
            return "意外的空值: \(variable)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .coreDataFailed:
            return "请重启应用"
        case .actorIsolationViolation:
            return "这是一个编程错误,请报告给开发者"
        case .unexpectedNil:
            return "请重启应用"
        }
    }

    var isRecoverable: Bool {
        return false
    }
}

// MARK: - Result Extensions

extension Result where Failure == AppError {
    /// 将错误映射为用户可读的消息
    var userMessage: String {
        switch self {
        case .success:
            return "操作成功"
        case .failure(let error):
            return error.localizedDescription
        }
    }

    /// 获取恢复建议
    var recoverySuggestion: String? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error.recoverySuggestion
        }
    }
}

// MARK: - Error Logging

extension AppError {
    /// 记录错误到控制台
    func log(context: String = #function, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let prefix = severity == .critical ? "🔴 [CRITICAL]" : severity == .warning ? "⚠️  [WARNING]" : "❌ [ERROR]"

        print("\(prefix) [\(fileName):\(line)] \(context)")
        print("  ↳ \(localizedDescription)")

        if let suggestion = recoverySuggestion {
            print("  💡 \(suggestion)")
        }
    }
}
