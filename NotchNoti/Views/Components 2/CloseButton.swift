//
//  CloseButton.swift
//  NotchNoti
//
//  通用关闭按钮组件
//  消除代码重复,统一关闭按钮样式
//

import SwiftUI

/// 刘海视图通用关闭按钮
struct NotchCloseButton: View {
    var action: () -> Void

    init(action: @escaping () -> Void = {
        NotchViewModel.shared?.returnToNormal()
    }) {
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.3))
                .padding(6)
                .background(Circle().fill(Color.black.opacity(0.01)))
                .contentShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(8)
        .zIndex(100)
    }
}

/// 窗口关闭按钮 (用于独立窗口,如Diff/Summary)
struct WindowCloseButton: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button(action: { isPresented = false }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Notch Close Button") {
    ZStack {
        Color.black
        NotchCloseButton()
    }
    .frame(width: 100, height: 100)
}

#Preview("Window Close Button") {
    ZStack {
        Color.gray
        WindowCloseButton(isPresented: .constant(true))
    }
    .frame(width: 100, height: 100)
}
