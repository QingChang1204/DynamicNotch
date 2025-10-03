//
//  AISettingsWindowController.swift
//  NotchNoti
//
//  AI配置独立窗口
//

import Cocoa
import SwiftUI

// MARK: - NSTextView包装器（完整支持复制粘贴）

struct NSTextFieldWrapper: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.delegate = context.coordinator

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NSTextFieldWrapper

        init(_ parent: NSTextFieldWrapper) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

class AISettingsWindowController: NSWindowController {
    static let shared = AISettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "AI分析设置"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .normal  // 改成normal，floating可能阻止粘贴

        // SwiftUI内容
        let contentView = AISettingsContentView()
        window.contentView = NSHostingView(rootView: contentView)

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - 独立窗口配置视图

struct AISettingsContentView: View {
    @State private var config: LLMConfig
    @ObservedObject var aiManager = AIAnalysisManager.shared
    @State private var showSaveSuccess = false
    @State private var showAPIKey = false

    init() {
        _config = State(initialValue: AIAnalysisManager.shared.loadConfig() ?? LLMConfig())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("AI工作洞察设置")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 配置表单
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 启用开关
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("启用AI分析", isOn: $config.enabled)
                            .font(.headline)
                        Text("开启后，可通过AI分析工作会话数据，获取智能建议")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if config.enabled {
                        Divider()

                        // API地址
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API地址")
                                .font(.headline)
                            TextField("https://api.openai.com", text: $config.baseURL)
                                .textFieldStyle(.roundedBorder)
                            Text("支持OpenAI兼容的API端点")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // 模型
                        VStack(alignment: .leading, spacing: 8) {
                            Text("模型")
                                .font(.headline)
                            TextField("gpt-4o-mini", text: $config.model)
                                .textFieldStyle(.roundedBorder)
                            Text("建议使用快速响应的小模型，如 gpt-4o-mini")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // API Key
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("API Key")
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    showAPIKey.toggle()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                        Text(showAPIKey ? "隐藏" : "显示")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }

                            if showAPIKey {
                                NSTextFieldWrapper(text: $config.apiKey)
                                    .frame(height: 60)
                            } else {
                                SecureField("sk-...", text: $config.apiKey)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Text("API密钥仅保存在本地，不会上传。提示：点击\"显示\"后可以复制粘贴")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Temperature
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Temperature")
                                    .font(.headline)
                                Spacer()
                                Text(String(format: "%.1f", config.temperature))
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $config.temperature, in: 0...2, step: 0.1)
                            Text("较低值更保守，较高值更有创意。推荐 0.7")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        // 隐私说明
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "lock.shield")
                                    .foregroundColor(.green)
                                Text("隐私保护")
                                    .font(.headline)
                            }
                            Text("• 仅发送工作统计数据（时长、操作次数、模式等）")
                                .font(.caption)
                            Text("• 不发送代码内容、文件名等敏感信息")
                                .font(.caption)
                            Text("• 所有数据仅在本地处理，不经过第三方服务")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }

            Divider()

            // 底部操作栏
            HStack {
                if showSaveSuccess {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("保存成功")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity)
                }

                Spacer()

                Button("测试连接") {
                    Task {
                        await testConnection()
                    }
                }
                .disabled(!config.enabled || config.baseURL.isEmpty || config.apiKey.isEmpty)

                Button("保存") {
                    saveConfig()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func saveConfig() {
        aiManager.saveConfig(config)
        showSaveSuccess = true

        // 3秒后隐藏成功提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showSaveSuccess = false
            }
        }
    }

    private func testConnection() async {
        // 简单测试：发送一个最小请求
        await aiManager.testConnection(
            baseURL: config.baseURL,
            model: config.model,
            apiKey: config.apiKey
        )
    }
}
