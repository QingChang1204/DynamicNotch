//
//  NotchContentView.swift
//  NotchDrop
//
//  Created by 秋星桥 on 2024/7/7.
//

import ColorfulX
import SwiftUI

struct NotchContentView: View {
    @StateObject var vm: NotchViewModel
    @ObservedObject var notificationManager = NotificationManager.shared

    var body: some View {
        ZStack {
            if let currentNotification = notificationManager.currentNotification,
               notificationManager.showNotification {
                NotificationView(notification: currentNotification)
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            } else {
                switch vm.contentType {
                case .normal:
                    // 显示通知中心主界面
                    NotificationCenterMainView()
                        .transition(AnyTransition.scale(scale: 0.8).combined(with: .opacity))
                case .menu:
                    NotchMenuView(vm: vm)
                        .transition(AnyTransition.scale(scale: 0.8).combined(with: .opacity))
                case .settings:
                    NotchSettingsView(vm: vm)
                        .transition(AnyTransition.scale(scale: 0.8).combined(with: .opacity))
                case .history:
                    // 历史页面直接使用通知中心主界面
                    NotificationCenterMainView()
                        .transition(AnyTransition.scale(scale: 0.8).combined(with: .opacity))
                }
            }
        }
        .animation(vm.animation, value: vm.contentType)
        .animation(vm.animation, value: notificationManager.showNotification)
    }
}

#Preview {
    NotchContentView(vm: .init())
        .padding()
        .frame(width: 600, height: 150, alignment: .center)
        .background(.black)
        .preferredColorScheme(.dark)
}
