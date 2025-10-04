//
//  NotificationConfigWindow.swift
//  NotchNoti
//
//  消息配置独立窗口 - 视觉统一设计
//

import SwiftUI
import Cocoa

// MARK: - 窗口管理器

class NotificationConfigWindowManager {
    static let shared = NotificationConfigWindowManager()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let configView = NotificationConfigWindowView()
            let hostingController = NSHostingController(rootView: configView)

            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 650),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            newWindow.title = "消息配置"
            newWindow.titlebarAppearsTransparent = true
            newWindow.titleVisibility = .hidden
            newWindow.center()
            newWindow.isReleasedWhenClosed = false
            newWindow.contentView = hostingController.view
            newWindow.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.95)
            newWindow.minSize = NSSize(width: 600, height: 500)

            window = newWindow
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - SwiftUI主视图

struct NotificationConfigWindowView: View {
    @ObservedObject private var configManager = NotificationConfigManager.shared
    @ObservedObject private var vm = NotchViewModel.shared ?? NotchViewModel()
    @State private var selectedTab: ConfigTab = .global
    @State private var selectedType: NotchNotification.NotificationType = .info
    @State private var showSaveSuccess = false
    @State private var searchText = ""

    enum ConfigTab: String, CaseIterable {
        case global = "全局设置"
        case types = "类型配置"
        case rules = "静默规则"
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

            VStack(spacing: 0) {
                // 顶部标题区
                headerSection
                    .padding(.top, 30)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)

                // 分段控制器（简单按钮组，避免系统样式问题）
                HStack(spacing: 8) {
                    ForEach(ConfigTab.allCases, id: \.self) { tab in
                        Button(action: {
                            selectedTab = tab
                        }) {
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .medium))
                                .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(selectedTab == tab ? Color.blue : Color.white.opacity(0.05))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 16)

                Divider()
                    .background(Color.white.opacity(0.1))

