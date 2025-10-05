//
//  CoreDataStack.swift
//  NotchNoti
//
//  统一的 CoreData 栈管理器
//  支持内存模式(测试)和持久化模式(生产)
//

@preconcurrency import CoreData
import Foundation

/// CoreData 栈单例
/// 提供统一的上下文访问和错误处理
actor CoreDataStack {
    static let shared = CoreDataStack()

    // MARK: - Properties

    private let modelName = "NotchNoti"
    private var _container: NSPersistentContainer?

    /// 主上下文 (主线程读取)
    nonisolated var viewContext: NSManagedObjectContext {
        get async {
            let container = await self.container
            return container.viewContext
        }
    }

    /// 容器 (延迟初始化)
    private var container: NSPersistentContainer {
        get async {
            if let existing = _container {
                return existing
            }

            let container = await loadContainer()
            _container = container
            return container
        }
    }

    // MARK: - Initialization

    private init() {}

    /// 加载持久化容器
    private func loadContainer() async -> NSPersistentContainer {
        let container = NSPersistentContainer(name: modelName)

        // 配置持久化存储
        if let storeDescription = container.persistentStoreDescriptions.first {
            // 启用自动迁移
            storeDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            storeDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

            // 启用 WAL 模式 (Write-Ahead Logging) 提升并发性能
            storeDescription.setOption("WAL" as NSString, forKey: "journal_mode")
        }

        return await withCheckedContinuation { continuation in
            container.loadPersistentStores { description, error in
                if let error = error {
                    fatalError("CoreData store failed to load: \(error.localizedDescription)")
                }

                // 配置视图上下文
                container.viewContext.automaticallyMergesChangesFromParent = true
                container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

                print("[CoreData] Loaded store: \(description.url?.lastPathComponent ?? "unknown")")
                continuation.resume(returning: container)
            }
        }
    }

    // MARK: - Context Management

    /// 创建后台上下文 (用于批量操作)
    func newBackgroundContext() async -> NSManagedObjectContext {
        let container = await self.container
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return context
    }

    /// 在后台上下文执行操作
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = await newBackgroundContext()

        return try await context.perform {
            let result = try block(context)

            if context.hasChanges {
                try context.save()
            }

            return result
        }
    }

    /// 保存主上下文
    func saveContext() async throws {
        let context = await viewContext

        guard context.hasChanges else { return }

        try await context.perform {
            try context.save()
        }
    }

    // MARK: - Batch Operations

    /// 批量插入 (性能优化)
    func batchInsert(
        entityName: String,
        objects: [[String: Any]]
    ) async throws {
        let context = await newBackgroundContext()

        try await context.perform {
            let batchInsert = NSBatchInsertRequest(
                entityName: entityName,
                objects: objects
            )

            batchInsert.resultType = .statusOnly

            try context.execute(batchInsert)
        }
    }

    /// 批量删除
    func batchDelete(fetchRequest: NSFetchRequest<NSFetchRequestResult>) async throws {
        let context = await newBackgroundContext()

        // 捕获需要的数据
        let entityName = fetchRequest.entityName ?? ""
        let predicate = fetchRequest.predicate

        try await context.perform {
            // 在闭包内重建 fetchRequest
            let localFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            localFetchRequest.predicate = predicate

            let deleteRequest = NSBatchDeleteRequest(fetchRequest: localFetchRequest)
            deleteRequest.resultType = .resultTypeStatusOnly

            try context.execute(deleteRequest)
        }
    }

    // MARK: - Memory Management

    /// 重置所有数据 (仅用于测试)
    func reset() async throws {
        let container = await self.container

        // 删除所有存储
        for store in container.persistentStoreCoordinator.persistentStores {
            if let storeURL = store.url {
                try container.persistentStoreCoordinator.destroyPersistentStore(
                    at: storeURL,
                    type: NSPersistentStore.StoreType(rawValue: store.type)
                )
            }
        }

        // 重新加载
        _container = nil
        _ = await self.container
    }

    /// 清理内存
    func refreshAllObjects() async {
        let context = await viewContext

        await context.perform {
            context.refreshAllObjects()
        }
    }
}

// MARK: - Test Support

#if DEBUG
extension CoreDataStack {
    /// 创建内存模式栈 (用于测试)
    static func inMemory() -> CoreDataStack {
        let stack = CoreDataStack()

        Task {
            let container = NSPersistentContainer(name: "NotchNoti")

            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]

            container.loadPersistentStores { _, error in
                if let error = error {
                    fatalError("In-memory store failed: \(error)")
                }
            }

            await stack.setContainer(container)
        }

        return stack
    }

    private func setContainer(_ container: NSPersistentContainer) {
        _container = container
    }
}
#endif
