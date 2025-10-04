//
//  NotchViewModel+Events.swift
//  NotchNoti
//
//  Created by 秋星桥 on 2024/7/8.
//

import Cocoa
import Combine
import Foundation
import SwiftUI

extension NotchViewModel {
    func setupCancellables() {
        let events = EventMonitors.shared
        events.mouseDown
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let mouseLocation: NSPoint = NSEvent.mouseLocation
                switch status {
                case .opened:
                    // 如果正在显示通知，延迟关闭以确保用户能看到内容
                    let hasActiveNotification = NotificationManager.shared.showNotification
                    let minimumDisplayTime: TimeInterval = hasActiveNotification ? 0.7 : 0

                    // 统计视图需要精确点击，禁用外部点击关闭（只能通过关闭按钮关闭）
                    let isStatsView = contentType == .stats

                    // touch outside, close
                    if !notchOpenedRect.contains(mouseLocation) {
                        // 统计视图不响应外部点击关闭
                        if isStatsView {
                            return
                        }

                        if hasActiveNotification {
                            // 给通知一个最小显示时间
                            DispatchQueue.main.asyncAfter(deadline: .now() + minimumDisplayTime) { [weak self] in
                                self?.notchClose()
                            }
                        } else {
                            notchClose()
                        }
                        // click where user open the panel
                    } else if deviceNotchRect.insetBy(dx: inset, dy: inset).contains(mouseLocation) {
                        if hasActiveNotification {
                            DispatchQueue.main.asyncAfter(deadline: .now() + minimumDisplayTime) { [weak self] in
                                self?.notchClose()
                            }
                        } else {
                            notchClose()
                        }
                        // for the same height as device notch, open the url of project
                    } else if headlineOpenedRect.contains(mouseLocation) {
                        // 统计、AI洞察、设置等特殊视图禁用headline切换（避免误触）
                        let specialViews: [ContentType] = [.stats, .aiAnalysis, .settings, .summaryHistory, .history]
                        if specialViews.contains(contentType) {
                            return
                        }

                        // for clicking headline - toggle menu
                        contentType = contentType == .menu ? .normal : .menu
                    }
                case .closed, .popping:
                    // touch inside, open
                    if deviceNotchRect.insetBy(dx: inset, dy: inset).contains(mouseLocation) {
                        notchOpen(.click)
                    }
                }
            }
            .store(in: &cancellables)

        events.optionKeyPress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] input in
                guard let self else { return }
                optionKeyPressed = input
            }
            .store(in: &cancellables)

        events.mouseLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mouseLocation in
                guard let self else { return }
                let mouseLocation: NSPoint = NSEvent.mouseLocation
                let aboutToOpen = deviceNotchRect.insetBy(dx: inset, dy: inset).contains(mouseLocation)
                if status == .closed, aboutToOpen { notchPop() }
                if status == .popping, !aboutToOpen { notchClose() }
            }
            .store(in: &cancellables)

        $status
            .filter { $0 != .closed }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                withAnimation { self?.notchVisible = true }
            }
            .store(in: &cancellables)

        $status
            .filter { $0 == .popping }
            .throttle(for: .seconds(0.5), scheduler: DispatchQueue.main, latest: false)
            .sink { [weak self] _ in
                guard NSEvent.pressedMouseButtons == 0 else { return }
                self?.hapticSender.send()
            }
            .store(in: &cancellables)

        hapticSender
            .throttle(for: .seconds(0.5), scheduler: DispatchQueue.main, latest: false)
            .sink { [weak self] _ in
                guard self?.hapticFeedback ?? false else { return }
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .levelChange,
                    performanceTime: .now
                )
            }
            .store(in: &cancellables)

        $status
            .debounce(for: 0.5, scheduler: DispatchQueue.global())
            .filter { $0 == .closed }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                withAnimation {
                    self?.notchVisible = false
                }
            }
            .store(in: &cancellables)

        $selectedLanguage
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] output in
                self?.notchClose()
                output.apply()
            }
            .store(in: &cancellables)
    }

    func destroy() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}