                // 内容区域
                ScrollView {
                    contentSection
                        .padding(30)
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                // 底部操作栏
                footerSection
                    .padding(.horizontal, 30)
                    .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 头部区域

    @ViewBuilder
    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 4)

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("消息配置")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Text("细粒度控制通知行为，优化工作体验")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.65))
            }

            Spacer()

            // 全局开关
            VStack(alignment: .trailing, spacing: 4) {
                Toggle(isOn: $configManager.globalEnabled) {
                    Text("")
                }
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .scaleEffect(0.9)

                Text(configManager.globalEnabled ? "已启用" : "已禁用")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(configManager.globalEnabled ? .green : .red)
            }
        }
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var contentSection: some View {
        switch selectedTab {
        case .global:
            globalConfigSection
        case .types:
            typesConfigSection
        case .rules:
            rulesConfigSection
        }
    }

    // MARK: - 全局配置

    @ViewBuilder
    private var globalConfigSection: some View {
        VStack(spacing: 24) {
            // 基础设置卡片
            ConfigCard(title: "基础设置", icon: "gear", color: .blue) {
                VStack(spacing: 16) {
                    ConfigRow(
                        icon: "speaker.wave.3.fill",
                        title: "通知声音",
                        subtitle: "播放类型对应的系统声音"
                    ) {
                        Toggle("", isOn: $configManager.globalSoundEnabled)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }

                    Divider().background(Color.white.opacity(0.2))

                    ConfigRow(
                        icon: "hand.tap.fill",
                        title: "触觉反馈",
                        subtitle: "通知显示时触发触觉反馈"
                    ) {
                        Toggle("", isOn: $configManager.globalHapticEnabled)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }

                    Divider().background(Color.white.opacity(0.2))

                    ConfigRow(
                        icon: "moon.zzz.fill",
                        title: "勿扰模式中显示",
                        subtitle: "在系统勿扰模式下仍然显示通知"
                    ) {
                        Toggle("", isOn: $configManager.showInDoNotDisturb)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                }
            }

            // 显示时长卡片
            ConfigCard(title: "显示时长", icon: "timer", color: .orange) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("默认显示时长")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))

                        Spacer()

                        Text("\(String(format: "%.1f", configManager.defaultDuration))s")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.2))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(8)
                    }

                    Slider(value: $configManager.defaultDuration, in: 0.5...5.0, step: 0.5)
                        .tint(.orange)

                    Text("此时长将应用于未自定义显示时长的通知类型")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            // 智能合并卡片
            ConfigCard(title: "智能合并", icon: "square.stack.3d.down.right.fill", color: .purple) {
                VStack(spacing: 16) {
                    ConfigRow(
                        icon: "link.circle.fill",
                        title: "启用智能合并",
                        subtitle: "相同来源的通知在时间窗口内自动合并"
                    ) {
                        Toggle("", isOn: $configManager.smartMergeEnabled)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: .purple))
                    }

                    if configManager.smartMergeEnabled {
                        Divider().background(Color.white.opacity(0.2))

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("合并时间窗口")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))

                                Spacer()

                                Text("\(String(format: "%.1f", configManager.mergeTimeWindow))s")
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(red: 0.85, green: 0.6, blue: 1.0))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.2))
                                    .cornerRadius(8)
                            }

                            Slider(value: $configManager.mergeTimeWindow, in: 0.1...2.0, step: 0.1)
                                .tint(.purple)

                            Text("通知间隔小于此时间时将合并为一条显示")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
        }
    }

    // MARK: - 类型配置

    @ViewBuilder
    private var typesConfigSection: some View {
        HStack(spacing: 20) {
            // 左侧类型列表
            VStack(alignment: .leading, spacing: 12) {
                Text("通知类型")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 4)

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(NotchNotification.NotificationType.allCases, id: \.self) { type in
                            typeListItem(type)
                        }
                    }
                }
            }
            .frame(width: 180)

            Divider()
                .background(Color.white.opacity(0.2))

            // 右侧类型详情
            typeDetailSection(for: selectedType)
        }
    }

    private func typeListItem(_ type: NotchNotification.NotificationType) -> some View {
        let config = configManager.getTypeConfig(for: type)
        let isSelected = selectedType == type

        return Button(action: {
            selectedType = type
        }) {
            HStack(spacing: 10) {
                Image(systemName: NotchNotification(title: "", message: "", type: type).systemImage)
                    .font(.system(size: 16))
                    .foregroundColor(config.enabled ?
                        NotchNotification(title: "", message: "", type: type).color : .gray)
                    .frame(width: 24)

                Text(type.localizedName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(config.enabled ? .white : .white.opacity(0.5))

                Spacer()

                Circle()
                    .fill(config.enabled ? Color.green : Color.red.opacity(0.5))
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func typeDetailSection(for type: NotchNotification.NotificationType) -> some View {
        let binding = Binding(
            get: { configManager.getTypeConfig(for: type) },
            set: { configManager.setTypeConfig($0, for: type) }
        )

        VStack(alignment: .leading, spacing: 20) {
            // 类型标题
            HStack(spacing: 12) {
                Image(systemName: NotchNotification(title: "", message: "", type: type).systemImage)
                    .font(.system(size: 28))
                    .foregroundColor(NotchNotification(title: "", message: "", type: type).color)

                VStack(alignment: .leading, spacing: 4) {
                    Text(type.localizedName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text("配置此类型通知的行为")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.75))
                }

                Spacer()

                Button(action: {
                    configManager.resetTypeConfig(for: type)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12))
                        Text("重置")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Divider().background(Color.white.opacity(0.2))

            // 配置选项
            VStack(spacing: 16) {
                ConfigRow(
                    icon: "power.circle.fill",
                    title: "启用此类型",
                    subtitle: "禁用后此类型通知将被完全过滤"
                ) {
                    Toggle("", isOn: Binding(
                        get: { binding.wrappedValue.enabled },
                        set: { enabled in
                            var config = binding.wrappedValue
                            config.enabled = enabled
                            binding.wrappedValue = config
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                }

                Divider().background(Color.white.opacity(0.2))

                ConfigRow(
                    icon: "speaker.wave.2.fill",
                    title: "声音",
                    subtitle: "播放此类型的系统声音"
                ) {
                    Toggle("", isOn: Binding(
                        get: { binding.wrappedValue.soundEnabled },
                        set: { enabled in
                            var config = binding.wrappedValue
                            config.soundEnabled = enabled
                            binding.wrappedValue = config
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .disabled(!binding.wrappedValue.enabled || !configManager.globalSoundEnabled)
                }

                Divider().background(Color.white.opacity(0.2))

                ConfigRow(
                    icon: "hand.tap.fill",
                    title: "触觉反馈",
                    subtitle: "显示通知时触发触觉反馈"
                ) {
                    Toggle("", isOn: Binding(
                        get: { binding.wrappedValue.hapticEnabled },
                        set: { enabled in
                            var config = binding.wrappedValue
                            config.hapticEnabled = enabled
                            binding.wrappedValue = config
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .disabled(!binding.wrappedValue.enabled || !configManager.globalHapticEnabled)
                }

                Divider().background(Color.white.opacity(0.2))

                // 自定义时长
                VStack(alignment: .leading, spacing: 12) {
                    ConfigRow(
                        icon: "timer",
                        title: "自定义显示时长",
                        subtitle: "覆盖全局默认时长"
                    ) {
                        Toggle("", isOn: Binding(
                            get: { binding.wrappedValue.customDuration != nil },
                            set: { enabled in
                                var config = binding.wrappedValue
                                config.customDuration = enabled ? 1.0 : nil
                                binding.wrappedValue = config
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                        .disabled(!binding.wrappedValue.enabled)
                    }

                    if binding.wrappedValue.customDuration != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("显示时长")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.7))

                                Spacer()

                                Text("\(String(format: "%.1f", binding.wrappedValue.customDuration ?? 1.0))s")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.2))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(6)
                            }

                            Slider(
                                value: Binding(
                                    get: { binding.wrappedValue.customDuration ?? 1.0 },
                                    set: { duration in
                                        var config = binding.wrappedValue
                                        config.customDuration = duration
                                        binding.wrappedValue = config
                                    }
                                ),
                                in: 0.5...5.0,
                                step: 0.5
                            )
                            .tint(.orange)
                        }
                        .padding(.leading, 36)
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    // MARK: - 规则配置

    @ViewBuilder
    private var rulesConfigSection: some View {
        VStack(spacing: 20) {
            // 规则说明
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.cyan)

                Text("静默规则允许你根据条件自动过滤或静音特定通知")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(16)
            .background(Color.cyan.opacity(0.15))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
            )

            // 预设规则按钮
            VStack(alignment: .leading, spacing: 12) {
                Text("预设规则模板")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(NotificationConfigManager.PresetRule.allCases, id: \.self) { preset in
                        presetRuleButton(preset)
                    }
                }
            }

            Divider().background(Color.white.opacity(0.2))

            // 当前规则列表
            if configManager.silentRules.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.3))

                    Text("暂无自定义规则")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.65))

                    Text("点击上方预设模板快速添加规则")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("已启用的规则 (\(configManager.silentRules.count))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))

                    VStack(spacing: 8) {
                        ForEach(Array(configManager.silentRules.enumerated()), id: \.element.id) { index, rule in
                            ruleListItem(rule, index: index)
                        }
                    }
                }
            }
        }
    }

    private func presetRuleButton(_ preset: NotificationConfigManager.PresetRule) -> some View {
        Button(action: {
            let rule = NotificationConfigManager.createPresetRule(preset)
            configManager.silentRules.append(rule)
        }) {
            HStack(spacing: 8) {
                Image(systemName: presetIcon(for: preset))
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 24)

                Text(preset.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func presetIcon(for preset: NotificationConfigManager.PresetRule) -> String {
        switch preset {
        case .nightMode: return "moon.stars.fill"
        case .workHours: return "briefcase.fill"
        case .errorsOnly: return "exclamationmark.triangle.fill"
        case .focusMode: return "eye.slash.fill"
        }
    }

    private func ruleListItem(_ rule: SilentRule, index: Int) -> some View {
        HStack(spacing: 12) {
            // 规则图标
            Circle()
                .fill(rule.enabled ? Color.orange : Color.gray)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(rule.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(rule.enabled ? .white : .white.opacity(0.5))

                Text("\(rule.conditions.count)个条件 • \(actionText(rule.action))")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.65))
            }

            Spacer()

            // 启用开关
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { enabled in
                    configManager.silentRules[index].enabled = enabled
                }
            ))
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: .orange))

            // 删除按钮
            Button(action: {
                configManager.silentRules.remove(at: index)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func actionText(_ action: SilentRule.RuleAction) -> String {
        switch action {
        case .silence: return "完全静默"
        case .muteSound: return "仅静音"
        case .muteHaptic: return "禁用触觉"
        case .showInQueue: return "加入队列"
        }
    }

    // MARK: - 底部操作栏

    @ViewBuilder
    private var footerSection: some View {
        HStack(spacing: 16) {
            if showSaveSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("配置已自动保存")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .transition(.opacity)
            }

            Spacer()

            Button(action: {
                configManager.resetAllConfigs()
                showSaveSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showSaveSuccess = false
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13))
                    Text("全部重置")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - 配置卡片组件

struct ConfigCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            content()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - 配置行组件

struct ConfigRow<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let control: () -> Content

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.65))
            }

            Spacer()

            control()
        }
    }
}
