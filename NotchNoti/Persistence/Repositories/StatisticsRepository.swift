//
//  StatisticsRepository.swift
//  NotchNoti
//
//  工作会话统计数据访问层
//  提供聚合查询和复杂统计计算
//

import CoreData
import Foundation

protocol StatisticsRepositoryProtocol: Sendable {
    func createSession(projectName: String) async throws -> WorkSession
    func endSession(_ sessionId: UUID) async throws
    func addActivity(_ activity: Activity, to sessionId: UUID) async throws
    func fetchRecentSessions(limit: Int) async throws -> [WorkSession]
    func fetchTodaySessions() async throws -> [WorkSession]
}

actor StatisticsRepository: StatisticsRepositoryProtocol {
    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    // MARK: - Session Management

    func createSession(projectName: String) async throws -> WorkSession {
        try await stack.performBackgroundTask { context in
            let entity = WorkSessionEntity.create(projectName: projectName, in: context)
            return entity.toModel()
        }
    }

    func endSession(_ sessionId: UUID) async throws {
        try await stack.performBackgroundTask { context in
            let request = WorkSessionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", sessionId as CVarArg)
            request.fetchLimit = 1

            if let entity = try context.fetch(request).first {
                entity.endTime = Date()
            }
        }
    }

    func getCurrentSession() async throws -> WorkSession? {
        let context = await stack.viewContext

        return try await context.perform {
            let request = WorkSessionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "endTime == nil")
            request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
            request.fetchLimit = 1

            return try context.fetch(request).first?.toModel()
        }
    }

    // MARK: - Activity Management

    func addActivity(_ activity: Activity, to sessionId: UUID) async throws {
        try await stack.performBackgroundTask { context in
            let request = WorkSessionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", sessionId as CVarArg)
            request.fetchLimit = 1

            if let entity = try context.fetch(request).first {
                entity.addActivity(activity, in: context)
            }
        }
    }

    // MARK: - Fetch Sessions

    func fetchRecentSessions(limit: Int = StatisticsConstants.maxSessionHistory) async throws -> [WorkSession] {
        let context = await stack.viewContext

        return try await context.perform {
            let request = WorkSessionEntity.recentSessions(limit: limit)
            request.relationshipKeyPathsForPrefetching = ["activities"]
            let entities = try context.fetch(request)
            return entities.map { $0.toModel() }
        }
    }

    func fetchTodaySessions() async throws -> [WorkSession] {
        let context = await stack.viewContext

        return try await context.perform {
            let request = WorkSessionEntity.todaySessions()
            request.relationshipKeyPathsForPrefetching = ["activities"]
            let entities = try context.fetch(request)
            return entities.map { $0.toModel() }
        }
    }

    func fetchSessions(forProject project: String) async throws -> [WorkSession] {
        let context = await stack.viewContext

        return try await context.perform {
            let request = WorkSessionEntity.sessions(forProject: project)
            request.relationshipKeyPathsForPrefetching = ["activities"]
            let entities = try context.fetch(request)
            return entities.map { $0.toModel() }
        }
    }

    func fetchSessions(from startDate: Date, to endDate: Date) async throws -> [WorkSession] {
        let context = await stack.viewContext

        return try await context.perform {
            let request = WorkSessionEntity.sessions(from: startDate, to: endDate)
            request.relationshipKeyPathsForPrefetching = ["activities"]
            let entities = try context.fetch(request)
            return entities.map { $0.toModel() }
        }
    }

    // MARK: - Aggregations

    /// 获取今日汇总
    func aggregateToday() async throws -> DailySummary {
        let sessions = try await fetchTodaySessions()

        let totalDuration = sessions.reduce(0.0) { $0 + $1.duration }
        let totalActivities = sessions.reduce(0) { $0 + $1.totalActivities }
        let avgPace = sessions.isEmpty ? 0 : sessions.reduce(0.0) { $0 + $1.pace } / Double(sessions.count)

        var allActivities: [ActivityType: Int] = [:]
        for session in sessions {
            for (type, count) in session.activityDistribution {
                allActivities[type, default: 0] += count
            }
        }

        return DailySummary(
            date: Calendar.current.startOfDay(for: Date()),
            sessionCount: sessions.count,
            totalDuration: totalDuration,
            totalActivities: totalActivities,
            averagePace: avgPace,
            activityDistribution: allActivities,
            sessions: sessions
        )
    }

    /// 获取周趋势
    func aggregateWeeklyTrend() async throws -> [DailySummary] {
        let calendar = Calendar.current
        var summaries: [DailySummary] = []

        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            let daySessions = try await fetchSessions(from: startOfDay, to: endOfDay)

            let totalDuration = daySessions.reduce(0.0) { $0 + $1.duration }
            let totalActivities = daySessions.reduce(0) { $0 + $1.totalActivities }
            let avgPace = daySessions.isEmpty ? 0 : daySessions.reduce(0.0) { $0 + $1.pace } / Double(daySessions.count)

            var allActivities: [ActivityType: Int] = [:]
            for session in daySessions {
                for (type, count) in session.activityDistribution {
                    allActivities[type, default: 0] += count
                }
            }

            summaries.append(DailySummary(
                date: startOfDay,
                sessionCount: daySessions.count,
                totalDuration: totalDuration,
                totalActivities: totalActivities,
                averagePace: avgPace,
                activityDistribution: allActivities,
                sessions: daySessions
            ))
        }

        return summaries.reversed()
    }

    /// 获取项目统计
    func aggregateByProject() async throws -> [ProjectSummary] {
        let sessions = try await fetchRecentSessions(limit: 100)

        var projectMap: [String: [WorkSession]] = [:]
        for session in sessions {
            projectMap[session.projectName, default: []].append(session)
        }

        return projectMap.map { (name, sessions) in
            let totalDuration = sessions.reduce(0.0) { $0 + $1.duration }
            let totalActivities = sessions.reduce(0) { $0 + $1.totalActivities }
            let lastActive = sessions.map(\.startTime).max() ?? Date()

            return ProjectSummary(
                projectName: name,
                sessionCount: sessions.count,
                totalDuration: totalDuration,
                totalActivities: totalActivities,
                lastActive: lastActive
            )
        }.sorted { $0.lastActive > $1.lastActive }
    }

    // MARK: - Cleanup

    func deleteOldSessions(olderThan days: Int = 30) async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        let request = WorkSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "startTime < %@", cutoffDate as NSDate)

        try await stack.batchDelete(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }
}
