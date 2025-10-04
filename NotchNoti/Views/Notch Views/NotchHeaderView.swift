//
//  NotchHeaderView.swift
//  NotchNoti
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
            // 根据不同的内容类型显示不同的标题
            switch vm.contentType {
            case .settings:
                Text("Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown") (Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"))")
                    .contentTransition(.numericText())
            case .summaryHistory:
                Text("Session总结 (\(SessionSummaryManager.shared.recentSummaries.count))")
                    .contentTransition(.numericText())
            default:
                // 动态显示通知历史或通知中心
                Text(notificationManager.notificationHistory.isEmpty ? "通知中心" : "通知历史 (\(notificationManager.notificationHistory.count))")
                    .contentTransition(.numericText())
            }

            Spacer()

            HStack(spacing: 12) {
                // 清空按钮 - 根据不同视图显示
                if vm.contentType == .summaryHistory && !SessionSummaryManager.shared.recentSummaries.isEmpty {
                    Button(action: {
                        SessionSummaryManager.shared.recentSummaries.removeAll()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                } else if !notificationManager.notificationHistory.isEmpty && vm.contentType != .settings && vm.contentType != .summaryHistory {
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
