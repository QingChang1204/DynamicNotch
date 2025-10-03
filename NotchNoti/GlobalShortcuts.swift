//
//  GlobalShortcuts.swift
//  NotchNoti
//
//  全局键盘快捷键支持
//

import Cocoa
import Carbon

class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()

    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef?] = []

    // 快捷键定义
    enum Shortcut: UInt32 {
        case toggleNotch = 1  // ⌘K
        case clearHistory = 2  // ⌘D
        case showStats = 3     // ⌘S
        case showHistory = 4   // ⌘H
    }

    private init() {}

    func registerShortcuts() {
        // 创建事件处理器
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(theEvent, UInt32(kEventParamDirectObject), UInt32(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)

            GlobalShortcutManager.shared.handleHotKey(id: hotKeyID.id)

            return noErr
        }, 1, &eventSpec, nil, &eventHandler)

        // 注册快捷键
        registerHotKey(.toggleNotch, keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey))  // ⌘K
        registerHotKey(.clearHistory, keyCode: UInt32(kVK_ANSI_D), modifiers: UInt32(cmdKey))  // ⌘D
        registerHotKey(.showStats, keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(cmdKey))    // ⌘S
        registerHotKey(.showHistory, keyCode: UInt32(kVK_ANSI_H), modifiers: UInt32(cmdKey))  // ⌘H
    }

    private func registerHotKey(_ shortcut: Shortcut, keyCode: UInt32, modifiers: UInt32) {
        var hotKeyID = EventHotKeyID(signature: OSType(0x4E4F5443), id: shortcut.rawValue)  // 'NOTC'
        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            hotKeyRefs.append(hotKeyRef)
            print("✅ 注册快捷键成功: \(shortcut)")
        } else {
            print("❌ 注册快捷键失败: \(shortcut) (status: \(status))")
        }
    }

    private func handleHotKey(id: UInt32) {
        guard let shortcut = Shortcut(rawValue: id) else { return }

        DispatchQueue.main.async {
            guard let vm = NotchViewModel.shared else { return }

            switch shortcut {
            case .toggleNotch:
                // ⌘K - 切换刘海开关
                if vm.status == .closed {
                    vm.notchOpen(.click)  // 使用 .click 作为快捷键触发
                } else {
                    vm.notchClose()
                }

            case .clearHistory:
                // ⌘D - 清空历史
                if vm.status != .closed {
                    NotificationManager.shared.clearHistory()
                    // 发送反馈
                    vm.hapticSender.send()
                }

            case .showStats:
                // ⌘S - 显示统计
                if vm.status == .closed {
                    vm.notchOpen(.click)
                }
                vm.contentType = .stats

            case .showHistory:
                // ⌘H - 显示历史
                if vm.status == .closed {
                    vm.notchOpen(.click)
                }
                vm.contentType = .history
            }
        }
    }

    func unregisterShortcuts() {
        hotKeyRefs.forEach { ref in
            if let ref = ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    deinit {
        unregisterShortcuts()
    }
}
