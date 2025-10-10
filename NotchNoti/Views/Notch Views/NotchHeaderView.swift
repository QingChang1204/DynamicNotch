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
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        Group {
            // 统计、AI洞察、历史、设置页面不显示header（这些页面有自己的关闭按钮）
            if vm.contentType == .stats || vm.contentType == .aiAnalysis || vm.contentType == .history || vm.contentType == .settings {
                EmptyView()
            } else {
                HStack(spacing: 12) {
                    // 根据不同的内容类型显示不同的标题
                    Group {
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
                    }
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                    Spacer(minLength: 8)

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
                .font(.system(.headline, design: .rounded))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationDidUpdate)) { _ in
            // 防抖：取消之前的更新任务
            debounceTask?.cancel()

            // 延迟300ms更新，避免频繁刷新触发布局抖动
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }

                let updatedHistory = await NotificationManager.shared.getHistory(page: 0, pageSize: 50)
                historyCount = updatedHistory.count
            }
        }
        .task {
            // 初始加载历史记录数量
            let history = await NotificationManager.shared.getHistory(page: 0, pageSize: 50)
            historyCount = history.count
        }
    }
}

#Preview {
    NotchHeaderView(vm: .init())
}
