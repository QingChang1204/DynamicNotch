//
//  AISettingsWindow.swift
//  NotchNoti
//
//  纯AppKit实现的AI设置窗口（避免SwiftUI剪贴板bug）
//

import Cocoa

// 使用标准 NSTextField，编辑菜单已在 AppDelegate 中设置
typealias PasteableTextField = NSTextField
typealias PasteableSecureTextField = NSSecureTextField

class AISettingsWindow: NSWindowController {
    static let shared = AISettingsWindow()

    private var baseURLField: PasteableTextField!
    private var modelField: PasteableTextField!
    private var apiKeyField: PasteableSecureTextField!
    private var apiKeyPlainField: PasteableTextField!
    private var showAPIKeyButton: NSButton!
    private var temperatureSlider: NSSlider!
    private var temperatureLabel: NSTextField!
    private var enabledCheckbox: NSButton!

    private var config: LLMConfig

    private init() {
        config = AIAnalysisManager.shared.loadConfig() ?? LLMConfig()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "AI分析设置"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)

        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let window = window else { return }

        // 主动请求剪贴板权限
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            _ = NSPasteboard.general.string(forType: .string)
        }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        var yPos: CGFloat = 420

        // 标题
        let titleLabel = NSTextField(labelWithString: "💡 AI工作洞察设置")
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.frame = NSRect(x: 20, y: yPos, width: 460, height: 30)
        contentView.addSubview(titleLabel)
        yPos -= 50

        // 启用开关
        enabledCheckbox = NSButton(checkboxWithTitle: "启用AI分析", target: self, action: #selector(enabledChanged))
        enabledCheckbox.state = config.enabled ? .on : .off
        enabledCheckbox.frame = NSRect(x: 20, y: yPos, width: 200, height: 24)
        contentView.addSubview(enabledCheckbox)
        yPos -= 40

        // API地址
        let baseURLLabel = NSTextField(labelWithString: "API地址:")
        baseURLLabel.frame = NSRect(x: 20, y: yPos, width: 460, height: 20)
        contentView.addSubview(baseURLLabel)
        yPos -= 25

        baseURLField = PasteableTextField(string: config.baseURL)
        baseURLField.placeholderString = "https://api.openai.com"
        baseURLField.frame = NSRect(x: 20, y: yPos, width: 460, height: 24)
        baseURLField.isEditable = true
        baseURLField.isSelectable = true
        contentView.addSubview(baseURLField)
        yPos -= 35

        // 模型
        let modelLabel = NSTextField(labelWithString: "模型:")
        modelLabel.frame = NSRect(x: 20, y: yPos, width: 460, height: 20)
        contentView.addSubview(modelLabel)
        yPos -= 25

        modelField = PasteableTextField(string: config.model)
        modelField.placeholderString = "gpt-4o-mini"
        modelField.frame = NSRect(x: 20, y: yPos, width: 460, height: 24)
        modelField.isEditable = true
        modelField.isSelectable = true
        contentView.addSubview(modelField)
        yPos -= 35

        // API Key
        let apiKeyLabel = NSTextField(labelWithString: "API Key:")
        apiKeyLabel.frame = NSRect(x: 20, y: yPos, width: 300, height: 20)
        contentView.addSubview(apiKeyLabel)

        showAPIKeyButton = NSButton(title: "显示", target: self, action: #selector(toggleAPIKeyVisibility))
        showAPIKeyButton.bezelStyle = .roundRect
        showAPIKeyButton.frame = NSRect(x: 400, y: yPos - 2, width: 80, height: 24)
        contentView.addSubview(showAPIKeyButton)
        yPos -= 25

        apiKeyField = PasteableSecureTextField(string: config.apiKey)
        apiKeyField.placeholderString = "sk-..."
        apiKeyField.frame = NSRect(x: 20, y: yPos, width: 460, height: 24)
        contentView.addSubview(apiKeyField)

        apiKeyPlainField = PasteableTextField(string: config.apiKey)
        apiKeyPlainField.placeholderString = "sk-..."
        apiKeyPlainField.frame = NSRect(x: 20, y: yPos, width: 460, height: 24)
        apiKeyPlainField.isEditable = true
        apiKeyPlainField.isSelectable = true
        apiKeyPlainField.isHidden = true
        contentView.addSubview(apiKeyPlainField)
        yPos -= 35

        // Temperature
        let tempLabel = NSTextField(labelWithString: "Temperature:")
        tempLabel.frame = NSRect(x: 20, y: yPos, width: 150, height: 20)
        contentView.addSubview(tempLabel)

        temperatureLabel = NSTextField(labelWithString: String(format: "%.1f", config.temperature))
        temperatureLabel.frame = NSRect(x: 440, y: yPos, width: 40, height: 20)
        temperatureLabel.alignment = .right
        contentView.addSubview(temperatureLabel)
        yPos -= 30

        temperatureSlider = NSSlider(value: config.temperature, minValue: 0, maxValue: 2, target: self, action: #selector(temperatureChanged))
        temperatureSlider.frame = NSRect(x: 20, y: yPos, width: 460, height: 24)
        contentView.addSubview(temperatureSlider)
        yPos -= 50

        // 隐私说明
        let privacyBox = NSBox(frame: NSRect(x: 20, y: yPos - 60, width: 460, height: 80))
        privacyBox.title = "🔒 隐私保护"
        privacyBox.titlePosition = .atTop

        let privacyText = NSTextField(wrappingLabelWithString: """
        • 仅发送工作统计数据（时长、操作次数等）
        • 不发送代码内容、文件名等敏感信息
        • 所有数据仅在本地处理
        """)
        privacyText.font = .systemFont(ofSize: 11)
        privacyText.frame = NSRect(x: 10, y: 5, width: 440, height: 60)
        privacyBox.contentView?.addSubview(privacyText)
        contentView.addSubview(privacyBox)

        // 底部按钮
        let saveButton = NSButton(title: "保存", target: self, action: #selector(saveConfig))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.frame = NSRect(x: 400, y: 20, width: 80, height: 32)
        contentView.addSubview(saveButton)

        let testButton = NSButton(title: "测试连接", target: self, action: #selector(testConnection))
        testButton.bezelStyle = .rounded
        testButton.frame = NSRect(x: 300, y: 20, width: 90, height: 32)
        contentView.addSubview(testButton)

        window.contentView = contentView
        updateFieldsEnabled()
    }

    @objc private func enabledChanged() {
        config.enabled = enabledCheckbox.state == .on
        updateFieldsEnabled()
    }

    @objc private func temperatureChanged() {
        config.temperature = temperatureSlider.doubleValue
        temperatureLabel.stringValue = String(format: "%.1f", config.temperature)
    }

    @objc private func toggleAPIKeyVisibility() {
        let isShowing = !apiKeyField.isHidden

        if isShowing {
            // 切换到隐藏
            apiKeyField.stringValue = apiKeyPlainField.stringValue
            apiKeyField.isHidden = false
            apiKeyPlainField.isHidden = true
            showAPIKeyButton.title = "显示"
        } else {
            // 切换到显示
            apiKeyPlainField.stringValue = apiKeyField.stringValue
            apiKeyField.isHidden = true
            apiKeyPlainField.isHidden = false
            showAPIKeyButton.title = "隐藏"
        }
    }

    @objc private func saveConfig() {
        config.baseURL = baseURLField.stringValue
        config.model = modelField.stringValue
        config.apiKey = apiKeyField.isHidden ? apiKeyPlainField.stringValue : apiKeyField.stringValue
        config.enabled = enabledCheckbox.state == .on
        config.temperature = temperatureSlider.doubleValue

        AIAnalysisManager.shared.saveConfig(config)

        let alert = NSAlert()
        alert.messageText = "保存成功"
        alert.informativeText = "AI分析配置已保存"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.beginSheetModal(for: window!) { _ in }
    }

    @objc private func testConnection() {
        let baseURL = baseURLField.stringValue
        let model = modelField.stringValue
        let apiKey = apiKeyField.isHidden ? apiKeyPlainField.stringValue : apiKeyField.stringValue

        if baseURL.isEmpty || apiKey.isEmpty {
            let alert = NSAlert()
            alert.messageText = "配置不完整"
            alert.informativeText = "请填写API地址和API Key"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "好的")
            alert.beginSheetModal(for: window!) { _ in }
            return
        }

        Task {
            await AIAnalysisManager.shared.testConnection(
                baseURL: baseURL,
                model: model,
                apiKey: apiKey
            )

            await MainActor.run {
                let alert = NSAlert()
                if let error = AIAnalysisManager.shared.lastError {
                    alert.messageText = "连接失败"
                    alert.informativeText = error
                    alert.alertStyle = .critical
                } else {
                    alert.messageText = "连接成功"
                    alert.informativeText = "API配置正常！"
                    alert.alertStyle = .informational
                }
                alert.addButton(withTitle: "好的")
                alert.beginSheetModal(for: self.window!) { _ in }
            }
        }
    }

    private func updateFieldsEnabled() {
        let enabled = config.enabled
        baseURLField.isEnabled = enabled
        modelField.isEnabled = enabled
        apiKeyField.isEnabled = enabled
        apiKeyPlainField.isEnabled = enabled
        showAPIKeyButton.isEnabled = enabled
        temperatureSlider.isEnabled = enabled
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // 确保第一个输入框获得焦点
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.window?.makeFirstResponder(self.baseURLField)
        }
    }
}
