//
//  NotchContentView.swift
//  NotchNoti
//
//  Created by 秋星桥 on 2024/7/7.
//

import ColorfulX
import SwiftUI

struct NotchContentView: View {
    @StateObject var vm: NotchViewModel
    @State private var currentNotification: NotchNotification?
    @State private var showNotification = false

    var body: some View {
        ZStack {
            if let currentNotification = currentNotification,
               showNotification {
                NotificationView(notification: currentNotification)
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            } else {
                switch vm.contentType {
                case .normal:
                    // 显示紧凑型通知中心
                    CompactNotificationHistoryView()
                        .transition(AnyTransition.scale(scale: 0.8).combined(with: .opacity))
                case .menu:
                    NotchMenuView(vm: vm)
                        .transition(AnyTransition.scale(scale: 0.8).combined(with: .opacity))
                case .settings:
                    NotchSettingsView(vm: vm)
                        .transition(AnyTransition.scale(scale: 0.8).combined(with: .opacity))
                case .stats:
                    GlobalStatsView()
                        .transition(AnyTransition.scale(scale: 0.8).combined(with: .opacity))
                case .history:
                    CompactNotificationHistoryView()
                        .transition(AnyTransition.scale(scale: 0.8).combined(with: .opacity))
                case .aiAnalysis:
                    CompactAIAnalysisView()
                        .transition(AnyTransition.scale(scale: 0.8).combined(with: .opacity))
                case .summaryHistory:
                    CompactSummaryListView()
                        .transition(AnyTransition.scale(scale: 0.8).combined(with: .opacity))
                }
            }
        }
        .animation(vm.animation, value: vm.contentType)
        .animation(vm.animation, value: showNotification)
        .onReceive(NotificationCenter.default.publisher(for: .notificationDidUpdate)) { _ in
            print("[NotchContentView] Received .notificationDidUpdate event")
            // 响应式更新通知状态
            Task {
                let notification = await NotificationManager.shared.currentNotification
                let shouldShow = await NotificationManager.shared.showNotification
                print("[NotchContentView] Updated: notification=\(notification?.title ?? "nil"), show=\(shouldShow)")
                currentNotification = notification
                showNotification = shouldShow
            }
        }
        .task {
            // 初始加载当前通知状态
            currentNotification = await NotificationManager.shared.currentNotification
            showNotification = await NotificationManager.shared.showNotification
            print("[NotchContentView] Initial load: notification=\(currentNotification?.title ?? "nil"), show=\(showNotification)")
        }
    }
}

#Preview {
    NotchContentView(vm: .init())
        .padding()
        .frame(width: 600, height: 150, alignment: .center)
        .background(.black)
        .preferredColorScheme(.dark)
}
