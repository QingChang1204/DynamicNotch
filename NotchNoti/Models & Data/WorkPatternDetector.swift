//
//  WorkPatternDetector.swift
//  NotchNoti
//
//  工作模式检测器 - 主动监控并触发AI洞察（基于通知数据）
//

import Foundation
import Combine

/// 工作模式检测器 - 在后台监控工作状态，检测反模式并触发AI洞察
class WorkPatternDetector: ObservableObject {
    static let shared = WorkPatternDetector()

    @Published var detectedAntiPattern: AntiPattern?
    @Published var shouldSuggestBreak: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var checkTimer: Timer?

    private let insightsAnalyzer = WorkInsightsAnalyzer.shared

    private init() {
        // 不在init自动启动，等AppDelegate调用
    }

    // MARK: - 监控控制

    /// 开始监控当前session
    func startMonitoring() {
        // 每5分钟检查一次
        checkTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.performCheck()
        }

        print("[WorkPatternDetector] 开始监控工作模式（基于通知）")
    }

    /// 停止监控
    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
        print("[WorkPatternDetector] 停止监控")
    }

    // MARK: - 核心检测逻辑（基于通知而非Session）

    private func performCheck() {
        Task {
            // 检查持续工作时间
            _ = await insightsAnalyzer.checkContinuousWork()

            // 检测反模式
            let notifications = await NotificationManager.shared.getHistory(page: 0, pageSize: 100)
            if let pattern = insightsAnalyzer.detectAntiPattern(from: notifications) {
                await MainActor.run {
                    detectedAntiPattern = pattern
                }
                _ = await insightsAnalyzer.analyzeAntiPattern(pattern, notifications: notifications)
            } else {
                await MainActor.run {
                    detectedAntiPattern = nil
                }
            }
        }
    }

    // MARK: - 手动请求（UI触发）

    /// 手动请求当前洞察
    func requestCurrentInsight() async -> WorkInsight? {
        return await insightsAnalyzer.analyzeRecentActivity()
    }

    /// 手动请求周度分析
    func requestWeeklyInsight() async -> WorkInsight? {
        return await insightsAnalyzer.analyzeWeeklyPattern(sessions: [])
    }
}
