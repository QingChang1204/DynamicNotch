//
//  DiffView.swift
//  NotchDrop
//
//  文件改动对比视图
//

import SwiftUI
import AppKit

struct DiffView: View {
    let diffPath: String?
    let filePath: String
    @Binding var isPresented: Bool
    @State private var diffContent: DiffContent?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // 内容区域
            if isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let content = diffContent {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 统计信息
                        HStack(spacing: 16) {
                            Label("\(content.addedLines) 添加", systemImage: "plus.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 11))
                            
                            Label("\(content.removedLines) 删除", systemImage: "minus.circle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 11))
                            
                            Spacer()
                            
                            Button(action: openInEditor) {
                                Label("在编辑器中打开", systemImage: "arrow.up.forward.square")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.link)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        
                        // Diff 内容
                        ForEach(content.lines) { line in
                            DiffLineView(line: line)
                        }
                    }
                }
                .background(Color(NSColor.textBackgroundColor))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadDiff()
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
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let diffText = try String(contentsOfFile: diffPath, encoding: .utf8)
                let content = parseDiff(diffText)
                
                DispatchQueue.main.async {
                    self.diffContent = content
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
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
            // 行号
            Text("\(line.lineNumber)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)
            
            // 内容
            Text(line.content)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(backgroundColor)
    }
    
    private var textColor: Color {
        switch line.type {
        case .added:
            return .green
        case .removed:
            return .red
        case .header:
            return .blue
        case .context:
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        switch line.type {
        case .added:
            return Color.green.opacity(0.1)
        case .removed:
            return Color.red.opacity(0.1)
        case .header:
            return Color.blue.opacity(0.05)
        case .context:
            return Color.clear
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