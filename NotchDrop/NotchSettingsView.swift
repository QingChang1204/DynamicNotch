//
//  NotchSettingsView.swift
//  NotchDrop
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
                Picker("Language: ", selection: $vm.selectedLanguage) {
                    ForEach(Language.allCases) { language in
                        Text(language.localized).tag(language)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: vm.selectedLanguage == .simplifiedChinese || vm.selectedLanguage == .traditionalChinese ? 220 : 160)

                Spacer()
                LaunchAtLogin.Toggle {
                    Text(NSLocalizedString("Launch at Login", comment: ""))
                }

                Spacer()
                Toggle("Haptic Feedback", isOn: $vm.hapticFeedback)

                Spacer()
            }

            HStack {
                Text("通知历史记录:")
                    .foregroundColor(.secondary)
                
                Text("\(notificationManager.notificationHistory.count) / 100")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                Text("服务器状态:")
                    .foregroundColor(.secondary)
                
                Text(NotificationServer.shared.isRunning ? "运行中 (端口 9876)" : "未运行")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(NotificationServer.shared.isRunning ? .green : .red)
                
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
