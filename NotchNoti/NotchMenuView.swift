//
//  NotchMenuView.swift
//  NotchNoti
//
//  Created by 秋星桥 on 2024/7/11.
//

import ColorfulX
import SwiftUI

struct NotchMenuView: View {
    @StateObject var vm: NotchViewModel
    @ObservedObject var notificationManager = NotificationManager.shared

    var body: some View {
        HStack(spacing: vm.spacing * 1.5) {
            history
            stats
            aiAnalysis
            moreMenu
        }
    }

    // 新增：AI分析按钮
    var aiAnalysis: some View {
        ColorButton(
            color: [.purple, .pink],
            image: Image(systemName: "sparkles"),
            title: "AI分析"
        )
        .onTapGesture {
            vm.showAIAnalysis()
        }
        .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius))
    }

    // 新增：更多菜单
    var moreMenu: some View {
        Menu {
            Button(action: {
                vm.showSettings()
            }) {
                Label("偏好设置", systemImage: "gear")
            }

            Button(action: {
                let result = ClaudeCodeSetup.shared.setupClaudeCodeHooks()
                ClaudeCodeSetup.shared.showSetupResult(result)
                if result.success {
                    vm.notchClose()
                }
            }) {
                Label("配置Claude Code", systemImage: "link.circle")
            }

            Divider()

            Button(action: {
                notificationManager.clearHistory()
                vm.notchClose()
            }) {
                Label("清空历史", systemImage: "trash")
            }

            Button(action: {
                StatisticsManager.shared.sessionHistory.removeAll()
                StatisticsManager.shared.currentSession = nil
                vm.notchClose()
            }) {
                Label("清空统计", systemImage: "chart.bar.xaxis")
            }

            Divider()

            Button(action: {
                if let url = URL(string: "https://github.com/QingChang1204/DynamicNotch") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Label("关于NotchNoti", systemImage: "info.circle")
            }

            Button(action: {
                vm.notchClose()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    NSApp.terminate(nil)
                }
            }) {
                Label("退出应用", systemImage: "power")
            }
        } label: {
            ColorButton(
                color: [.gray, .secondary],
                image: Image(systemName: "ellipsis"),
                title: "菜单"
            )
        }
        .menuStyle(.borderlessButton)
        .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius))
    }

    
    var history: some View {
        ColorButton(
            color: ColorfulPreset.colorful.colors,
            image: Image(systemName: "bell.badge"),
            title: LocalizedStringKey("History")
        )
        .onTapGesture {
            vm.contentType = .history
        }
        .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius))
    }

    var stats: some View {
        ColorButton(
            color: [.cyan, .blue],
            image: Image(systemName: "chart.bar.fill"),
            title: "统计"
        )
        .onTapGesture {
            vm.showStats()
        }
        .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius))
    }
}

private struct ColorButton: View {
    let color: [Color]
    let image: Image
    let title: LocalizedStringKey

    @State var hover: Bool = false

    var body: some View {
        Color.white
            .opacity(0.1)
            .overlay(
                ColorfulView(
                    color: .constant(color),
                    speed: .constant(0)
                )
                .mask {
                    VStack(spacing: 8) {
                        Text("888888")
                            .hidden()
                            .overlay {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            }
                        Text(title)
                    }
                    .font(.system(.headline, design: .rounded))
                }
                .contentShape(Rectangle())
                .scaleEffect(hover ? 1.05 : 1)
                .animation(.spring, value: hover)
                .onHover { hover = $0 }
            )
            .aspectRatio(1, contentMode: .fit)
            .contentShape(Rectangle())
    }
}

#Preview {
    NotchMenuView(vm: .init())
        .padding()
        .frame(width: 600, height: 150, alignment: .center)
        .background(.black)
        .preferredColorScheme(.dark)
}
