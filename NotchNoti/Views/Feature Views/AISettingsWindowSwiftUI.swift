//
//  AISettingsWindowSwiftUI.swift
//  NotchNoti
//
//  SwiftUI版AI设置窗口 - 视觉统一设计
//

import SwiftUI
import Cocoa

// MARK: - 窗口管理器

class AISettingsWindowManager {
    static let shared = AISettingsWindowManager()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let settingsView = AISettingsWindowView()
            let hostingController = NSHostingController(rootView: settingsView)

            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            newWindow.title = "AI分析设置"
            newWindow.titlebarAppearsTransparent = true
            newWindow.titleVisibility = .hidden
            newWindow.center()
            newWindow.isReleasedWhenClosed = false
            newWindow.contentView = hostingController.view
            newWindow.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.95)

            window = newWindow
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - SwiftUI主视图

struct AISettingsWindowView: View {
    @State private var config: LLMConfig
    @ObservedObject private var aiManager = AIAnalysisManager.shared
    @State private var showAPIKey = false
    @State private var showSaveSuccess = false
    @State private var isTesting = false

    init() {
        _config = State(initialValue: AIAnalysisManager.shared.loadConfig() ?? LLMConfig())
    }

    var body: some View {
        ZStack {
            // 背景渐变 - 和刘海风格一致
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.15, blue: 0.15),
                    Color(red: 0.1, green: 0.1, blue: 0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 顶部标题区 - 统一样式
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)
                                .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 4)

                            Image(systemName: "sparkles")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI 工作洞察")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)

                            Text("分析工作模式，优化开发节奏")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.65))
                        }

                        Spacer()
                    }
                    .padding(.top, 30)
                    .padding(.horizontal, 24)

                    // 启用开关卡片
                    VStack(spacing: 20) {
                        Toggle(isOn: $config.enabled) {
                            HStack {
                                Image(systemName: config.enabled ? "power.circle.fill" : "power.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(config.enabled ? .green : .gray)

                                Text("启用 AI 分析")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .toggleStyle(.switch)

                        if config.enabled {
                            configurationSection
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)

                    // 隐私说明卡片
                    if config.enabled {
                        privacySection
                    }

                    Spacer()

                    // 底部操作栏
                    actionButtons
                }
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 配置区域

    @ViewBuilder
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .background(Color.white.opacity(0.1))

            // API地址
            FormField(
                icon: "link",
                title: "API 地址",
                placeholder: "https://api.openai.com",
                text: $config.baseURL
            )

            // 模型
            FormField(
                icon: "cpu",
                title: "模型名称",
                placeholder: "gpt-4o-mini",
                text: $config.model
            )

            // API Key
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "key.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow.opacity(0.8))
                        .frame(width: 20)

                    Text("API Key")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))

                    Spacer()

                    Button(action: { showAPIKey.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: showAPIKey ? "eye.slash.fill" : "eye.fill")
                            Text(showAPIKey ? "隐藏" : "显示")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }

                if showAPIKey {
                    MacTextFieldWrapper(
                        text: $config.apiKey,
                        placeholder: "sk-proj-..."
                    )
                    .frame(height: 32)
                } else {
                    MacSecureFieldWrapper(
                        text: $config.apiKey,
                        placeholder: "••••••••"
                    )
                    .frame(height: 32)
                }
            }

            // Temperature
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange.opacity(0.8))
                        .frame(width: 20)

                    Text("Temperature")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))

                    Spacer()

                    Text(String(format: "%.1f", config.temperature))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }

                Slider(value: $config.temperature, in: 0...2, step: 0.1)
                    .tint(.purple)
            }
        }
    }

    // MARK: - 隐私说明

    @ViewBuilder
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)

                Text("隐私保护")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                PrivacyRow(icon: "checkmark.circle.fill", text: "仅发送统计数据（时长、次数、模式）")
                PrivacyRow(icon: "xmark.circle.fill", text: "不发送代码、文件名等敏感信息", isNegative: true)
                PrivacyRow(icon: "checkmark.circle.fill", text: "所有数据本地处理，不经第三方")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    // MARK: - 操作按钮

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 12) {
            if showSaveSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("已保存")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .transition(.opacity)
            }

            Spacer()

            Button(action: { testConnection() }) {
                HStack(spacing: 6) {
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                            .tint(.white)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 12))
                    }
                    Text("测试连接")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.12))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(!config.enabled || config.baseURL.isEmpty || config.apiKey.isEmpty || isTesting)

            Button(action: { saveConfiguration() }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text("保存配置")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(8)
                .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 操作方法

    private func saveConfiguration() {
        aiManager.saveConfig(config)
        withAnimation {
            showSaveSuccess = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSaveSuccess = false
            }
        }
    }

    private func testConnection() {
        isTesting = true
        Task {
            await aiManager.testConnection(
                baseURL: config.baseURL,
                model: config.model,
                apiKey: config.apiKey
            )

            await MainActor.run {
                isTesting = false

                let alert = NSAlert()
                if let error = aiManager.lastError {
                    alert.messageText = "连接失败"
                    alert.informativeText = error
                    alert.alertStyle = .critical
                } else {
                    alert.messageText = "连接成功"
                    alert.informativeText = "API 配置正常！"
                    alert.alertStyle = .informational
                }
                alert.addButton(withTitle: "好的")
                alert.runModal()
            }
        }
    }
}

// MARK: - 组件

struct FormField: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.blue.opacity(0.8))
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }

            MacTextFieldWrapper(
                text: $text,
                placeholder: placeholder
            )
            .frame(height: 32)
        }
    }
}

struct PrivacyRow: View {
    let icon: String
    let text: String
    var isNegative: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(isNegative ? .red.opacity(0.7) : .green.opacity(0.7))

            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - AppKit包装器

struct MacTextFieldWrapper: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.backgroundColor = NSColor.white.withAlphaComponent(0.08)
        textField.textColor = .white
        textField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacTextFieldWrapper

        init(_ parent: MacTextFieldWrapper) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
    }
}

struct MacSecureFieldWrapper: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeNSView(context: Context) -> NSSecureTextField {
        let textField = NSSecureTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.backgroundColor = NSColor.white.withAlphaComponent(0.08)
        textField.textColor = .white
        textField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        return textField
    }

    func updateNSView(_ nsView: NSSecureTextField, context: Context) {
        nsView.stringValue = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacSecureFieldWrapper

        init(_ parent: MacSecureFieldWrapper) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSSecureTextField else { return }
            parent.text = textField.stringValue
        }
    }
}
