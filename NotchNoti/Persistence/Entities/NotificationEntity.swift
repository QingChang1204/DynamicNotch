//
//  NotificationEntity.swift
//  NotchNoti
//
//  CoreData 通知实体定义
//  对应数据库表结构和索引配置
//

import CoreData
import Foundation

@objc(NotificationEntity)
public class NotificationEntity: NSManagedObject {
    // MARK: - Properties

    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var title: String
    @NSManaged public var message: String
    @NSManaged public var typeRawValue: String
    @NSManaged public var priorityRawValue: Int16
    @NSManaged public var icon: String?
    @NSManaged public var metadataJSON: Data?  // JSON encoded dictionary
    @NSManaged public var userChoice: String?  // 用户选择 (交互式通知)

    // Relations
    @NSManaged public var actions: NSSet?  // NotificationActionEntity

    // MARK: - Computed Properties

    var type: NotchNotification.NotificationType {
        get { NotchNotification.NotificationType(rawValue: typeRawValue) ?? .info }
        set { typeRawValue = newValue.rawValue }
    }

    var priority: NotchNotification.Priority {
        get { NotchNotification.Priority(rawValue: Int(priorityRawValue)) ?? .normal }
        set { priorityRawValue = Int16(newValue.rawValue) }
    }

    var metadata: [String: String]? {
        get {
            guard let data = metadataJSON else { return nil }
            return try? JSONDecoder().decode([String: String].self, from: data)
        }
        set {
            metadataJSON = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        timestamp = Date()
    }
}

// MARK: - Core Data Helpers

extension NotificationEntity {
    /// 获取 Fetch Request
    @nonobjc public class func fetchRequest() -> NSFetchRequest<NotificationEntity> {
        return NSFetchRequest<NotificationEntity>(entityName: "NotificationEntity")
    }

    /// 创建实体
    @discardableResult
    static func create(
        from notification: NotchNotification,
        in context: NSManagedObjectContext
    ) -> NotificationEntity {
        let entity = NotificationEntity(context: context)
        entity.id = notification.id
        entity.timestamp = notification.timestamp
        entity.title = notification.title
        entity.message = notification.message
        entity.type = notification.type
        entity.priority = notification.priority
        entity.icon = notification.icon
        entity.metadata = notification.metadata

        // 创建 actions
        if let actions = notification.actions {
            let actionEntities = NSMutableSet()
            for action in actions {
                let actionEntity = NotificationActionEntity.create(from: action, in: context)
                actionEntities.add(actionEntity)
            }
            entity.actions = actionEntities
        }

        return entity
    }

    /// 转换为领域模型
    func toModel() -> NotchNotification {
        let actionModels = (actions as? Set<NotificationActionEntity>)?
            .map { $0.toModel() }

        return NotchNotification(
            id: id,
            timestamp: timestamp,
            title: title,
            message: message,
            type: type,
            priority: priority,
            icon: icon,
            actions: actionModels,
            metadata: metadata
        )
    }
}

// MARK: - Notification Action Entity

@objc(NotificationActionEntity)
public class NotificationActionEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var label: String
    @NSManaged public var action: String
    @NSManaged public var styleRawValue: String

    @NSManaged public var notification: NotificationEntity?

    var style: NotificationAction.ActionStyle {
        get { NotificationAction.ActionStyle(rawValue: styleRawValue) ?? .normal }
        set { styleRawValue = newValue.rawValue }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
    }

    static func create(
        from action: NotificationAction,
        in context: NSManagedObjectContext
    ) -> NotificationActionEntity {
        let entity = NotificationActionEntity(context: context)
        entity.id = action.id
        entity.label = action.label
        entity.action = action.action
        entity.style = action.style
        return entity
    }

    func toModel() -> NotificationAction {
        NotificationAction(
            label: label,
            action: action,
            style: style
        )
    }
}

// MARK: - Fetch Request Builders

extension NotificationEntity {
    /// 获取最近的通知 (分页)
    static func recentNotifications(
        page: Int,
        pageSize: Int
    ) -> NSFetchRequest<NotificationEntity> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = pageSize
        request.fetchOffset = page * pageSize
        return request
    }

    /// 按类型筛选
    static func notifications(
        ofTypes types: [NotchNotification.NotificationType]
    ) -> NSFetchRequest<NotificationEntity> {
        let request = fetchRequest()
        let typeValues = types.map { $0.rawValue }
        request.predicate = NSPredicate(format: "typeRawValue IN %@", typeValues)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        return request
    }

    /// 按项目筛选 (使用元数据)
    static func notifications(
        forProject project: String
    ) -> NSFetchRequest<NotificationEntity> {
        let request = fetchRequest()
        // 注意: 由于 metadata 是 JSON,需要在代码中过滤
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        return request
    }

    /// 按时间范围筛选
    static func notifications(
        from startDate: Date,
        to endDate: Date
    ) -> NSFetchRequest<NotificationEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "timestamp >= %@ AND timestamp <= %@",
            startDate as NSDate,
            endDate as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        return request
    }

    /// 搜索通知
    static func search(
        query: String
    ) -> NSFetchRequest<NotificationEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "title CONTAINS[cd] %@ OR message CONTAINS[cd] %@",
            query, query
        )
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        return request
    }

    /// 统计查询 (计数)
    static func countRequest(
        predicate: NSPredicate? = nil
    ) -> NSFetchRequest<NSFetchRequestResult> {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "NotificationEntity")
        request.resultType = .countResultType
        request.predicate = predicate
        return request
    }
}

// MARK: - NotchNotification Extension

extension NotchNotification {
    /// 从 ID 创建 (支持解码)
    init(
        id: UUID,
        timestamp: Date,
        title: String,
        message: String,
        type: NotificationType,
        priority: Priority,
        icon: String?,
        actions: [NotificationAction]?,
        metadata: [String: String]?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.title = title
        self.message = message
        self.type = type
        self.priority = priority
        self.icon = icon
        self.actions = actions
        self.metadata = metadata
    }
}
