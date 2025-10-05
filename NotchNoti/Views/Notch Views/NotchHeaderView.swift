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
    @State private var historyCount = 0

    var body: some View {
        Group {
            // 统计、AI洞察、历史页面不显示header
            if vm.contentType == .stats || vm.contentType == .aiAnalysis || vm.contentType == .history {
                EmptyView()
            } else {
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
                        Text(historyCount == 0 ? "通知中心" : "通知历史 (\(historyCount))")
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
                        } else if historyCount > 0 && vm.contentType != .settings && vm.contentType != .summaryHistory {
                            Button(action: {
                                Task {
                                    await NotificationManager.shared.clearHistory()
                                    historyCount = 0
                                }
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
                .animation(vm.animation, value: historyCount)
                .font(.system(.headline, design: .rounded))
            }
        }
        .task {
            // Update history count periodically
            while true {
                let history = await NotificationManager.shared.getHistory(page: 0, pageSize: 50)
                historyCount = history.count
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }
}

#Preview {
    NotchHeaderView(vm: .init())
}
