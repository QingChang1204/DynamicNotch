//
//  SummaryWindowController.swift
//  NotchNoti
//
//  Session总结窗口控制器
//

import Cocoa
import SwiftUI

/// Session总结窗口控制器（单例，管理所有总结窗口）
class SummaryWindowController: NSObject {
    static let shared = SummaryWindowController()

    private var windows: [UUID: NSWindow] = [:]  // summaryId -> window
    private var windowToSummaryId: [ObjectIdentifier: UUID] = [:]  // window标识 -> summaryId

    private override init() {
        super.init()
    }

    /// 显示总结窗口
    func showSummary(_ summary: SessionSummary, projectPath: String?) {
        // 如果该总结的窗口已经打开，激活它
        if let existingWindow = windows[summary.id] {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // 创建新窗口
        let window = createSummaryWindow(summary: summary, projectPath: projectPath)
        windows[summary.id] = window
        windowToSummaryId[ObjectIdentifier(window)] = summary.id

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createSummaryWindow(summary: SessionSummary, projectPath: String?) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        window.title = "Session总结 - \(summary.projectName) - \(dateFormatter.string(from: summary.startTime))"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        // 创建状态绑定用于关闭窗口（用于SwiftUI内部的关闭按钮）
        let windowId = ObjectIdentifier(window)
        let isPresented = Binding<Bool>(
            get: { window.isVisible },
            set: { [weak self] newValue in
                if !newValue {
                    window.close()
                    // 清理会由windowWillClose代理处理，这里不需要重复
                }
            }
        )

        // 创建SwiftUI内容视图
        let contentView = SummaryView(
            summary: summary,
            projectPath: projectPath,
            isPresented: isPresented
        )

        window.contentView = NSHostingView(rootView: contentView)

        // 设置delegate监听系统关闭事件（但不在windowWillClose里操作contentView）
        window.delegate = self

        return window
    }

    /// 关闭指定总结的窗口
    func closeSummary(_ summaryId: UUID) {
        if let window = windows[summaryId] {
            let windowId = ObjectIdentifier(window)
            windowToSummaryId.removeValue(forKey: windowId)
            window.close()
            windows.removeValue(forKey: summaryId)
        }
    }

    /// 关闭所有总结窗口
    func closeAll() {
        for window in windows.values {
            window.close()
        }
        windows.removeAll()
        windowToSummaryId.removeAll()
    }
}

// MARK: - NSWindowDelegate

extension SummaryWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        let windowId = ObjectIdentifier(window)

        // 清理窗口映射（不操作contentView，避免NSTextView的Core Text崩溃）
        if let summaryId = windowToSummaryId[windowId] {
            windowToSummaryId.removeValue(forKey: windowId)
            windows.removeValue(forKey: summaryId)
        }
    }
}

// MARK: - Summary View

struct SummaryView: View {
    let summary: SessionSummary
    let projectPath: String?
    @Binding var isPresented: Bool

    @State private var showingSavePanel = false
    @State private var saveStatus: SaveStatus?
    @State private var hostingWindow: NSWindow?

    enum SaveStatus {
        case success(String)  // 文件路径
        case error(String)    // 错误信息
    }

