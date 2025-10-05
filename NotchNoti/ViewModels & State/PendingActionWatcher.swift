//
//  PendingActionWatcher.swift
//  NotchNoti
//
//  文件系统监控器 - 替代轮询机制
//  使用 DispatchSource 监听文件变化，实现零延迟响应
//

import Foundation

/// 文件系统监控器
/// 监听 PendingActionStore 的文件变化，当文件被写入时立即触发回调
class PendingActionWatcher {
    private var source: DispatchSourceFileSystemObject?
    private let fileDescriptor: Int32
    private let queue = DispatchQueue(label: "com.notchnoti.filewatcher", qos: .userInteractive)
    private let onChange: () -> Void

    /// 初始化文件监控器
    /// - Parameters:
    ///   - path: 要监控的文件路径
    ///   - onChange: 文件变化时的回调（在后台队列执行）
    init?(path: String, onChange: @escaping () -> Void) {
        self.onChange = onChange

        // 确保文件存在
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: path) {
            fileManager.createFile(atPath: path, contents: Data("{}".utf8), attributes: nil)
        }

        // 打开文件用于监听（只读模式）
        fileDescriptor = open(path, O_EVTONLY)

        guard fileDescriptor >= 0 else {
            return nil
        }

        // 创建文件系统监控源
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],  // 监听写入、重命名、删除事件
            queue: queue
        )

        guard let source = source else {
            close(fileDescriptor)
            return nil
        }

        // 设置事件处理器
        source.setEventHandler { [weak self] in
            self?.onChange()
        }

        // 设置取消处理器（关闭文件描述符）
        source.setCancelHandler { [fileDescriptor] in
            close(fileDescriptor)
        }

        // 启动监控
        source.resume()
    }

    /// 停止监控并清理资源
    func stop() {
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }
}
