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
                    if NotificationServer.shared.isRunning {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                            Text("HTTP :9876")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
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
