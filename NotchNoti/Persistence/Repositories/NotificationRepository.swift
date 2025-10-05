//
//  NotificationRepository.swift
//  NotchNoti
//
//  通知数据访问层
//  封装 CoreData 操作,提供类型安全的 API
//

import CoreData
import Foundation

/// 通知仓储协议 (便于测试)
protocol NotificationRepositoryProtocol: Sendable {
    func save(_ notification: NotchNotification) async throws
    func saveBatch(_ notifications: [NotchNotification]) async throws
    func fetch(page: Int, pageSize: Int) async throws -> [NotchNotification]
    func search(query: String, page: Int, pageSize: Int) async throws -> [NotchNotification]
    func count() async throws -> Int
    func delete(olderThan date: Date) async throws
    func clear() async throws
}

/// CoreData 通知仓储实现
actor NotificationRepository: NotificationRepositoryProtocol {
    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    // MARK: - Create

    func save(_ notification: NotchNotification) async throws {
        try await stack.performBackgroundTask { context in
            NotificationEntity.create(from: notification, in: context)
        }
    }

    func saveBatch(_ notifications: [NotchNotification]) async throws {
        guard !notifications.isEmpty else { return }

        let objects = notifications.map { notification -> [String: Any] in
            var dict: [String: Any] = [
                "id": notification.id,
                "timestamp": notification.timestamp,
                "title": notification.title,
                "message": notification.message,
                "typeRawValue": notification.type.rawValue,
                "priorityRawValue": notification.priority.rawValue
            ]

            if let icon = notification.icon {
                dict["icon"] = icon
            }

            if let metadata = notification.metadata,
               let metadataData = try? JSONEncoder().encode(metadata) {
                dict["metadataJSON"] = metadataData
            }

            return dict
        }

        try await stack.batchInsert(entityName: "NotificationEntity", objects: objects)
    }

    // MARK: - Read

    func fetch(page: Int = 0, pageSize: Int = NotificationConstants.defaultPageSize) async throws -> [NotchNotification] {
        let context = await stack.viewContext

        return try await context.perform {
            let request = NotificationEntity.recentNotifications(page: page, pageSize: pageSize)
            let entities = try context.fetch(request)
            return entities.map { $0.toModel() }
        }
    }

    func fetchAll() async throws -> [NotchNotification] {
        let context = await stack.viewContext

        return try await context.perform {
            let request = NotificationEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            let entities = try context.fetch(request)
            return entities.map { $0.toModel() }
        }
    }

    func fetch(
        types: [NotchNotification.NotificationType]
    ) async throws -> [NotchNotification] {
        let context = await stack.viewContext

        return try await context.perform {
            let request = NotificationEntity.notifications(ofTypes: types)
            let entities = try context.fetch(request)
            return entities.map { $0.toModel() }
        }
    }

    func fetch(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [NotchNotification] {
        let context = await stack.viewContext

        return try await context.perform {
            let request = NotificationEntity.notifications(from: startDate, to: endDate)
            let entities = try context.fetch(request)
            return entities.map { $0.toModel() }
        }
    }

    func fetch(forProject project: String) async throws -> [NotchNotification] {
        // 由于 metadata 是 JSON,需要先获取所有数据再过滤
        let all = try await fetchAll()
        return all.filter { $0.metadata?[MetadataKeys.project] == project }
    }

    func search(
        query: String,
        page: Int = 0,
        pageSize: Int = NotificationConstants.defaultPageSize
    ) async throws -> [NotchNotification] {
        let context = await stack.viewContext

        return try await context.perform {
            let request = NotificationEntity.search(query: query)
            request.fetchLimit = pageSize
            request.fetchOffset = page * pageSize

            let entities = try context.fetch(request)
            return entities.map { $0.toModel() }
        }
    }

    // MARK: - Count

    func count() async throws -> Int {
        let context = await stack.viewContext

        return try await context.perform {
            let request = NotificationEntity.countRequest()
            let result = try context.execute(request) as? NSAsynchronousFetchResult<NSFetchRequestResult>
            return (result?.finalResult as? [NSNumber])?.first?.intValue ?? 0
        }
    }

    func count(types: [NotchNotification.NotificationType]) async throws -> Int {
        let context = await stack.viewContext

        return try await context.perform {
            let typeValues = types.map { $0.rawValue }
            let predicate = NSPredicate(format: "typeRawValue IN %@", typeValues)
            let request = NotificationEntity.countRequest(predicate: predicate)

            let result = try context.execute(request) as? NSAsynchronousFetchResult<NSFetchRequestResult>
            return (result?.finalResult as? [NSNumber])?.first?.intValue ?? 0
        }
    }

    // MARK: - Delete

    func delete(_ notification: NotchNotification) async throws {
        try await stack.performBackgroundTask { context in
            let request = NotificationEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", notification.id as CVarArg)
            request.fetchLimit = 1

            if let entity = try context.fetch(request).first {
                context.delete(entity)
            }
        }
    }

    func delete(olderThan date: Date) async throws {
        let request = NotificationEntity.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp < %@", date as NSDate)

        try await stack.batchDelete(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }

    func clear() async throws {
        let request = NotificationEntity.fetchRequest()
        try await stack.batchDelete(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
    }

    // MARK: - Update

    func updateUserChoice(
        notificationId: UUID,
        choice: String
    ) async throws {
        try await stack.performBackgroundTask { context in
            let request = NotificationEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", notificationId as CVarArg)
            request.fetchLimit = 1

            if let entity = try context.fetch(request).first {
                entity.userChoice = choice

                // 同时更新 metadata
                var metadata = entity.metadata ?? [:]
                metadata[MetadataKeys.userChoice] = choice
                entity.metadata = metadata
            }
        }
    }

    // MARK: - Cleanup

    /// 清理过期数据 (保留最新的 N 条)
    func cleanup(keepRecent count: Int = NotificationConstants.maxPersistentCount) async throws {
        let context = await stack.viewContext

        let totalCount = try await self.count()
        guard totalCount > count else { return }

        let deleteCount = totalCount - count

        // 获取最老的 N 条记录的 ID
        let idsToDelete: [UUID] = try await context.perform {
            let request = NotificationEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            request.fetchLimit = deleteCount
            request.propertiesToFetch = ["id"]

            let entities = try context.fetch(request)
            return entities.compactMap { $0.id }
        }

        // 批量删除
        try await stack.performBackgroundTask { context in
            let request = NotificationEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", idsToDelete)

            let entities = try context.fetch(request)
            for entity in entities {
                context.delete(entity)
            }
        }

        print("[NotificationRepository] Cleaned up \(deleteCount) old notifications")
    }
}
