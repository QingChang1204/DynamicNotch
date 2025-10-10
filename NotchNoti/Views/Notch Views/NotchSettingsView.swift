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
    @State private var historyCount = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            contentView

            // 关闭按钮
            closeButton
        }
        .frame(height: 160)
    }

    private var contentView: some View {
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

                Button(action: {
                    NotificationConfigWindowManager.shared.show()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("消息配置")
                    }
                    .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)

                Spacer()
            }

            HStack {
                Text("通知历史记录:")
                    .foregroundColor(.secondary)

                Text("\(historyCount) / 50")
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
        }
        .padding()
        .transition(AnyTransition.scale(scale: 0.8).combined(with: .opacity))
        .task {
            let history = await NotificationManager.shared.getHistory(page: 0, pageSize: 50)
            historyCount = history.count
        }
    }

    private var closeButton: some View {
        Button(action: {
            vm.returnToNormal()
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.3))
                .padding(6)
                .background(Circle().fill(Color.black.opacity(0.01)))
                .contentShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(8)
        .zIndex(100)
    }
}

#Preview {
    NotchSettingsView(vm: NotchViewModel())
        .padding()
        .frame(width: 600, height: 150, alignment: .center)
        .background(Color.black)
        .preferredColorScheme(.dark)
}
