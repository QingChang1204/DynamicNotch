//
//  DiffView.swift
//  NotchNoti
//
//  文件改动对比视图
//

import SwiftUI
import Cocoa

struct DiffView: View {
    let diffPath: String?
    let filePath: String
    @Binding var isPresented: Bool
    @State private var diffContent: DiffContent?
    @State private var isLoading = true
    @State private var errorMessage: String?

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

                // 内容区域
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let content = diffContent {
                    diffContentView(content)
                }
            }
        }
        .onAppear {
            loadDiff()
        }
    }

    // MARK: - 顶部标题栏

    private var headerBar: some View {
        HStack(spacing: 12) {
            // 文件图标和名称
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(fileName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text("文件改动预览")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Spacer()

            // 关闭按钮
            WindowCloseButton(isPresented: $isPresented)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.2))
    }

    // MARK: - 加载状态

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.cyan)

            Text("加载中...")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 错误状态

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 64, height: 64)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
            }

            Text(error)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Diff内容视图

    private func diffContentView(_ content: DiffContent) -> some View {
        VStack(spacing: 0) {
            // 统计信息栏
            HStack(spacing: 20) {
                // 添加统计
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("\(content.addedLines) 添加")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.15))
                .cornerRadius(6)

                // 删除统计
                HStack(spacing: 6) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text("\(content.removedLines) 删除")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.15))
                .cornerRadius(6)

                Spacer()

                // 在编辑器中打开
                Button(action: openInEditor) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 12))
                        Text("在编辑器中打开")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.15))

            // Diff内容滚动区域
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(content.lines) { line in
                        DiffLineView(line: line)
                    }
                }
            }
            .background(Color.black.opacity(0.1))
        }
    }
    
    private var fileName: String {
        URL(fileURLWithPath: filePath).lastPathComponent
    }
    
    private func loadDiff() {
        guard let diffPath = diffPath else {
            errorMessage = "没有 diff 文件路径"
            isLoading = false
            return
        }

        // 安全验证：检查路径是否安全
        if let validationError = FilePathValidator.validatePath(diffPath) {
            errorMessage = validationError
            isLoading = false
            return
        }

        Task.detached(priority: .userInitiated) {
            do {
                let diffText = try String(contentsOfFile: diffPath, encoding: .utf8)
                let content = parseDiff(diffText)

                await MainActor.run {
                    self.diffContent = content
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "无法读取 diff 文件: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func parseDiff(_ text: String) -> DiffContent {
        var lines: [DiffLine] = []
        var addedCount = 0
        var removedCount = 0
        
        for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let lineStr = String(line)
            var diffLine = DiffLine(
                id: index,
                content: lineStr,
                type: .context,
                lineNumber: index + 1
            )
            
            if lineStr.hasPrefix("+") && !lineStr.hasPrefix("+++") {
                diffLine.type = .added
                addedCount += 1
            } else if lineStr.hasPrefix("-") && !lineStr.hasPrefix("---") {
                diffLine.type = .removed
                removedCount += 1
            } else if lineStr.hasPrefix("@@") {
                diffLine.type = .header
            }
            
            lines.append(diffLine)
        }
        
        return DiffContent(
            lines: lines,
            addedLines: addedCount,
            removedLines: removedCount
        )
    }
    
    private func openInEditor() {
        // 安全验证：检查路径是否安全
        guard FilePathValidator.isPathSafe(filePath) else {
            print("[Security] Blocked attempt to open file in editor: \(filePath)")
            return
        }

        if let url = URL(string: "file://\(filePath)") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct DiffContent {
    let lines: [DiffLine]
    let addedLines: Int
    let removedLines: Int
}

struct DiffLine: Identifiable {
    let id: Int
    let content: String
    var type: LineType
    let lineNumber: Int
    
    enum LineType {
        case added
        case removed
        case context
        case header
    }
}

struct DiffLineView: View {
    let line: DiffLine

    var body: some View {
        HStack(spacing: 0) {
            // 行号区域
            Text("\(line.lineNumber)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 50, alignment: .trailing)
                .padding(.trailing, 12)

            // 类型指示器
            Text(linePrefix)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(prefixColor)
                .frame(width: 16, alignment: .leading)

            // 内容
            Text(line.content.dropFirst(linePrefix.isEmpty ? 0 : 1))  // 移除原始的+/-前缀
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(backgroundColor)
        .overlay(
            Rectangle()
                .fill(accentColor)
                .frame(width: 3),
            alignment: .leading
        )
    }

    private var linePrefix: String {
        switch line.type {
        case .added: return "+"
        case .removed: return "-"
        case .header: return "@"
        case .context: return ""
        }
    }

    private var prefixColor: Color {
        switch line.type {
        case .added: return .green.opacity(0.9)
        case .removed: return .red.opacity(0.9)
        case .header: return .cyan.opacity(0.9)
        case .context: return .clear
        }
    }

    private var textColor: Color {
        switch line.type {
        case .added:
            return .white.opacity(0.95)
        case .removed:
            return .white.opacity(0.95)
        case .header:
            return .cyan.opacity(0.85)
        case .context:
            return .white.opacity(0.7)
        }
    }

    private var backgroundColor: Color {
        switch line.type {
        case .added:
            return Color.green.opacity(0.12)
        case .removed:
            return Color.red.opacity(0.12)
        case .header:
            return Color.cyan.opacity(0.08)
        case .context:
            return Color.white.opacity(0.02)
        }
    }

    private var accentColor: Color {
        switch line.type {
        case .added: return .green.opacity(0.5)
        case .removed: return .red.opacity(0.5)
        case .header: return .cyan.opacity(0.5)
        case .context: return .clear
        }
    }
}

// 预览
#Preview {
    DiffView(
        diffPath: nil,
        filePath: "/Users/test/example.swift",
        isPresented: .constant(true)
    )
}