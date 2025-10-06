//
//  AppDelegate.swift
//  NotchNoti
//
//  Created by 秋星桥 on 2024/7/7.
//

import Cocoa
import LaunchAtLogin

class AppDelegate: NSObject, NSApplicationDelegate {
    var isFirstOpen = true
    var isLaunchedAtLogin = false
    var mainWindowController: NotchWindowController?

    // 使用 weak var 避免循环引用
    private var timer: Timer?

    func applicationDidFinishLaunching(_: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildApplicationWindows),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSApp.setActivationPolicy(.accessory)

        // 创建标准编辑菜单以支持复制粘贴
        setupEditMenu()

        isLaunchedAtLogin = LaunchAtLogin.wasLaunchedAtLogin

        _ = EventMonitors.shared

        // 注册全局快捷键
        GlobalShortcutManager.shared.registerShortcuts()

        // 启动AI工作模式检测器
        WorkPatternDetector.shared.startMonitoring()

        // 使用 weak self 避免循环引用
        let timer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true
        ) { [weak self] _ in
            self?.determineIfProcessIdentifierMatches()
            self?.makeKeyAndVisibleIfNeeded()
        }
        self.timer = timer

        rebuildApplicationWindows()
    }

    private func setupEditMenu() {
        // 创建主菜单栏
        let mainMenu = NSMenu()

        // 创建编辑菜单
        let editMenu = NSMenu(title: "Edit")
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu

        // 添加标准编辑操作
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        // 添加到主菜单
        mainMenu.addItem(editMenuItem)

        // 设置为应用菜单
        NSApp.mainMenu = mainMenu
    }

    func applicationWillTerminate(_: Notification) {
        // 清理定时器，防止资源泄漏
        timer?.invalidate()
        timer = nil

        // 注销全局快捷键
        GlobalShortcutManager.shared.unregisterShortcuts()

        // 清理临时文件
        do {
            try FileManager.default.removeItem(at: temporaryDirectory)
            try FileManager.default.removeItem(at: pidFile)
        } catch {
            print("[AppDelegate] ⚠️  Failed to clean up temporary files: \(error.localizedDescription)")
        }
    }

    deinit {
        // 双重保险：deinit时也清理timer
        timer?.invalidate()
        timer = nil

        // 移除通知观察者
        NotificationCenter.default.removeObserver(self)
    }

    func findScreenFitsOurNeeds() -> NSScreen? {
        if let screen = NSScreen.buildin, screen.notchSize != .zero { return screen }
        return .main
    }

    @objc func rebuildApplicationWindows() {
        defer { isFirstOpen = false }
        if let mainWindowController {
            mainWindowController.destroy()
        }
        mainWindowController = nil
        guard let mainScreen = findScreenFitsOurNeeds() else { return }
        mainWindowController = .init(screen: mainScreen)
        if isFirstOpen, !isLaunchedAtLogin {
            mainWindowController?.openAfterCreate = true
        }
    }

    func determineIfProcessIdentifierMatches() {
        let pid = String(NSRunningApplication.current.processIdentifier)
        let content = (try? String(contentsOf: pidFile)) ?? ""
        guard pid.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            == content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        else {
            NSApp.terminate(nil)
            return
        }
    }

    func makeKeyAndVisibleIfNeeded() {
        guard let controller = mainWindowController,
              let window = controller.window,
              let vm = controller.vm,
              vm.status == .opened
        else { return }
        window.makeKeyAndOrderFront(nil)
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        guard let controller = mainWindowController,
              let vm = controller.vm
        else { return true }
        vm.notchOpen(.click)
        return true
    }
}
