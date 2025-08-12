//
//  NotchHeaderView.swift
//  NotchDrop
//
//  Created by 秋星桥 on 2024/7/7.
//

import ColorfulX
import SwiftUI

struct NotchHeaderView: View {
    @StateObject var vm: NotchViewModel
    @ObservedObject var notificationManager = NotificationManager.shared

    var body: some View {
        HStack {
            if vm.contentType == .settings {
                Text("Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown") (Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"))")
                    .contentTransition(.numericText())
            } else {
                // 动态显示通知历史或通知中心
                Text(notificationManager.notificationHistory.isEmpty ? "通知中心" : "通知历史 (\(notificationManager.notificationHistory.count))")
                    .contentTransition(.numericText())
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // 清空按钮 - 只在有通知历史时显示
                if !notificationManager.notificationHistory.isEmpty && vm.contentType != .settings {
                    Button(action: {
                        notificationManager.clearHistory()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
                
                // 设置按钮
                Image(systemName: "ellipsis")
            }
        }
        .animation(vm.animation, value: vm.contentType)
        .animation(vm.animation, value: notificationManager.notificationHistory.count)
        .font(.system(.headline, design: .rounded))
    }
}

#Preview {
    NotchHeaderView(vm: .init())
}
