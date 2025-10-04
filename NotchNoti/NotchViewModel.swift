import Cocoa
import Combine
import Foundation
import LaunchAtLogin
import SwiftUI

class NotchViewModel: NSObject, ObservableObject {
    static weak var shared: NotchViewModel?

    var cancellables: Set<AnyCancellable> = []
    let inset: CGFloat

    init(inset: CGFloat = -4) {
        self.inset = inset
        super.init()
        NotchViewModel.shared = self
        setupCancellables()
    }

    deinit {
        destroy()
    }

    // 优化的动画配置，支持 ProMotion 120Hz
    let animation: Animation = .interpolatingSpring(
        mass: 0.7,           // 降低质量，更轻快
        stiffness: 450,      // 增加刚度，更快响应
        damping: 28,         // 适度阻尼，减少震荡
        initialVelocity: 0
    )
    let notchOpenedSize: CGSize = .init(width: 600, height: 160)
    let dropDetectorRange: CGFloat = 32

    enum Status: String, Codable, Hashable, Equatable {
        case closed
        case opened
        case popping
    }

    enum OpenReason: String, Codable, Hashable, Equatable {
        case click
        case drag
        case boot
        case unknown
    }

    enum ContentType: Int, Codable, Hashable, Equatable {
        case normal
        case menu
        case settings
        case history
        case stats
        case aiAnalysis
    }

    var notchOpenedRect: CGRect {
        .init(
            x: screenRect.origin.x + (screenRect.width - notchOpenedSize.width) / 2,
            y: screenRect.origin.y + screenRect.height - notchOpenedSize.height,
            width: notchOpenedSize.width,
            height: notchOpenedSize.height
        )
    }

    var headlineOpenedRect: CGRect {
        .init(
            x: screenRect.origin.x + (screenRect.width - notchOpenedSize.width) / 2,
            y: screenRect.origin.y + screenRect.height - deviceNotchRect.height,
            width: notchOpenedSize.width,
            height: deviceNotchRect.height
        )
    }

    @Published private(set) var status: Status = .closed
    @Published var openReason: OpenReason = .unknown
    @Published var contentType: ContentType = .normal

    @Published var spacing: CGFloat = 16
    @Published var cornerRadius: CGFloat = 16
    @Published var deviceNotchRect: CGRect = .zero
    @Published var screenRect: CGRect = .zero
    @Published var optionKeyPressed: Bool = false
    @Published var notchVisible: Bool = true

    @PublishedPersist(key: "selectedLanguage", defaultValue: .system)
    var selectedLanguage: Language

    @PublishedPersist(key: "hapticFeedback", defaultValue: true)
    var hapticFeedback: Bool
    
    @PublishedPersist(key: "notificationSound", defaultValue: true)
    var notificationSound: Bool

    let hapticSender = PassthroughSubject<Void, Never>()

    func notchOpen(_ reason: OpenReason) {
        openReason = reason
        status = .opened
        contentType = .normal
    }

    func notchClose() {
        openReason = .unknown
        status = .closed
        contentType = .normal
    }

    func showSettings() {
        contentType = .settings
    }

    func showStats() {
        contentType = .stats
    }

    func showAIAnalysis() {
        contentType = .aiAnalysis
    }

    func notchPop() {
        openReason = .unknown
        status = .popping
    }

    func returnToNormal() {
        let wasViewingOtherContent = contentType != .normal && contentType != .menu
        contentType = .normal

        // 如果用户从其他页面返回，且有待处理的通知，触发显示
        if wasViewingOtherContent {
            NotificationManager.shared.checkAndShowPendingNotifications()
        }
    }
}
