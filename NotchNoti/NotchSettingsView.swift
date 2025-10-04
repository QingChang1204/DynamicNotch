//
//  NotchSettingsView.swift
//  NotchNoti
//
//  Created by 曹丁杰 on 2024/7/29.
//

import LaunchAtLogin
import SwiftUI

struct NotchSettingsView: View {
    @StateObject var vm: NotchViewModel
    @ObservedObject var notificationManager = NotificationManager.shared

    var body: some View {
        VStack(spacing: vm.spacing) {
            HStack {
                Picker("语言: ", selection: $vm.selectedLanguage) {
                    ForEach(Language.allCases) { language in
                        Text(language.localized).tag(language)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: vm.selectedLanguage == .simplifiedChinese || vm.selectedLanguage == .traditionalChinese ? 220 : 160)

                Spacer()
                LaunchAtLogin.Toggle {
                    Text("开机启动")
                }

                Spacer()
                Toggle("触觉反馈", isOn: $vm.hapticFeedback)
                
                Spacer()
                Toggle("通知声音", isOn: $vm.notificationSound)

                Spacer()
            }

            HStack {
                Text("通知历史记录:")
                    .foregroundColor(.secondary)

                Text("\(notificationManager.notificationHistory.count) / 50")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Text("连接方式:")
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    if UnixSocketServerSimple.shared.isRunning {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Unix Socket")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.green)
                        }
                    }
                }

                Spacer()
            }

            Divider()
                .padding(.vertical, 4)

            // Claude Code 集成
            VStack(alignment: .leading, spacing: 8) {
                Text("Claude Code 集成")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    // Hooks 配置按钮
                    Button(action: {
                        let result = ClaudeCodeSetup.shared.setupClaudeCodeHooks()
                        ClaudeCodeSetup.shared.showSetupResult(result)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "link.circle.fill")
                                .font(.system(size: 12))
                            Text("配置 Hooks")
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // MCP 配置复制按钮
                    Button(action: {
                        if ClaudeCodeSetup.shared.copyMCPConfigToClipboard() {
                            ClaudeCodeSetup.shared.showMCPConfigCopied()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.clipboard.fill")
                                .font(.system(size: 12))
                            Text("复制 MCP 配置")
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    // 说明文本
                    Text("Hooks: 被动监控 | MCP: 主动控制")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .transition(AnyTransition.scale(scale: 0.8).combined(with: .opacity))
    }
}

#Preview {
    NotchSettingsView(vm: NotchViewModel())
        .padding()
        .frame(width: 600, height: 150, alignment: .center)
        .background(Color.black)
        .preferredColorScheme(.dark)
}