    var body: some View {
        ZStack {
            // 背景渐变 - 与刘海风格一致
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.15, blue: 0.15),
                    Color(red: 0.1, green: 0.1, blue: 0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部标题栏
                headerBar

                Divider()
                    .background(Color.white.opacity(0.1))

                // 操作工具栏
                actionToolbar

                Divider()
                    .background(Color.white.opacity(0.05))

                // AI洞察卡片（如果有）
                if let insight = summary.aiInsight {
                    aiInsightCard(insight)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)

                    Divider()
                        .background(Color.white.opacity(0.05))
                }

                // Markdown内容区域
                MarkdownTextView(text: summary.toMarkdown())
            }
        }
        .background(WindowAccessor(window: $hostingWindow))
    }

    // MARK: - AI洞察卡片

    private func aiInsightCard(_ insight: WorkInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("AI 工作洞察")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Text(insight.type.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }

            // 总结
            Text(insight.summary)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(4)

            // 建议
            if !insight.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(insight.suggestions.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.cyan)
                                .frame(width: 20, alignment: .trailing)

                            Text(insight.suggestions[index])
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - 顶部标题栏

    private var headerBar: some View {
        HStack(spacing: 12) {
            // 图标和项目信息
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.projectName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Text("Session 总结")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))

                        Text("•")
                            .foregroundColor(.white.opacity(0.3))

                        Text(formatTime(summary.startTime))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }

            Spacer()

            // 关闭按钮
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.2))
    }

    // MARK: - 操作工具栏

    private var actionToolbar: some View {
        HStack(spacing: 12) {
            // 保存到默认位置
            Button(action: saveToDefault) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 12))
                    Text("保存到项目")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .opacity(0.2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("保存到 项目/docs/sessions/")

            // 另存为
            Button(action: presentSavePanel) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.badge.arrow.up")
                        .font(.system(size: 12))
                    Text("另存为...")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // 复制到剪贴板
            Button(action: copyToClipboard) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 12))
                    Text("复制")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Spacer()

            // 保存状态提示
            if let status = saveStatus {
                switch status {
                case .success(_):
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("已保存")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(6)
                case .error(let message):
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(6)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.15))
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Actions

    private func saveToDefault() {
        guard let projectPath = projectPath else {
            saveStatus = .error("未知项目路径")
            return
        }

        guard let suggestedPath = SessionSummaryManager.shared.suggestSavePath(
            for: summary,
            projectPath: projectPath
        ) else {
            saveStatus = .error("无法生成保存路径")
            return
        }

        do {
            try SessionSummaryManager.shared.ensureDirectoryExists(at: suggestedPath)
            try SessionSummaryManager.shared.saveSummary(summary, to: suggestedPath)
            saveStatus = .success(suggestedPath.path)

            // 3秒后清除状态
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                await MainActor.run {
                    saveStatus = nil
                }
            }

            // 发送通知
            let notification = NotchNotification(
                title: "总结已保存",
                message: "保存到: \(suggestedPath.lastPathComponent)",
                type: .success,
                priority: .normal,
                metadata: ["path": suggestedPath.path]
            )
            Task {
                await NotificationManager.shared.addNotification(notification)
            }

        } catch {
            saveStatus = .error("保存失败: \(error.localizedDescription)")
        }
    }

    private func saveToCustomLocation(_ url: URL) {
        do {
            try SessionSummaryManager.shared.ensureDirectoryExists(at: url)
            try SessionSummaryManager.shared.saveSummary(summary, to: url)
            saveStatus = .success(url.path)

            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                await MainActor.run {
                    saveStatus = nil
                }
            }

            let notification = NotchNotification(
                title: "总结已保存",
                message: "保存到: \(url.lastPathComponent)",
                type: .success,
                priority: .normal,
                metadata: ["path": url.path]
            )
            Task {
                await NotificationManager.shared.addNotification(notification)
            }

        } catch {
            saveStatus = .error("保存失败: \(error.localizedDescription)")
        }
    }

    private func copyToClipboard() {
        let markdown = summary.toMarkdown()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(markdown, forType: .string)

        saveStatus = .success("已复制到剪贴板")

        // 2秒后清除状态
        Task {
            try? await Task.sleep(nanoseconds: UInt64(UIConstants.Delay.settingsReset * 1_000_000_000))
            await MainActor.run {
                saveStatus = nil
            }
        }
    }

    private func presentSavePanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "session-summary.md"
        panel.message = "选择保存位置"
        panel.prompt = "保存"

        // 作为sheet附加到窗口，避免独立窗口导致的Metal冲突
        if let window = hostingWindow {
            panel.beginSheetModal(for: window) { response in
                if response == .OK, let url = panel.url {
                    self.saveToCustomLocation(url)
                }
            }
        } else {
            // 降级方案：无父窗口时使用独立面板
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    self.saveToCustomLocation(url)
                }
            }
        }
    }
}

// MARK: - Window Accessor (获取NSWindow引用)

struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor in
            self.window = view.window
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            self.window = nsView.window
        }
    }
}

// MARK: - Markdown Text View (NSTextView wrapper for better performance)

struct MarkdownTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        // 深色主题配置
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor(white: 0.9, alpha: 1.0)  // 浅灰色文字
        textView.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)  // 深色背景
        textView.insertionPointColor = NSColor.white  // 光标颜色
        textView.string = text

        // 滚动视图样式
        scrollView.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        scrollView.drawsBackground = true

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: ()) {
        // 清理NSTextView的内容和布局，避免Core Text缓存访问已释放内存
        if let textView = nsView.documentView as? NSTextView {
            textView.string = ""
            textView.layoutManager?.replaceTextStorage(NSTextStorage())
            textView.textStorage?.setAttributedString(NSAttributedString())
        }
    }
}
